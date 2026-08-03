<%@ WebHandler Language="C#" Class="GetClasses" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetClasses : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            // Vérification de l'authentification
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            var list = new List<object>();
            
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            string connStr = connSetting != null ? connSetting.ConnectionString : "";
            
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.StatusCode = 500;
                ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée\"}");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                
                string query = "SELECT ID, NOM FROM CLASSES WHERE STATUT = 1 ORDER BY NOM";
                
                using (var cmd = new SqlCommand(query, conn))
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        var item = new Dictionary<string, object>();
                        item["ID"] = Convert.ToInt32(rdr["ID"]);
                        item["NOM"] = rdr["NOM"].ToString();
                        list.Add(item);
                    }
                }
            }
            
            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["data"] = list;
            
            var serializer = new JavaScriptSerializer();
            ctx.Response.Write(serializer.Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "'") + "\"}");
        }
    }

    // ⚠️ PROPRIÉTÉ OBLIGATOIRE POUR IHttpHandler
    public bool IsReusable
    {
        get { return false; }
    }
}