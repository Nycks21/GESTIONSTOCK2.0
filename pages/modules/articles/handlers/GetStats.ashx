<%@ WebHandler Language="C#" Class="GetStats" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetStats : IHttpHandler, IRequiresSessionState
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
            string connStr = AuthHelper.ConnectionString;
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Requête corrigée avec CTE pour éviter les agrégations imbriquées
                string sql = @"
                    WITH StockTotal AS (
                        SELECT ARTICLE_ID, ISNULL(SUM(QUANTITE_ACTUELLE), 0) AS STOCK
                        FROM SSTOCK
                        WHERE DELETION_AT IS NULL
                        GROUP BY ARTICLE_ID
                    )
                    SELECT
                        COUNT(a.ID) AS Total,
                        SUM(CASE WHEN ISNULL(st.STOCK, 0) > a.SEUIL_ALERTE THEN 1 ELSE 0 END) AS Normal,
                        SUM(CASE WHEN ISNULL(st.STOCK, 0) > 0 AND ISNULL(st.STOCK, 0) <= a.SEUIL_ALERTE THEN 1 ELSE 0 END) AS Alerte,
                        SUM(CASE WHEN ISNULL(st.STOCK, 0) <= 0 THEN 1 ELSE 0 END) AS Rupture
                    FROM MARTICLE a
                    LEFT JOIN StockTotal st ON a.ID = st.ARTICLE_ID
                    WHERE a.DELETION_AT IS NULL AND a.ACTIVE = 1";

                int total = 0, normal = 0, alerte = 0, rupture = 0;
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader rdr = cmd.ExecuteReader())
                {
                    if (rdr.Read())
                    {
                        total = rdr["Total"] == DBNull.Value ? 0 : Convert.ToInt32(rdr["Total"]);
                        normal = rdr["Normal"] == DBNull.Value ? 0 : Convert.ToInt32(rdr["Normal"]);
                        alerte = rdr["Alerte"] == DBNull.Value ? 0 : Convert.ToInt32(rdr["Alerte"]);
                        rupture = rdr["Rupture"] == DBNull.Value ? 0 : Convert.ToInt32(rdr["Rupture"]);
                    }
                }

                ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, total, normal, alerte, rupture }));
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
