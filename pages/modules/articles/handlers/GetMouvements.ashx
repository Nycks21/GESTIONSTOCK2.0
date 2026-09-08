<%@ WebHandler Language="C#" Class="GetMouvements" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetMouvements : IHttpHandler, IRequiresSessionState
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
            string articleId = ctx.Request["articleId"] ?? "";
            string emplacementId = ctx.Request["emplacementId"] ?? "";
            int page = 1, pageSize = 20;
            int.TryParse(ctx.Request["page"], out page);
            int.TryParse(ctx.Request["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 20;

            if (string.IsNullOrEmpty(articleId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"articleId requis\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Comptage
                string where = "WHERE ARTICLE_ID = @articleId AND DELETION_AT IS NULL";
                if (!string.IsNullOrEmpty(emplacementId))
                    where += " AND EMPLACEMENT_ID = @empl";
                string countSql = "SELECT COUNT(*) FROM MSTOCK " + where;
                int total = 0;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddWithValue("@articleId", articleId);
                    if (!string.IsNullOrEmpty(emplacementId))
                        cmd.Parameters.AddWithValue("@empl", emplacementId);
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                string sql = @"
                    SELECT ID, TYPE, QUANTITE, QUANTITE_AVANT, QUANTITE_APRES, MOTIF,
                           REFERENCE_TYPE, REFERENCE_NUMERO, CREATED_AT
                    FROM MSTOCK
                    " + where + @"
                    ORDER BY CREATED_AT DESC
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                var mouvements = new List<object>();
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@articleId", articleId);
                    if (!string.IsNullOrEmpty(emplacementId))
                        cmd.Parameters.AddWithValue("@empl", emplacementId);
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);
                    using (SqlDataReader rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            // ⚠️ Remplacement de l'opérateur ?. par Convert.ToString (gère DBNull)
                            mouvements.Add(new
                            {
                                ID = Convert.ToString(rdr["ID"]),
                                TYPE = Convert.ToString(rdr["TYPE"]),
                                QUANTITE = Convert.ToDecimal(rdr["QUANTITE"]),
                                QUANTITE_AVANT = Convert.ToDecimal(rdr["QUANTITE_AVANT"]),
                                QUANTITE_APRES = Convert.ToDecimal(rdr["QUANTITE_APRES"]),
                                MOTIF = Convert.ToString(rdr["MOTIF"]),
                                REFERENCE_TYPE = Convert.ToString(rdr["REFERENCE_TYPE"]),
                                REFERENCE_NUMERO = Convert.ToString(rdr["REFERENCE_NUMERO"]),
                                CREATED_AT = Convert.ToString(rdr["CREATED_AT"])
                            });
                        }
                    }
                }

                int totalPages = (int)Math.Ceiling((double)total / pageSize);
                ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                {
                    success = true,
                    Mouvements = mouvements,
                    total = total,
                    totalPages = totalPages
                }));
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
