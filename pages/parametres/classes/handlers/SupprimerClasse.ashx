<%@ WebHandler Language="C#" Class="SupprimerClasse" %>

using System;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerClasse : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        var ser = new JavaScriptSerializer();

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        if (ctx.Request.HttpMethod != "POST")
        {
            ctx.Response.StatusCode = 405;
            ctx.Response.Write("{\"success\":false,\"message\":\"Méthode non autorisée\"}");
            return;
        }

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var payload = ser.Deserialize<IdPayload>(body);
            if (payload == null || string.IsNullOrWhiteSpace(payload.ID))
                throw new ArgumentException("ID de classe invalide.");

            int classeId;
            if (!int.TryParse(payload.ID, out classeId) || classeId <= 0)
                throw new ArgumentException("ID de classe invalide.");

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand("DELETE FROM [dbo].[CLASSES] WHERE ID = @id", conn))
            {
                cmd.Parameters.AddWithValue("@id", classeId);
                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0)
                    throw new Exception("Classe introuvable (ID=" + payload.ID + ").");
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Classe supprimée avec succès.\"}");
        }
        catch (ArgumentException argEx)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + argEx.Message.Replace("\"", "\\\"") + "\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class IdPayload
    {
        public string ID { get; set; }
    }
}