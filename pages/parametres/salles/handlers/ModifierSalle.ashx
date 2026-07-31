<%@ WebHandler Language="C#" Class="ModifierSalle" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierSalle : IHttpHandler, IRequiresSessionState
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

            var payload = ser.Deserialize<SallePayload>(body);

            // --- VALIDATIONS ---
            if (payload == null)
                throw new ArgumentException("Données invalides (JSON vide).");

            // Vérification du GUID (Crucial pour SQL Server)
            Guid idGuid;
            if (string.IsNullOrEmpty(payload.ID) || !Guid.TryParse(payload.ID, out idGuid))
                throw new ArgumentException("Identifiant de salle invalide.");

            // Vérification du NUMERO (C'est ici que votre erreur est déclenchée)
            if (string.IsNullOrWhiteSpace(payload.NUMERO))
                throw new ArgumentException("Le numéro de salle est obligatoire.");

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"UPDATE [dbo].[SALLES]
                  SET    NUMERO   = @numero,
                         CAPACITE = @capacite,
                         STATUT   = @statut
                  WHERE  ID       = @id", conn))
            {
                // Utilisation de SqlDbType.UniqueIdentifier pour le GUID
                cmd.Parameters.Add("@id", System.Data.SqlDbType.UniqueIdentifier).Value = idGuid;
                cmd.Parameters.Add("@numero", System.Data.SqlDbType.NVarChar).Value = payload.NUMERO.Trim();
                cmd.Parameters.Add("@capacite", System.Data.SqlDbType.Int).Value = payload.CAPACITE;
                cmd.Parameters.Add("@statut", System.Data.SqlDbType.Bit).Value = payload.STATUT;

                conn.Open();
                int rows = cmd.ExecuteNonQuery();

                if (rows == 0) 
                    throw new Exception("La salle n'a pas pu être mise à jour (ID introuvable).");
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
            string msg = (ex.Message.Contains("UNIQUE") || ex.Message.Contains("UQ_"))
                ? "Ce numéro de salle existe déjà."
                : ex.Message;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(msg) + "}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class SallePayload
    {
        public string ID { get; set; }
        public string NUMERO { get; set; } // Doit correspondre EXACTEMENT à la clé JSON
        public int CAPACITE { get; set; }
        public bool STATUT { get; set; }
    }
}