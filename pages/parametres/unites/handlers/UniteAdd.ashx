<%@ WebHandler Language="C#" Class="UniteAdd" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class UniteAdd : IHttpHandler, IRequiresSessionState
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
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Dictionary<string, object> data = serializer.Deserialize<Dictionary<string, object>>(json);

            string code = GetString(data, "code");
            string nom = GetString(data, "nom");
            bool actif = GetBool(data, "actif", true);

            if (string.IsNullOrEmpty(code) || string.IsNullOrEmpty(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Code et nom sont obligatoires.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string newId = Guid.NewGuid().ToString(); // ← déclarée ici, accessible partout

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    INSERT INTO SUNITE (ID, CODE, NOM, ACTIVE, CREATED_BY, CREATED_AT)
                    VALUES (@id, @code, @nom, @active, @userId, GETDATE())";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", newId);
                    cmd.Parameters.AddWithValue("@code", code);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write(serializer.Serialize(new { success = true, id = newId, message = "Unité ajoutée avec succès." }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        if (data.ContainsKey(key) && data[key] != null)
            return data[key].ToString();
        return null;
    }

    private bool GetBool(Dictionary<string, object> data, string key, bool defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool val;
            if (bool.TryParse(data[key].ToString(), out val))
                return val;
        }
        return defaultValue;
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
