<%@ WebHandler Language="C#" Class="AjouterNiveau" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterNiveau : IHttpHandler, IRequiresSessionState
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
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        JavaScriptSerializer ser = new JavaScriptSerializer();

        if (ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
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

            var payload = ser.Deserialize<NiveauPayload>(body);

            if (payload == null)
                throw new ArgumentException("Données invalides.");

            if (string.IsNullOrWhiteSpace(payload.NOM))
                throw new ArgumentException("Le nom est obligatoire.");

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

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            // On utilise ISNULL(@id, NEWID()) pour gérer l'auto-génération si @id est NULL
            using (var cmd = new SqlCommand(
                @"INSERT INTO [dbo].[NIVEAUX] (ID, NOM, ORDRE, STATUT, CREATED_AT) 
                  VALUES (ISNULL(@id, NEWID()), @nom, @ordre, @statut, GETDATE())", conn))
            {
                // Gestion du paramètre @id (Envoi de DBNull si pas de saisie)
                cmd.Parameters.Add("@id", System.Data.SqlDbType.UniqueIdentifier).Value = 
                    (object)idSaisi ?? DBNull.Value;
                
                cmd.Parameters.AddWithValue("@nom",    payload.NOM.Trim());
                cmd.Parameters.AddWithValue("@ordre",  payload.ORDRE);
                cmd.Parameters.AddWithValue("@statut", payload.STATUT);

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
            
            // Gestion des erreurs d'unicité (Nom ou ID déjà présent)
            string msg = ex.Message;
            if (ex.Message.Contains("PRIMARY KEY"))
                msg = "Cet identifiant (ID) est déjà utilisé.";
            else if (ex.Message.Contains("UNIQUE"))
                msg = "Ce nom de niveau existe déjà.";

            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(msg) + "}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class NiveauPayload
    {
        public string ID { get; set; } // Reçu en string depuis le JS
        public string NOM { get; set; }
        public int ORDRE { get; set; }
        public bool STATUT { get; set; }
    }
}