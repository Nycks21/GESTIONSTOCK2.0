<%@ WebHandler Language="C#" Class="AjouterClasse" %>

using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterClasse : IHttpHandler, IRequiresSessionState
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
        JavaScriptSerializer ser = new JavaScriptSerializer();

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var payload = ser.Deserialize<ClassePayload>(body);

            // Validation des GUIDs pour Niveau et Salle
            Guid niveauGuid, salleGuid;
            if (!Guid.TryParse(payload.NIVEAU_ID, out niveauGuid))
                throw new ArgumentException("Le niveau sélectionné n'est pas un identifiant valide.");
            if (!Guid.TryParse(payload.SALLE_ID, out salleGuid))
                throw new ArgumentException("La salle sélectionnée n'est pas un identifiant valide.");

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"INSERT INTO [dbo].[Classes] (NOM, NIVEAU_ID, TITULAIRE_ID, SALLE_ID, EFFECTIF, STATUT)
                  VALUES (@nom, @niv, @tit, @sal, @eff, @stat)", conn))
            {
                cmd.Parameters.Add("@nom", SqlDbType.NVarChar).Value = payload.NOM ?? "";
                cmd.Parameters.Add("@niv", SqlDbType.UniqueIdentifier).Value = niveauGuid;
                cmd.Parameters.Add("@tit", SqlDbType.Int).Value = payload.TITULAIRE_ID;
                cmd.Parameters.Add("@sal", SqlDbType.UniqueIdentifier).Value = salleGuid;
                cmd.Parameters.Add("@eff", SqlDbType.Int).Value = payload.EFFECTIF;
                cmd.Parameters.Add("@stat", SqlDbType.Bit).Value = (payload.STATUT == "1" || payload.STATUT.ToLower() == "true");

                conn.Open();
                cmd.ExecuteNonQuery();
            }
            ctx.Response.Write("{\"success\":true}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(ex.Message) + "}");
        }
    }

    public bool IsReusable { get { return false; } }

    public class ClassePayload
    {
        public string NOM { get; set; }
        public string NIVEAU_ID { get; set; } // Reçu en string (GUID)
        public int TITULAIRE_ID { get; set; }
        public string SALLE_ID { get; set; }  // Reçu en string (GUID)
        public int EFFECTIF { get; set; }
        public string STATUT { get; set; }
    }
}