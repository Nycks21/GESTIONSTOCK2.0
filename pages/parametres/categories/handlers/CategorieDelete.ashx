<%@ WebHandler Language="C#" Class="CategorieDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class CategorieDelete : IHttpHandler, IRequiresSessionState
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
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Dictionary<string, object> data = serializer.Deserialize<Dictionary<string, object>>(json);

            string id = GetString(data, "id");
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string referenceSql = @"
                    SELECT COUNT(*)
                    FROM MARTICLE
                    WHERE CATEGORIE_ID = @id";
                using (SqlCommand referenceCmd = new SqlCommand(referenceSql, conn))
                {
                    referenceCmd.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(referenceCmd.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer, codification rattachée"
                        }));
                        return;
                    }
                }
                string sql = @"
                    UPDATE SCATEGORIE
                    SET DELETION_AT = GETDATE(),
                        DELETION_BY = @userId
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Catégorie introuvable ou déjà supprimée.\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new { success = true, message = "Catégorie supprimée." }));
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

    public bool IsReusable { get { return false; } }
}
