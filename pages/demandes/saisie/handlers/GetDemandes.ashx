<%@ WebHandler Language="C#" Class="GetDemandes" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetDemandes : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Cache.SetNoStore();

        // ✅ Authentification : tous les rôles authentifiés (0 à 4)
        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            int userId = AuthHelper.GetUserId(ctx);
            int page = 1, pageSize = 10;
            string search = ctx.Request["search"] ?? "";
            string statut = ctx.Request["statut"] ?? "";
            string sort = ctx.Request["sort"] ?? "DATE_SORTIE";
            string order = ctx.Request["order"] ?? "DESC";

            int.TryParse(ctx.Request["page"], out page);
            int.TryParse(ctx.Request["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;

            string connStr = AuthHelper.ConnectionString;
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string where = "WHERE s.CREATED_BY = @userId AND s.DELETION_AT IS NULL AND s.STATUT <> 'VALIDE'";
                if (!string.IsNullOrEmpty(search))
                    where += " AND (s.NUMERO LIKE @search OR s.DESTINATION LIKE @search OR s.NOM LIKE @search)";
                if (!string.IsNullOrEmpty(statut))
                    where += " AND s.STATUT = @statut";

                // Comptage
                string countSql = "SELECT COUNT(*) FROM SSORTIE s " + where;
                int total = 0;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddWithValue("@userId", userId);
                    if (!string.IsNullOrEmpty(search))
                        cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(statut))
                        cmd.Parameters.AddWithValue("@statut", statut);
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                // Récupération des sorties
                string sql = @"
                    SELECT s.ID, s.NUMERO, s.DATE_SORTIE, s.DESTINATION, s.NOM, s.FONCTION, s.NOTES, s.STATUT
                    FROM SSORTIE s
                    " + where + @"
                    ORDER BY " + sort + " " + order + @"
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                var sorties = new List<object>();
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@userId", userId);
                    if (!string.IsNullOrEmpty(search))
                        cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(statut))
                        cmd.Parameters.AddWithValue("@statut", statut);
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);

                    using (SqlDataReader rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            // Utilisation de la syntaxe compatible C# 4.0
                            var s = new Dictionary<string, object>();
                            s["ID"] = rdr["ID"].ToString();
                            s["NUMERO"] = Convert.ToString(rdr["NUMERO"]);
                            s["DATE_SORTIE"] = rdr["DATE_SORTIE"].ToString();
                            s["DESTINATION"] = Convert.ToString(rdr["DESTINATION"]);
                            s["NOM"] = Convert.ToString(rdr["NOM"]);
                            s["FONCTION"] = Convert.ToString(rdr["FONCTION"]);
                            s["NOTES"] = Convert.ToString(rdr["NOTES"]);
                            s["STATUT"] = Convert.ToString(rdr["STATUT"]);
                            s["Lignes"] = new List<object>();
                            sorties.Add(s);
                        }
                    }
                }

                // Charger les lignes pour chaque sortie
                foreach (Dictionary<string, object> s in sorties)
                {
                    string id = s["ID"].ToString();
                    string lignesSql = @"
                        SELECT l.ARTICLE_ID, a.CODE AS ARTICLE_CODE, a.NOM AS ARTICLE_NOM,
                               l.QUANTITE_D, l.QUANTITE_R, l.OBSERVATIONS
                        FROM MLSORTIE l
                        LEFT JOIN MARTICLE a ON l.ARTICLE_ID = a.ID
                        WHERE l.BON_SORTIE_ID = @id AND l.DELETION_AT IS NULL";
                    var lignes = new List<object>();
                    using (SqlCommand cmd = new SqlCommand(lignesSql, conn))
                    {
                        cmd.Parameters.AddWithValue("@id", id);
                        using (SqlDataReader rdr = cmd.ExecuteReader())
                        {
                            while (rdr.Read())
                            {
                                lignes.Add(new
                                {
                                    ARTICLE_ID = rdr["ARTICLE_ID"].ToString(),
                                    ARTICLE_CODE = Convert.ToString(rdr["ARTICLE_CODE"]),
                                    ARTICLE_NOM = Convert.ToString(rdr["ARTICLE_NOM"]),
                                    QUANTITE_D = Convert.ToDecimal(rdr["QUANTITE_D"]),
                                    QUANTITE_R = Convert.ToDecimal(rdr["QUANTITE_R"]),
                                    OBSERVATIONS = Convert.ToString(rdr["OBSERVATIONS"])
                                });
                            }
                        }
                    }
                    s["Lignes"] = lignes;
                }

                int totalPages = (int)Math.Ceiling((double)total / pageSize);
                var response = new { success = true, Sorties = sorties, total = total, totalPages = totalPages };
                ctx.Response.Write(new JavaScriptSerializer().Serialize(response));
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
