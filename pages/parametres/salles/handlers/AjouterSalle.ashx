<%@ WebHandler Language="C#" Class="AjouterSalle" %>

using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterSalle : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        try
        {
            // 1. Authentification
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

            // 2. Lecture du payload
            string body = new StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var payload = serializer.Deserialize<SallePayload>(body);

            // 3. Validation
            if (payload == null)
                throw new ArgumentException("Données invalides.");
            if (string.IsNullOrWhiteSpace(payload.NUMERO))
                throw new ArgumentException("Le numéro de salle est obligatoire.");
            if (payload.CAPACITE < 0)
                throw new ArgumentException("La capacité doit être positive.");

            // 4. Connexion
            string connStr = GetConnectionString();
            if (string.IsNullOrEmpty(connStr))
            {
                SendError(ctx, 500, "Chaîne de connexion non trouvée");
                return;
            }

            // 5. Insertion
            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                "INSERT INTO [dbo].[SALLES] (ID, NUMERO, CAPACITE, STATUT, CREATED_AT) " +
                "VALUES (NEWID(), @numero, @capacite, @statut, GETDATE())", conn))
            {
                cmd.Parameters.Add("@numero", SqlDbType.NVarChar).Value = payload.NUMERO.Trim();
                cmd.Parameters.Add("@capacite", SqlDbType.Int).Value = payload.CAPACITE;
                cmd.Parameters.Add("@statut", SqlDbType.Bit).Value = payload.STATUT;
                conn.Open();
                cmd.ExecuteNonQuery();
            }

            ctx.Response.Write("{\"success\":true}");
        }
        catch (Exception ex)
        {
            string msg = (ex.Message.Contains("UNIQUE") || ex.Message.Contains("UQ_")) 
                ? "Ce numéro de salle existe déjà." 
                : ex.Message;
            SendError(ctx, 400, msg);
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

    public class SallePayload
    {
        public string NUMERO { get; set; }
        public int CAPACITE { get; set; }
        public bool STATUT { get; set; }
    }
}