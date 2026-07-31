<%@ WebHandler Language="C#" Class="AjouterTarifEcolage" %>
using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterTarifEcolage : IHttpHandler, IRequiresSessionState
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

        if (ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var ser = new JavaScriptSerializer();
            var data = ser.Deserialize<dynamic>(body);

            int anneeId       = Convert.ToInt32(data["anneeId"]);
            int classeId      = Convert.ToInt32(data["classeId"]);
            decimal montant   = Convert.ToDecimal(data["montant"]);
            string description= data.ContainsKey("description") ? data["description"].ToString() : "";
            bool statut       = data.ContainsKey("statut") ? Convert.ToBoolean(data["statut"]) : true;

            if (anneeId <= 0 || classeId <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Année et classe obligatoires\"}");
                return;
            }
            if (montant <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Montant invalide\"}");
                return;
            }

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérification doublon : même année + même classe
                string checkSql = "SELECT COUNT(*) FROM TARIFS_ECOLAGE WHERE ANNEE_ID = @anneeId AND CLASSE_ID = @classeId";
                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.AddWithValue("@anneeId",  anneeId);
                    checkCmd.Parameters.AddWithValue("@classeId", classeId);
                    int existing = (int)checkCmd.ExecuteScalar();
                    if (existing > 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Un tarif existe déjà pour cette classe et cette année scolaire\"}");
                        return;
                    }
                }

                using (var cmd = new SqlCommand(@"
                    INSERT INTO TARIFS_ECOLAGE (ID, ANNEE_ID, CLASSE_ID, MONTANT, DESCRIPTION, STATUT, CREATED_AT)
                    VALUES (NEWID(), @anneeId, @classeId, @montant, @description, @statut, GETDATE())", conn))
                {
                    cmd.Parameters.AddWithValue("@anneeId",     anneeId);
                    cmd.Parameters.AddWithValue("@classeId",    classeId);
                    cmd.Parameters.AddWithValue("@montant",     montant);
                    cmd.Parameters.AddWithValue("@description", description);
                    cmd.Parameters.AddWithValue("@statut",      statut ? 1 : 0);
                    cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Tarif ajouté avec succès\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}
