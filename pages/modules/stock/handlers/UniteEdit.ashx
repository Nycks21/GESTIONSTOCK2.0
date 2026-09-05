<%@ WebHandler Language="C#" Class="UniteEdit" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class UniteEdit : IHttpHandler, IRequiresSessionState
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

            string id = GetString(data, "id");
            string code = GetString(data, "code");
            string nom = GetString(data, "nom");
            bool actif = GetBool(data, "actif", true);

            if (string.IsNullOrEmpty(id) || string.IsNullOrEmpty(code) || string.IsNullOrEmpty(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID, code et nom sont obligatoires.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    UPDATE SUNITE
                    SET CODE = @code,
                        NOM = @nom,
                        ACTIVE = @active,
                        UPDATED_BY = @userId,
                        UPDATED_AT = GETDATE()
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@code", code);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Unité introuvable ou déjà supprimée.\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new { success = true, message = "Unité modifiée avec succès." }));
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
