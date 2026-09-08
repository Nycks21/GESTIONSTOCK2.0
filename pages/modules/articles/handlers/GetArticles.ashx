<%@ WebHandler Language="C#" Class="GetArticles" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetArticles : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            int page = 1, pageSize = 10;
            string search = ctx.Request["search"] ?? "";
            string category = ctx.Request["category"] ?? "";
            string status = ctx.Request["status"] ?? "";
            string sort = ctx.Request["sort"] ?? "NOM";
            string order = ctx.Request["order"] ?? "ASC";

            int.TryParse(ctx.Request["page"], out page);
            int.TryParse(ctx.Request["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;

            string connStr = AuthHelper.ConnectionString;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string whereClause = "WHERE a.DELETION_AT IS NULL ";
                if (!string.IsNullOrEmpty(search))
                {
                    whereClause += "AND (a.CODE LIKE @search OR a.NOM LIKE @search OR a.DESCRIPTION LIKE @search) ";
                }
                if (!string.IsNullOrEmpty(category))
                {
                    whereClause += "AND a.CATEGORIE_ID = @category ";
                }

                // Comptage total
                string countSql = "SELECT COUNT(*) FROM MARTICLE a " + whereClause;
                int total = 0;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    if (!string.IsNullOrEmpty(search)) cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(category)) cmd.Parameters.AddWithValue("@category", category);
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                // Requête de liste
                string sql = @"
                    SELECT a.ID, a.CODE, a.NOM, a.DESCRIPTION,
                           a.CATEGORIE_ID, c.NOM AS CATEGORIE_NOM,
                           a.FOURNISSEUR_PREFERE_ID, f.NOM AS FOURNISSEUR_NOM,
                           a.UNITE_MESURE_ID, u.CODE AS UNITE_CODE, u.NOM AS UNITE_NOM,
                           a.EMPLACEMENT_ID, e.NOM AS EMPLACEMENT_NOM,
                           a.SEUIL_ALERTE, a.SEUIL_MIN,
                           a.ACTIVE, a.EST_SERVICE,
                           ISNULL((SELECT SUM(s.QUANTITE_ACTUELLE) FROM SSTOCK s WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL), 0) AS STOCK_TOTAL,
                           CASE
                               WHEN ISNULL((SELECT SUM(s.QUANTITE_ACTUELLE) FROM SSTOCK s WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL), 0) = 0 THEN 'rupture'
                               WHEN ISNULL((SELECT SUM(s.QUANTITE_ACTUELLE) FROM SSTOCK s WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL), 0) <= a.SEUIL_ALERTE THEN 'alerte'
                               ELSE 'normal'
                           END AS STATUT_STOCK
                    FROM MARTICLE a
                    LEFT JOIN SCATEGORIE c ON a.CATEGORIE_ID = c.ID
                    LEFT JOIN SFOURNISSEUR f ON a.FOURNISSEUR_PREFERE_ID = f.ID
                    LEFT JOIN SUNITE u ON a.UNITE_MESURE_ID = u.ID
                    LEFT JOIN SEMPLACEMENT e ON a.EMPLACEMENT_ID = e.ID
                    " + whereClause + @"
                    ORDER BY " + sort + " " + order + @"
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                var articles = new List<object>();
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    if (!string.IsNullOrEmpty(search)) cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(category)) cmd.Parameters.AddWithValue("@category", category);
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);
                    using (SqlDataReader rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            articles.Add(new
                            {
                                ID = rdr["ID"] == DBNull.Value ? null : rdr["ID"].ToString(),
                                CODE = Convert.ToString(rdr["CODE"]),
                                NOM = Convert.ToString(rdr["NOM"]),
                                DESCRIPTION = Convert.ToString(rdr["DESCRIPTION"]),
                                CATEGORIE_ID = Convert.ToString(rdr["CATEGORIE_ID"]),
                                CATEGORIE_NOM = Convert.ToString(rdr["CATEGORIE_NOM"]),
                                FOURNISSEUR_PREFERE_ID = Convert.ToString(rdr["FOURNISSEUR_PREFERE_ID"]),
                                FOURNISSEUR_NOM = Convert.ToString(rdr["FOURNISSEUR_NOM"]),
                                UNITE_MESURE_ID = Convert.ToString(rdr["UNITE_MESURE_ID"]),
                                UNITE = Convert.ToString(rdr["UNITE_NOM"]),
                                UNITE_SYMBOLE = Convert.ToString(rdr["UNITE_CODE"]),
                                EMPLACEMENT_ID = Convert.ToString(rdr["EMPLACEMENT_ID"]),
                                EMPLACEMENT_NOM = Convert.ToString(rdr["EMPLACEMENT_NOM"]),
                                SEUIL_ALERTE = Convert.ToDecimal(rdr["SEUIL_ALERTE"]),
                                SEUIL_MIN = Convert.ToDecimal(rdr["SEUIL_MIN"]),
                                ACTIVE = Convert.ToBoolean(rdr["ACTIVE"]),
                                EST_SERVICE = Convert.ToBoolean(rdr["EST_SERVICE"]),
                                STOCK_TOTAL = Convert.ToDecimal(rdr["STOCK_TOTAL"]),
                                STATUT_STOCK = Convert.ToString(rdr["STATUT_STOCK"])
                            });
                        }
                    }
                }

                int totalPages = (int)Math.Ceiling((double)total / pageSize);
                var response = new { success = true, Articles = articles, total = total, totalPages = totalPages };
                ctx.Response.Write(new JavaScriptSerializer().Serialize(response));
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}
