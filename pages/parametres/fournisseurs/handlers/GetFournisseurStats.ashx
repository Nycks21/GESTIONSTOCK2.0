<%@ WebHandler Language="C#" Class="GetFournisseurStats" %>

using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetFournisseurStats : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
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
            string connStr = AuthHelper.ConnectionString;
            int total = 0, actif = 0, inactif = 0, avecEmail = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    SELECT
                        COUNT(*) AS Total,
                        SUM(CASE WHEN ACTIVE = 1 THEN 1 ELSE 0 END) AS Actif,
                        SUM(CASE WHEN ACTIVE = 0 THEN 1 ELSE 0 END) AS Inactif,
                        SUM(CASE WHEN EMAIL IS NOT NULL AND EMAIL <> '' THEN 1 ELSE 0 END) AS AvecEmail
                    FROM SFOURNISSEUR
                    WHERE DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    using (var reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            total = reader.GetInt32(0);
                            actif = reader.GetInt32(1);
                            inactif = reader.GetInt32(2);
                            avecEmail = reader.GetInt32(3);
                        }
                    }
                }
            }

            var result = new
            {
                success = true,
                total = total,
                actif = actif,
                inactif = inactif,
                avecEmail = avecEmail
            };

            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
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
