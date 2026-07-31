<%@ WebHandler Language="C#" Class="SupprimerAnnee" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerAnnee : IHttpHandler, IRequiresSessionState
{
    private static readonly string connStr;

    static SupprimerAnnee()
    {
        var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
        connStr = (connSetting != null) ? connSetting.ConnectionString : "";
    }

    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        JavaScriptSerializer ser = new JavaScriptSerializer();

        // ✅ Vérification d'authentification simplifiée
        if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        // ✅ Vérification du rôle (SuperAdmin ou Admin)
        object roleObj = ctx.Session["USERROLE"];
        int role = (roleObj != null) ? Convert.ToInt32(roleObj) : -1;
        if (role != 0 && role != 1)
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
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

            if (payload == null || payload.ID <= 0)
                throw new ArgumentException("ID d'année invalide.");

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand("DELETE FROM [dbo].[RANNEE] WHERE ID = @id", conn))
            {
                cmd.Parameters.Add("@id", System.Data.SqlDbType.Int).Value = payload.ID;
                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0)
                    throw new Exception("Année introuvable (ID=" + payload.ID + ").");
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Année scolaire supprimée avec succès.\"}");
        }
        catch (ArgumentException ex)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(ex.Message) + "}");
        }
        catch (Exception)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize("Erreur serveur") + "}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class IdPayload
    {
        public int ID { get; set; }
    }
}