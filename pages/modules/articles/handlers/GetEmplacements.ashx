<%@ WebHandler Language="C#" Class="GetEmplacements" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEmplacements : IHttpHandler, IRequiresSessionState
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
            string connStr = AuthHelper.ConnectionString;
            var emplacements = new List<object>();
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                // Récupère tous les emplacements actifs, triés par nom
                string sql = "SELECT ID, NOM FROM SEMPLACEMENT WHERE DELETION_AT IS NULL AND ACTIVE = 1 ORDER BY NOM";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        emplacements.Add(new {
                            ID = Convert.ToString(rdr["ID"]),
                            NOM = Convert.ToString(rdr["NOM"])
                        });
                    }
                }
            }
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, Emplacements = emplacements }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}
