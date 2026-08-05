<%@ WebHandler Language="C#" Class="GetSalles" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetSalles : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            // Authentification
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                SendError(ctx, 401, "Non authentifié");
                return;
            }
            if (!AuthHelper.RequireApiAuth(ctx))
            {
                SendError(ctx, 403, "Session invalide");
                return;
            }
            int role = AuthHelper.GetUserRole(ctx);
            if (role < 0 || role > 1)
            {
                SendError(ctx, 403, "Permissions insuffisantes");
                return;
            }

            string connStr = GetConnectionString();
            if (string.IsNullOrEmpty(connStr))
            {
                SendError(ctx, 500, "Chaîne de connexion non trouvée");
                return;
            }

            var salles = new List<object>();

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                "SELECT ID, NUMERO, CAPACITE, STATUT, CREATED_AT FROM [dbo].[SALLES] ORDER BY NUMERO", conn))
            {
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        salles.Add(new
                        {
                            ID = reader.GetGuid(0).ToString(),
                            NUMERO = reader.GetString(1),
                            CAPACITE = reader.GetInt32(2),
                            STATUT = reader.GetBoolean(3),
                            CREATED_AT = reader.IsDBNull(4) ? "" : reader.GetDateTime(4).ToString("yyyy-MM-dd HH:mm:ss")
                        });
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, salles = salles }));
        }
        catch (Exception ex)
        {
            SendError(ctx, 500, "Erreur serveur : " + ex.Message);
        }
    }

    private void SendError(HttpContext ctx, int status, string message)
    {
        ctx.Response.StatusCode = status;
        ctx.Response.Write("{\"success\":false,\"message\":\"" + message.Replace("\"", "'") + "\"}");
    }

    private string GetConnectionString()
    {
        var setting = ConfigurationManager.ConnectionStrings["MaConnexion"];
        return setting != null ? setting.ConnectionString : null;
    }

    public bool IsReusable
    {
        get { return false; }
    }
}