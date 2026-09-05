<%@ WebHandler Language="C#" Class="GetEntreeStats" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEntreeStats : IHttpHandler, IRequiresSessionState
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
            int total = 0, valide = 0, brouillon = 0, annule = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    SELECT
                        COUNT(*) AS Total,
                        SUM(CASE WHEN STATUT = 'VALIDE' THEN 1 ELSE 0 END) AS Valide,
                        SUM(CASE WHEN STATUT = 'BROUILLON' THEN 1 ELSE 0 END) AS Brouillon,
                        SUM(CASE WHEN STATUT = 'ANNULE' THEN 1 ELSE 0 END) AS Annule
                    FROM SENTREE WHERE DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    using (var reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            total = reader["Total"] != DBNull.Value ? Convert.ToInt32(reader["Total"]) : 0;
                            valide = reader["Valide"] != DBNull.Value ? Convert.ToInt32(reader["Valide"]) : 0;
                            brouillon = reader["Brouillon"] != DBNull.Value ? Convert.ToInt32(reader["Brouillon"]) : 0;
                            annule = reader["Annule"] != DBNull.Value ? Convert.ToInt32(reader["Annule"]) : 0;
                        }
                    }
                }
            }

            var response = new { success = true, total, valide, brouillon, annule };
            ctx.Response.Write(new JavaScriptSerializer().Serialize(response));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}
