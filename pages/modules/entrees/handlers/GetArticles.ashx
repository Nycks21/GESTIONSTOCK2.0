<%@ WebHandler Language="C#" Class="GetArticles" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetArticles : IHttpHandler, IRequiresSessionState
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
            string connStr = AuthHelper.ConnectionString;
            var list = new List<object>();
            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = "SELECT ID, CODE, NOM FROM MARTICLE WHERE ACTIVE = 1 AND DELETION_AT IS NULL ORDER BY NOM";
                using (var cmd = new SqlCommand(sql, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var obj = new Dictionary<string, object>();
                        obj["ID"] = reader["ID"].ToString();
                        obj["CODE"] = reader["CODE"].ToString();
                        obj["NOM"] = reader["NOM"].ToString();
                        list.Add(obj);
                    }
                }
            }
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, Articles = list }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}
