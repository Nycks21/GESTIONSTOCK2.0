<%@ WebHandler Language="C#" Class="SupprimerClasse" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerClasse : IHttpHandler, IRequiresSessionState
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
        JavaScriptSerializer ser = new JavaScriptSerializer();

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var payload = ser.Deserialize<IdPayload>(body);
            int idInt;
            if (!int.TryParse(payload.ID, out idInt)) throw new ArgumentException("ID invalide.");

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            using (var cmd  = new SqlCommand("DELETE FROM [dbo].[Classes] WHERE ID = @id", conn))
            {
                cmd.Parameters.Add("@id", System.Data.SqlDbType.Int).Value = idInt;
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
    private class IdPayload { public string ID { get; set; } }
}