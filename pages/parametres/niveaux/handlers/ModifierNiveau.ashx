<%@ WebHandler Language="C#" Class="ModifierNiveau" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierNiveau : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        // ✅ Sécurité : 4 vérifications essentielles
    
    // 1. Authentification
    if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
    {
        ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
        return;
    }
    
    // 2. Token de session valide
    if (!AuthHelper.RequireApiAuth(ctx))
    {
        ctx.Response.Write("{\"success\":false,\"message\":\"Session invalide\"}");
        return;
    }
    
    // 3. Permission (SuperAdmin = 0, Admin = 1, etc.)
    int role = AuthHelper.GetUserRole(ctx);
    if (role < 0 || role > 1) // Permissions minimales selon le handler
    {
        ctx.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
        return;
    }
    
    // 4. CSRF pour les méthodes POST/PUT/DELETE
    string method = ctx.Request.HttpMethod.ToUpper();
    if (method == "POST" || method == "PUT" || method == "DELETE")
    {
        string token = ctx.Request.Headers["X-CSRF-Token"];
        string sessionToken = ctx.Session["CSRF_TOKEN"] != null ? ctx.Session["CSRF_TOKEN"].ToString() : null;
        if (string.IsNullOrEmpty(token) || token != sessionToken)
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Token CSRF invalide\"}");
            return;
        }
    }
        // Configuration de la réponse
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        JavaScriptSerializer ser = new JavaScriptSerializer();

        // Sécurité : Vérification de la session
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

            // ✅ VALIDATION DU GUID
            Guid idGuid;
            if (string.IsNullOrWhiteSpace(payload.ID) || !Guid.TryParse(payload.ID, out idGuid))
                throw new ArgumentException("Identifiant de Niveau (GUID) invalide.");

            if (string.IsNullOrWhiteSpace(payload.NOM))
                throw new ArgumentException("Le numéro de Niveau est obligatoire.");

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"UPDATE [dbo].[NIVEAUX]
                  SET    NOM   = @nom,
                         ORDRE = @ordre,
                         STATUT   = @statut
                  WHERE  ID       = @id", conn))
            {
                // Utilisation du type spécifique UniqueIdentifier pour éviter les erreurs de conversion
                cmd.Parameters.Add("@id", System.Data.SqlDbType.UniqueIdentifier).Value = idGuid;
                cmd.Parameters.AddWithValue("@nom",   payload.NOM.Trim());
                cmd.Parameters.AddWithValue("@ordre", payload.ORDRE);
                cmd.Parameters.AddWithValue("@statut",   payload.STATUT);

                conn.Open();
                int rows = cmd.ExecuteNonQuery();

                if (rows == 0) 
                    throw new Exception("La Niveau n'existe pas ou aucune modification n'a été détectée.");
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
            
            // Gestion des erreurs de contraintes (ex: numéro de Niveau déjà pris par une autre Niveau)
            string msg = (ex.Message.Contains("UNIQUE") || ex.Message.Contains("UQ_"))
                ? "Ce numéro de Niveau est déjà utilisé par une autre Niveau." 
                : ex.Message;
            
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(msg) + "}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class NiveauPayload
    {
        public string ID { get; set; } // Reçu en tant que String (GUID)
        public string NOM { get; set; }
        public int ORDRE { get; set; }
        public bool STATUT { get; set; }
    }
}