<%@ WebHandler Language="C#" Class="GetFournisseurs" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetFournisseurs : IHttpHandler, IRequiresSessionState
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

            var fournisseurs = new List<object>();

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                "SELECT ID, NOM FROM SFOURNISSEUR WHERE ACTIVE = 1 AND DELETION_AT IS NULL ORDER BY NOM", conn))
            {
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        fournisseurs.Add(new
                        {
                            ID = reader["ID"].ToString(),
                            NOM = reader["NOM"].ToString()
                        });
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, Fournisseurs = fournisseurs }));
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
