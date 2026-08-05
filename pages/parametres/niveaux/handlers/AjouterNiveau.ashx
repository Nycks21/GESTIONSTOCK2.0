<%@ WebHandler Language="C#" Class="AjouterNiveau" %>

using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterNiveau : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        context.Response.Charset = "utf-8";

        try
        {
            // 1. Vérification session
            if (context.Session == null || context.Session["authenticated"] == null || !(bool)context.Session["authenticated"])
            {
                SendError(context, "Non authentifié");
                return;
            }

            // 2. Vérification AuthHelper
            if (!AuthHelper.RequireApiAuth(context))
            {
                SendError(context, "Session invalide");
                return;
            }

            // 3. Rôle (Admin ou SuperAdmin)
            int role = AuthHelper.GetUserRole(context);
            if (role < 0 || role > 1)
            {
                SendError(context, "Permissions insuffisantes");
                return;
            }

            // 4. CSRF : vérifier l'en-tête X-CSRF-Token
            string tokenHeader = context.Request.Headers["X-CSRF-Token"];
            string sessionToken = context.Session["CSRF_TOKEN"] as string;
            if (string.IsNullOrEmpty(tokenHeader) || tokenHeader != sessionToken)
            {
                SendError(context, "Token CSRF invalide");
                return;
            }

            // 5. Lire le corps de la requête
            string body = new StreamReader(context.Request.InputStream).ReadToEnd();
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            NiveauPayload payload = serializer.Deserialize<NiveauPayload>(body);

            // 6. Chaîne de connexion
            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                SendError(context, "Chaîne de connexion non définie");
                return;
            }

            // 7. Insertion en base
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                SqlCommand cmd = new SqlCommand(
                    "INSERT INTO [dbo].[NIVEAUX] (ID, NOM, ORDRE, STATUT, CREATED_AT) " +
                    "VALUES (NEWID(), @nom, @ordre, @statut, GETDATE())", conn);
                cmd.Parameters.AddWithValue("@nom", payload.nom ?? "");
                cmd.Parameters.AddWithValue("@ordre", payload.ordre);
                cmd.Parameters.AddWithValue("@statut", payload.statut);
                conn.Open();
                cmd.ExecuteNonQuery();
            }

            // 8. Réponse succès
            context.Response.Write("{\"success\":true}");
        }
        catch (Exception ex)
        {
            SendError(context, "Erreur : " + ex.Message);
        }
    }

    private void SendError(HttpContext context, string message)
    {
        context.Response.StatusCode = 500;
        context.Response.Write("{\"success\":false,\"message\":\"" + message.Replace("\"", "\\\"") + "\"}");
    }

    public bool IsReusable
    {
        get { return false; }
    }

    public class NiveauPayload
    {
        public string nom { get; set; }
        public int ordre { get; set; }
        public bool statut { get; set; }
    }
}