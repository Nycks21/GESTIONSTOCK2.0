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
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            int total = 0, normal = 0, alerte = 0, rupture = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Total
                string sqlTotal = "SELECT COUNT(*) FROM MARTICLE WHERE DELETION_AT IS NULL AND ACTIVE = 1";
                using (var cmd = new SqlCommand(sqlTotal, conn))
                {
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                // Normal
                string sqlNormal = @"
                    SELECT COUNT(*)
                    FROM MARTICLE a
                    WHERE a.DELETION_AT IS NULL AND a.ACTIVE = 1
                      AND ISNULL((SELECT SUM(QUANTITE) FROM SSTOCK WHERE ARTICLE_ID = a.ID), 0) > a.SEUIL_ALERTE";
                using (var cmd = new SqlCommand(sqlNormal, conn))
                {
                    normal = Convert.ToInt32(cmd.ExecuteScalar());
                }

                // Alerte
                string sqlAlerte = @"
                    SELECT COUNT(*)
                    FROM MARTICLE a
                    WHERE a.DELETION_AT IS NULL AND a.ACTIVE = 1
                      AND ISNULL((SELECT SUM(QUANTITE) FROM SSTOCK WHERE ARTICLE_ID = a.ID), 0) <= a.SEUIL_ALERTE
                      AND ISNULL((SELECT SUM(QUANTITE) FROM SSTOCK WHERE ARTICLE_ID = a.ID), 0) > 0";
                using (var cmd = new SqlCommand(sqlAlerte, conn))
                {
                    alerte = Convert.ToInt32(cmd.ExecuteScalar());
                }

                // Rupture
                string sqlRupture = @"
                    SELECT COUNT(*)
                    FROM MARTICLE a
                    WHERE a.DELETION_AT IS NULL AND a.ACTIVE = 1
                      AND ISNULL((SELECT SUM(QUANTITE) FROM SSTOCK WHERE ARTICLE_ID = a.ID), 0) <= 0";
                using (var cmd = new SqlCommand(sqlRupture, conn))
                {
                    rupture = Convert.ToInt32(cmd.ExecuteScalar());
                }
            }

            var result = new
            {
                success = true,
                total = total,
                normal = normal,
                alerte = alerte,
                rupture = rupture
            };

            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message,
                stack = ex.StackTrace
            }));
        }
    }

    // Propriété traditionnelle pour éviter l'erreur CS1002
    public bool IsReusable
    {
        get { return false; }
    }
}
