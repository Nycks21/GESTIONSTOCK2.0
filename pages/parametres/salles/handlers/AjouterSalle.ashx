<%@ WebHandler Language="C#" Class="AjouterSalle" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterSalle : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        // ✅ Sécurité : 4 vérifications essentielles
    
    // 1. Authentification
    if (context.Session == null || context.Session["authenticated"] == null || !(bool)context.Session["authenticated"])
    {
        context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
        return;
    }
    
    // 2. Token de session valide
    if (!AuthHelper.RequireApiAuth(context))
    {
        context.Response.Write("{\"success\":false,\"message\":\"Session invalide\"}");
        return;
    }
    
    // 3. Permission (SuperAdmin = 0, Admin = 1, etc.)
    int role = AuthHelper.GetUserRole(context);
    if (role < 0 || role > 1) // Permissions minimales selon le handler
    {
        context.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
        return;
    }
    
    // 4. CSRF pour les méthodes POST/PUT/DELETE
    string method = context.Request.HttpMethod.ToUpper();
    if (method == "POST" || method == "PUT" || method == "DELETE")
    {
        string token = context.Request.Headers["X-CSRF-Token"];
        string sessionToken = context.Session["CSRF_TOKEN"]?.ToString();
        if (string.IsNullOrEmpty(token) || token != sessionToken)
        {
            context.Response.Write("{\"success\":false,\"message\":\"Token CSRF invalide\"}");
            return;
        }
    }
        // Configuration de la réponse
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        JavaScriptSerializer ser = new JavaScriptSerializer();

        // Vérification de la session
        if (ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        // Vérification de la méthode POST
        if (ctx.Request.HttpMethod != "POST")
        {
            ctx.Response.StatusCode = 405;
            ctx.Response.Write("{\"success\":false,\"message\":\"Méthode non autorisée\"}");
            return;
        }

        try
        {
            // Lecture du corps de la requête
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            // Désérialisation via une classe Payload typée
            var payload = ser.Deserialize<SallePayload>(body);

            // Validation des données
            if (payload == null)
                throw new ArgumentException("Données invalides.");

            if (string.IsNullOrWhiteSpace(payload.NUMERO))
                throw new ArgumentException("Le numéro de salle est obligatoire.");

            if (payload.CAPACITE < 0)
                throw new ArgumentException("La capacité doit être un nombre positif.");

            // --- Logique du GUID ---
            Guid? idSaisi = null;
            if (!string.IsNullOrWhiteSpace(payload.ID))
            {
                Guid tempGuid;
                if (Guid.TryParse(payload.ID, out tempGuid))
                    idSaisi = tempGuid;
                else
                    throw new ArgumentException("Le format de l'ID est invalide (doit être un GUID).");
            }

            // Chaîne de connexion standardisée
            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"INSERT INTO [dbo].[SALLES] (ID, NUMERO, CAPACITE, STATUT, CREATED_AT) 
                  VALUES (ISNULL(@id, NEWID()), @numero, @capacite, @statut, GETDATE())", conn))
            {
                cmd.Parameters.Add("@id", System.Data.SqlDbType.UniqueIdentifier).Value = 
                    (object)idSaisi ?? DBNull.Value;
                cmd.Parameters.AddWithValue("@numero",   payload.NUMERO.Trim());
                cmd.Parameters.AddWithValue("@capacite", payload.CAPACITE);
                cmd.Parameters.AddWithValue("@statut",   payload.STATUT);

                conn.Open();
                cmd.ExecuteNonQuery();
            }

            ctx.Response.Write("{\"success\":true}");
        }
        catch (ArgumentException ex)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(ex.Message) + "}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            
            // Gestion spécifique pour les doublons de numéros de salle
            string msg = (ex.Message.Contains("UNIQUE") || ex.Message.Contains("UQ_"))
                ? "Ce numéro de salle existe déjà."
                : ex.Message;

            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(msg) + "}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }

    // Classe de transport pour structurer les données JSON reçues
    private class SallePayload
    {
        public string ID { get; set; }
        public string NUMERO { get; set; }
        public int CAPACITE { get; set; }
        public bool STATUT { get; set; }
    }
}