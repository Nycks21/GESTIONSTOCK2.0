<%@ WebHandler Language="C#" Class="GetTypes" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetTypes : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ✅ Authentification : tous les rôles authentifiés (0 à 4)
        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            var types = new List<Dictionary<string, object>>();
            string connStr = AuthHelper.ConnectionString;
            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = "SELECT DISTINCT TYPE FROM SEMPLACEMENT WHERE DELETION_AT IS NULL AND TYPE IS NOT NULL ORDER BY TYPE";
                using (var cmd = new SqlCommand(sql, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["VALUE"] = reader["TYPE"].ToString();
                        d["LABEL"] = reader["TYPE"].ToString();
                        types.Add(d);
                    }
                }
            }

            // Si aucun type trouvé, on propose quelques valeurs par défaut
            if (types.Count == 0)
            {
                // Utilisation de l'initialiseur de dictionnaire compatible C# 4.0
                types.Add(new Dictionary<string, object> { { "VALUE", "Entrepot" }, { "LABEL", "Entrepot" } });
                types.Add(new Dictionary<string, object> { { "VALUE", "Rayon" }, { "LABEL", "Rayon" } });
                types.Add(new Dictionary<string, object> { { "VALUE", "Etagere" }, { "LABEL", "Etagere" } });
                types.Add(new Dictionary<string, object> { { "VALUE", "Bac" }, { "LABEL", "Bac" } });
                types.Add(new Dictionary<string, object> { { "VALUE", "Zone" }, { "LABEL", "Zone" } });
            }

            var result = new { success = true, Types = types };
            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}
