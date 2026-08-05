<%@ WebHandler Language="C#" Class="SupprimerSalle" %>

using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerSalle : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

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

            string body = new StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var payload = serializer.Deserialize<IdPayload>(body);

            if (payload == null || string.IsNullOrWhiteSpace(payload.ID))
                throw new ArgumentException("Identifiant manquant.");

            Guid idGuid;
            if (!Guid.TryParse(payload.ID, out idGuid))
                throw new ArgumentException("Identifiant (GUID) invalide.");

            string connStr = GetConnectionString();
            if (string.IsNullOrEmpty(connStr))
            {
                SendError(ctx, 500, "Chaîne de connexion non trouvée");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand("DELETE FROM [dbo].[SALLES] WHERE ID = @id", conn))
            {
                cmd.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = idGuid;
                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0)
                    throw new Exception("Salle introuvable.");
            }

            ctx.Response.Write("{\"success\":true}");
        }
        catch (Exception ex)
        {
            SendError(ctx, 400, ex.Message);
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

    public class IdPayload
    {
        public string ID { get; set; }
    }
}