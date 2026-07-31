// handlers/GetEleve.ashx
<%@ WebHandler Language="C#" Class="GetEleve" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEleve : IHttpHandler, IRequiresSessionState
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
        
        try
        {
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            string connStr = "";
            if (ConfigurationManager.ConnectionStrings["MaConnexion"] != null)
            {
                connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
            }
            
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée\"}");
                return;
            }

            var eleves = new List<object>();
            
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                
                string sql = @"
                    SELECT 
                        e.MATRICULE,
                        e.NOM,
                        e.CLASSE,
                        c.NOM as CLASSE_NOM,
                        e.STATUT,
                        e.EMAIL,
                        e.TELEPHONE
                    FROM ELEVES e
                    LEFT JOIN CLASSES c ON e.CLASSE = c.ID
                    WHERE e.STATUT = 'actif'
                    ORDER BY e.NOM ASC
                ";
                
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        eleves.Add(new
                        {
                            MATRICULE = reader["MATRICULE"].ToString(),
                            NOM = reader["NOM"].ToString(),
                            CLASSE = reader["CLASSE"] != DBNull.Value ? Convert.ToInt32(reader["CLASSE"]) : 0,
                            CLASSE_NOM = reader["CLASSE_NOM"] != DBNull.Value ? reader["CLASSE_NOM"].ToString() : "",
                            STATUT = reader["STATUT"].ToString(),
                            EMAIL = reader["EMAIL"] != DBNull.Value ? reader["EMAIL"].ToString() : "",
                            TELEPHONE = reader["TELEPHONE"] != DBNull.Value ? reader["TELEPHONE"].ToString() : ""
                        });
                    }
                }
            }
            
            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["Eleves"] = eleves;
            result["Total"] = eleves.Count;
            
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            ctx.Response.Write(serializer.Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "'") + "\"}");
        }
    }
    
    public bool IsReusable { get { return false; } }
}