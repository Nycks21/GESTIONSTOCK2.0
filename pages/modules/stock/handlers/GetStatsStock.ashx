<%@ WebHandler Language="C#" Class="GetStatsStock" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetStatsStock : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            int totalArticles = 0;
            decimal totalQuantite = 0;
            int sousSeuil = 0;
            int rupture = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ✅ Même logique que GetStock.ashx :
                //    - Article retenu : EXISTS (SSTOCK) — cohérent avec le tableau
                //    - DISPONIBLE   = SUM(SSTOCK.QUANTITE_ACTUELLE)
                //    - SEUIL_ALERTE = MARTICLE.SEUIL_ALERTE
                string sql = @"
                    SELECT
                        SUM(CASE WHEN DISPONIBLE > 0 THEN 1 ELSE 0 END) AS TotalArticles,
                        ISNULL(SUM(DISPONIBLE), 0) AS TotalQuantite,
                        SUM(CASE WHEN DISPONIBLE > 0 AND SEUIL_ALERTE > 0 AND DISPONIBLE <= SEUIL_ALERTE THEN 1 ELSE 0 END) AS SousSeuil,
                        SUM(CASE WHEN DISPONIBLE <= 0 THEN 1 ELSE 0 END) AS Rupture
                    FROM (
                        SELECT
                            a.ID,
                            a.SEUIL_ALERTE,
                            ISNULL((
                                SELECT SUM(s.QUANTITE_ACTUELLE)
                                FROM SSTOCK s
                                WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                            ), 0) AS DISPONIBLE
                        FROM MARTICLE a
                        WHERE a.DELETION_AT IS NULL
                          AND EXISTS (
                              SELECT 1 FROM SSTOCK s
                              WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                          )
                    ) t";

                using (var cmd = new SqlCommand(sql, conn))
                using (var rdr = cmd.ExecuteReader())
                {
                    if (rdr.Read())
                    {
                        totalArticles = rdr["TotalArticles"] == DBNull.Value ? 0 : Convert.ToInt32(rdr["TotalArticles"]);
                        totalQuantite = rdr["TotalQuantite"] == DBNull.Value ? 0m : Convert.ToDecimal(rdr["TotalQuantite"]);
                        sousSeuil = rdr["SousSeuil"] == DBNull.Value ? 0 : Convert.ToInt32(rdr["SousSeuil"]);
                        rupture = rdr["Rupture"] == DBNull.Value ? 0 : Convert.ToInt32(rdr["Rupture"]);
                    }
                }
            }

            var result = new
            {
                success = true,
                totalArticles = totalArticles,
                totalQuantite = totalQuantite,
                sousSeuil = sousSeuil,
                rupture = rupture
            };
            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(
                new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}
