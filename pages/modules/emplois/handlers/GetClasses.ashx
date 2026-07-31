<%@ WebHandler Language="C#" Class="GetClasses" %>
using System;
using System.Collections.Generic;
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

        // ✅ Sécurité centralisée (Admin ou SuperAdmin)
        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        var list = new List<object>();
        string connStr = AuthHelper.ConnectionString;

        if (string.IsNullOrEmpty(connStr))
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion manquante\"}");
            return;
        }

        try
        {
            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand())
            {
                cmd.Connection = conn;

                int userRole = AuthHelper.GetUserRole(ctx);
                if (userRole == 3)
                {
                    // Professeur : ne renvoyer que les classes liées à ses matières
                    cmd.CommandText = @"SELECT DISTINCT c.ID, c.NOM
                                         FROM CLASSES c
                                         INNER JOIN MATIERES m ON m.CLASSE_ID = c.ID
                                         WHERE m.ENSEIGNANT = @professeurId
                                         ORDER BY c.NOM";
                    cmd.Parameters.AddWithValue("@professeurId", AuthHelper.GetUserId(ctx));
                }
                else
                {
                    cmd.CommandText = "SELECT ID, NOM FROM CLASSES ORDER BY NOM";
                }

                conn.Open();
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        list.Add(new
                        {
                            ID = rdr["ID"].ToString(),
                            NOM = rdr["NOM"].ToString()
                        });
                    }
                }
            }
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, data = list }));
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