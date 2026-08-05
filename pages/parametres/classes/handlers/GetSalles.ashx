<%@ WebHandler Language="C#" Class="GetSalles" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetSalles : IHttpHandler, IRequiresSessionState
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
        // Configuration de la réponse pour le format JSON
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // Vérification de la session (Sécurité)
        if (ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        try
        {
            // Utilisation de la chaîne de connexion standardisée
            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
            var salles = new List<object>();

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"SELECT ID, NUMERO, CAPACITE, STATUT, CREATED_AT 
                  FROM [dbo].[SALLES] 
                  ORDER BY NUMERO ASC", conn))
            {
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        // Création d'objets anonymes pour une sérialisation propre
                        salles.Add(new
                        {
                            ID         = reader.IsDBNull(0) ? "" : reader.GetGuid(0).ToString(),
                            NUMERO     = reader.IsDBNull(1) ? "" : reader.GetString(1),
                            CAPACITE   = reader.IsDBNull(2) ? 0 : reader.GetInt32(2),
                            STATUT     = !reader.IsDBNull(3) && reader.GetBoolean(3),
                            CREATED_AT = reader.IsDBNull(4) ? null : reader.GetDateTime(4).ToString("yyyy-MM-dd HH:mm:ss")
                        });
                    }
                }
            }

            // Génération du JSON via le sérialiseur système
            var json = new JavaScriptSerializer().Serialize(new { success = true, salles = salles });
            ctx.Response.Write(json);
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":" 
                + new JavaScriptSerializer().Serialize(ex.Message) + "}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}