<%@ WebHandler Language="C#" Class="GetUsers" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetUsers : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ✅ Vérification : Admin ou SuperAdmin uniquement
        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            var users = new List<Dictionary<string, object>>();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ✅ FILTRE : UNIQUEMENT les utilisateurs avec ROLEID = 3 (Enseignants)
                // et ACTIVE = 1 (comptes actifs)
                string sql = @"
                    SELECT 
                        IDUSER,
                        USERNAME,
                        NOM,
                        ROLEID,
                        CAST(ISNULL(ACTIVE, 0) AS BIT) AS ACTIVE
                    FROM USERS
                    WHERE ROLEID = 3 
                      AND ACTIVE = 1
                    ORDER BY NOM ASC";

                using (var cmd = new SqlCommand(sql, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var user = new Dictionary<string, object>();
                        user["IDUSER"] = reader["IDUSER"];
                        user["USERNAME"] = reader["USERNAME"];
                        user["NOM"] = reader["NOM"];
                        user["ROLEID"] = reader["ROLEID"];
                        user["ACTIVE"] = reader["ACTIVE"];
                        users.Add(user);
                    }
                }
            }

            // Format de réponse attendu par loaders.js
            var response = new Dictionary<string, object>();
            response["success"] = true;
            response["users"] = users;

            var serializer = new JavaScriptSerializer();
            ctx.Response.Write(serializer.Serialize(response));
        }
        catch (SqlException)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur base de données\"}");
        }
        catch (Exception)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur serveur\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}