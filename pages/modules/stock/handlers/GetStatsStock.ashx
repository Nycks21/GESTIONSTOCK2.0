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

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
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
                // Nombre d'articles ayant au moins un stock > 0
                string sqlTotalArticles = "SELECT COUNT(DISTINCT ARTICLE_ID) FROM SSTOCK WHERE DELETION_AT IS NULL AND QUANTITE_ACTUELLE > 0";
                using (var cmd = new SqlCommand(sqlTotalArticles, conn))
                    totalArticles = (int)cmd.ExecuteScalar();

                // Quantité totale
                string sqlTotalQuantite = "SELECT ISNULL(SUM(QUANTITE_ACTUELLE), 0) FROM SSTOCK WHERE DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sqlTotalQuantite, conn))
                    totalQuantite = (decimal)cmd.ExecuteScalar();

                // Sous seuil d'alerte (quantite < seuil_alerte et > 0)
                string sqlSousSeuil = @"
                    SELECT COUNT(*)
                    FROM SSTOCK s
                    INNER JOIN MARTICLE a ON s.ARTICLE_ID = a.ID
                    WHERE s.DELETION_AT IS NULL AND a.DELETION_AT IS NULL
                    AND s.QUANTITE_ACTUELLE < a.SEUIL_ALERTE AND s.QUANTITE_ACTUELLE > 0";
                using (var cmd = new SqlCommand(sqlSousSeuil, conn))
                    sousSeuil = (int)cmd.ExecuteScalar();

                // Rupture (quantite = 0)
                string sqlRupture = @"
                    SELECT COUNT(*)
                    FROM SSTOCK s
                    INNER JOIN MARTICLE a ON s.ARTICLE_ID = a.ID
                    WHERE s.DELETION_AT IS NULL AND a.DELETION_AT IS NULL
                    AND s.QUANTITE_ACTUELLE = 0";
                using (var cmd = new SqlCommand(sqlRupture, conn))
                    rupture = (int)cmd.ExecuteScalar();
            }

            var result = new
            {
                success = true,
                totalArticles,
                totalQuantite,
                sousSeuil,
                rupture
            };
            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}
