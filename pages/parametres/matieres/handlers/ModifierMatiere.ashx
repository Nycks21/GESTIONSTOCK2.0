<%@ WebHandler Language="C#" Class="ModifierMatiere" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierMatiere : IHttpHandler, IRequiresSessionState
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
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset     = "utf-8";
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

            var payload = ser.Deserialize<MatierePayload>(body);

            if (payload == null)
                throw new ArgumentException("Données invalides.");

            Guid matiereGuid;
            if (!Guid.TryParse(payload.ID, out matiereGuid))
                throw new ArgumentException("ID de matière invalide.");

            if (string.IsNullOrWhiteSpace(payload.NOM))
                throw new ArgumentException("Le nom de la matière est obligatoire.");

            if (payload.ENSEIGNANT_ID <= 0)
                throw new ArgumentException("Veuillez sélectionner un enseignant valide.");

            if (payload.CLASSE_ID <= 0)
                throw new ArgumentException("Veuillez sélectionner une classe valide.");

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            using (var cmd  = new SqlCommand(
                @"UPDATE [dbo].[MATIERES]
                  SET    NOM            = @nom,
                         ENSEIGNANT     = @ens,
                         COEFFICIENT    = @coeff,
                         HEURES_SEMAINE = @heures,
                         CLASSE_ID      = @classeId
                  WHERE  ID = @id", conn))
            {
                cmd.Parameters.Add("@id",       System.Data.SqlDbType.UniqueIdentifier).Value = matiereGuid;
                cmd.Parameters.Add("@nom",      System.Data.SqlDbType.NVarChar).Value         = payload.NOM.Trim();
                cmd.Parameters.Add("@ens",      System.Data.SqlDbType.Int).Value              = payload.ENSEIGNANT_ID;
                cmd.Parameters.Add("@coeff",    System.Data.SqlDbType.Decimal).Value          = payload.COEFFICIENT;
                cmd.Parameters.Add("@heures",   System.Data.SqlDbType.Int).Value              = payload.HEURES_SEMAINE;
                cmd.Parameters.Add("@classeId", System.Data.SqlDbType.Int).Value              = payload.CLASSE_ID;

                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0) throw new Exception("Matière introuvable (ID=" + payload.ID + ").");
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
            string msg = ex.Message.Contains("UNIQUE") ? "Cette matière existe déjà." : ex.Message;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(msg) + "}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class MatierePayload
    {
        public string  ID             { get; set; }
        public string  NOM            { get; set; }
        public int     ENSEIGNANT_ID  { get; set; }
        public decimal COEFFICIENT    { get; set; }
        public int     HEURES_SEMAINE { get; set; }
        public int     CLASSE_ID      { get; set; }
    }
}