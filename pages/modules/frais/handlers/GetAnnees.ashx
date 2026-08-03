<%@ WebHandler Language="C#" Class="GetAnnees" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetAnnees : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        var list = new List<object>();
        string connStr = "";
        var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
        if (connSetting != null)
        {
            connStr = connSetting.ConnectionString;
        }

        try
        {
            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand("SELECT ID, ANNEE FROM RANNEE ORDER BY ID DESC", conn))
            {
                conn.Open();
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        var item = new Dictionary<string, object>();
                        item["ID"] = Convert.ToInt32(rdr["ID"]);
                        item["ANNEE"] = rdr["ANNEE"].ToString();
                        list.Add(item);
                    }
                }
            }
            
            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["data"] = list;
            
            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}