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
        // ✅ Authentification : tous les rôles authentifiés (0 à 4)
        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
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

                // ✅ Requête complète sans filtre ROLEID
                string sql = @"
                    SELECT
                        IDUSER,
                        USERNAME,
                        NOM,
                        ISNULL(EMAIL, '') AS EMAIL,
                        ISNULL(TELEPHONE, '') AS TELEPHONE,
                        ROLEID,
                        CREATED_AT,
                        CAST(ISNULL(ACTIVE, 0) AS BIT) AS ACTIVE
                    FROM USERS
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
                        user["EMAIL"] = reader["EMAIL"];
                        user["TELEPHONE"] = reader["TELEPHONE"];
                        user["ROLEID"] = reader["ROLEID"];
                        user["CREATED_AT"] = Convert.ToDateTime(reader["CREATED_AT"]);
                        user["ACTIVE"] = reader["ACTIVE"];
                        users.Add(user);
                    }
                }
            }

            var serializer = new JavaScriptSerializer();
            ctx.Response.Write(serializer.Serialize(users));
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
