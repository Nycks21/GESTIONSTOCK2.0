<%@ WebHandler Language="C#" Class="GetClasse" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetClasse : IHttpHandler, IRequiresSessionState
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
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            string classeId = ctx.Request.QueryString["id"];

            var list = new List<object>();

            using (var conn = new SqlConnection(connStr))
            {
                string sql = @"
                    SELECT 
                        c.ID,
                        c.NOM,
                    FROM [dbo].[CLASSES] c
                ";

                if (!string.IsNullOrEmpty(classeId))
                {
                    sql += " WHERE c.ID = @id";
                }

                sql += " ORDER BY c.NOM";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    if (!string.IsNullOrEmpty(classeId))
                    {
                        cmd.Parameters.AddWithValue("@id", classeId);
                    }

                    conn.Open();
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            list.Add(new
                            {
                                ID = reader.IsDBNull(0) ? "" : reader.GetInt32(0).ToString(),
                                NOM = reader.IsDBNull(1) ? "" : reader.GetString(1),
                            });
                        }
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, Classes = list }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}