<%@ WebHandler Language="C#" Class="ModifierClasse" %>

using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierClasse : IHttpHandler, IRequiresSessionState
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

            int idInt;
            Guid niveauGuid, salleGuid;

            if (!int.TryParse(payload.ID, out idInt)) throw new ArgumentException("ID classe invalide.");
            if (!Guid.TryParse(payload.NIVEAU_ID, out niveauGuid)) throw new ArgumentException("Niveau invalide.");
            if (!Guid.TryParse(payload.SALLE_ID, out salleGuid)) throw new ArgumentException("Salle invalide.");

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            using (var cmd  = new SqlCommand(
                @"UPDATE [dbo].[Classes] 
                  SET NOM=@nom, NIVEAU_ID=@niv, TITULAIRE_ID=@tit, SALLE_ID=@sal, EFFECTIF=@eff, STATUT=@stat
                  WHERE ID=@id", conn))
            {
                // Utilisation du chemin complet System.Data.SqlDbType pour être certain
                cmd.Parameters.Add("@id",  System.Data.SqlDbType.Int).Value = idInt;
                cmd.Parameters.Add("@nom", System.Data.SqlDbType.NVarChar).Value = payload.NOM.Trim();
                cmd.Parameters.Add("@niv", System.Data.SqlDbType.UniqueIdentifier).Value = niveauGuid;
                cmd.Parameters.Add("@tit", System.Data.SqlDbType.Int).Value = payload.TITULAIRE_ID;
                cmd.Parameters.Add("@sal", System.Data.SqlDbType.UniqueIdentifier).Value = salleGuid;
                cmd.Parameters.Add("@eff", System.Data.SqlDbType.Int).Value = payload.EFFECTIF;
                cmd.Parameters.Add("@stat", System.Data.SqlDbType.Bit).Value = (payload.STATUT == "1" || payload.STATUT.ToLower() == "true");

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
    private class ClassePayload {
        public string ID { get; set; }
        public string NOM { get; set; }
        public string NIVEAU_ID { get; set; }
        public int TITULAIRE_ID { get; set; }
        public string SALLE_ID { get; set; }
        public int EFFECTIF { get; set; }
        public string STATUT { get; set; }
    }
}