<%@ WebHandler Language="C#" Class="GetNiveaux" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetNiveaux : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext context)
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
        context.Response.ContentType = "application/json";
        context.Response.Charset = "utf-8";
        context.Response.Cache.SetNoStore();

        // Vérification de la session
        if (context.Session["authenticated"] == null || !(bool)context.Session["authenticated"])
        {
            context.Response.StatusCode = 401;
            context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        try
        {
            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
            var niveaux = new List<object>();

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"SELECT ID, NOM, ORDRE, STATUT, CREATED_AT 
                  FROM [dbo].[NIVEAUX] 
                  ORDER BY ORDRE, NOM", conn))
            {
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        niveaux.Add(new
                        {
                           ID         = reader.IsDBNull(0) ? "" : reader.GetGuid(0).ToString(),
                            NOM        = reader.IsDBNull(1) ? "" : reader.GetString(1),
                            ORDRE      = reader.IsDBNull(2) ? 0 : reader.GetInt32(2),
                            STATUT     = !reader.IsDBNull(3) && reader.GetBoolean(3),
                            CREATED_AT = reader.IsDBNull(4) ? null : reader.GetDateTime(4).ToString("yyyy-MM-dd HH:mm:ss")
                        });
                    }
                }
            }

            // Sérialisation propre
            var json = new JavaScriptSerializer().Serialize(new { success = true, niveaux = niveaux });
            context.Response.Write(json);
        }
        catch (Exception ex)
        {
            context.Response.StatusCode = 500;
            context.Response.Write("{\"success\":false,\"message\":" 
                + new JavaScriptSerializer().Serialize(ex.Message) + "}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}