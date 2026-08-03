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
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            // 1. Authentification
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            // 2. Token de session valide
            if (!AuthHelper.RequireApiAuth(ctx))
            {
                ctx.Response.StatusCode = 403;
                ctx.Response.Write("{\"success\":false,\"message\":\"Session invalide\"}");
                return;
            }

            // 3. Permission (SuperAdmin = 0, Admin = 1, etc.)
            int role = AuthHelper.GetUserRole(ctx);
            if (role < 0 || role > 1)
            {
                ctx.Response.StatusCode = 403;
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
                    ctx.Response.StatusCode = 403;
                    ctx.Response.Write("{\"success\":false,\"message\":\"Token CSRF invalide\"}");
                    return;
                }
            }

            // Récupération de la chaîne de connexion
            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }

            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.StatusCode = 500;
                ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée\"}");
                return;
            }

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
                        var item = new Dictionary<string, object>();
                        item["ID"] = reader.IsDBNull(0) ? "" : reader.GetGuid(0).ToString();
                        item["NOM"] = reader.IsDBNull(1) ? "" : reader.GetString(1);
                        item["ORDRE"] = reader.IsDBNull(2) ? 0 : reader.GetInt32(2);
                        item["STATUT"] = !reader.IsDBNull(3) && reader.GetBoolean(3);
                        item["CREATED_AT"] = reader.IsDBNull(4) ? "" : reader.GetDateTime(4).ToString("yyyy-MM-dd HH:mm:ss");
                        niveaux.Add(item);
                    }
                }
            }

            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["niveaux"] = niveaux;

            var json = new JavaScriptSerializer().Serialize(result);
            ctx.Response.Write(json);
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "'") + "\"}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}