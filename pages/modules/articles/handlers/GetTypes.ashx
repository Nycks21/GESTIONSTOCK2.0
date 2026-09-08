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

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
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
                        d.Add("VALUE", reader["TYPE"].ToString());
                        d.Add("LABEL", reader["TYPE"].ToString());
                        types.Add(d);
                    }
                }
            }

            // Si aucun type trouvé, on propose quelques valeurs par défaut
            if (types.Count == 0)
            {
                var d1 = new Dictionary<string, object>();
                d1.Add("VALUE", "Entrepot");
                d1.Add("LABEL", "Entrepot");
                types.Add(d1);

                var d2 = new Dictionary<string, object>();
                d2.Add("VALUE", "Rayon");
                d2.Add("LABEL", "Rayon");
                types.Add(d2);

                var d3 = new Dictionary<string, object>();
                d3.Add("VALUE", "Etagere");
                d3.Add("LABEL", "Etagere");
                types.Add(d3);

                var d4 = new Dictionary<string, object>();
                d4.Add("VALUE", "Bac");
                d4.Add("LABEL", "Bac");
                types.Add(d4);

                var d5 = new Dictionary<string, object>();
                d5.Add("VALUE", "Zone");
                d5.Add("LABEL", "Zone");
                types.Add(d5);
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
