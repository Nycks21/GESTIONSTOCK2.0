<%@ WebHandler Language="C#" Class="SupprimerEleve" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerEleve : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        JavaScriptSerializer ser = new JavaScriptSerializer();

        if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
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
                throw new ArgumentException("ID d'élève invalide.");

            // ID élève est un GUID
            Guid eleveGuid;
            if (!Guid.TryParse(payload.ID, out eleveGuid))
                throw new ArgumentException("ID d'élève invalide (format GUID attendu).");

            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand("DELETE FROM [dbo].[ELEVES] WHERE ID = @id", conn))
            {
                cmd.Parameters.Add("@id", System.Data.SqlDbType.UniqueIdentifier).Value = eleveGuid;
                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0)
                    throw new Exception("Élève introuvable (ID=" + payload.ID + ").");
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Élève supprimé avec succès.\"}");
        }
        catch (ArgumentException ex)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(ex.Message) + "}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(ex.Message) + "}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }

    private class IdPayload { public string ID { get; set; } }
}