<%@ WebHandler Language="C#" Class="GetStatsEmplacements" %>

using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetStatsEmplacements : IHttpHandler, IRequiresSessionState
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
            int total = 0, actifs = 0, inactifs = 0, sousEmplacements = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                // Total
                string sqlTotal = "SELECT COUNT(*) FROM SEMPLACEMENT WHERE DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sqlTotal, conn))
                    total = (int)cmd.ExecuteScalar();

                // Actifs
                string sqlActifs = "SELECT COUNT(*) FROM SEMPLACEMENT WHERE DELETION_AT IS NULL AND ACTIVE = 1";
                using (var cmd = new SqlCommand(sqlActifs, conn))
                    actifs = (int)cmd.ExecuteScalar();

                // Inactifs
                string sqlInactifs = "SELECT COUNT(*) FROM SEMPLACEMENT WHERE DELETION_AT IS NULL AND ACTIVE = 0";
                using (var cmd = new SqlCommand(sqlInactifs, conn))
                    inactifs = (int)cmd.ExecuteScalar();

                // Sous-emplacements (ayant un parent)
                string sqlSous = "SELECT COUNT(*) FROM SEMPLACEMENT WHERE DELETION_AT IS NULL AND PARENT_ID IS NOT NULL";
                using (var cmd = new SqlCommand(sqlSous, conn))
                    sousEmplacements = (int)cmd.ExecuteScalar();
            }

            var result = new
            {
                success = true,
                total,
                actifs,
                inactifs,
                sousEmplacements
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
