<%@ WebHandler Language="C#" Class="AddEventFromTemplate" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AddEventFromTemplate : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        if (!AuthHelper.HasPermission("agenda"))
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

            var json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données JSON invalides\"}");
                return;
            }

            string templateId = GetString(data, "templateId", "");
            if (string.IsNullOrEmpty(templateId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID du template manquant\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string id = Guid.NewGuid().ToString();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérifier que le template existe
                string checkSql = "SELECT COUNT(*) FROM EVENTTEMPLATES WHERE ID = @templateId";
                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.AddWithValue("@templateId", templateId);
                    int count = (int)checkCmd.ExecuteScalar();
                    if (count == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Template non trouvé\"}");
                        return;
                    }
                }

                string sql = @"
                    INSERT INTO CALENDAREVENTS (
                        ID, IDUSER, TEMPLATE_ID, TITRE, DATE_DEBUT, DATE_FIN,
                        COULEUR, HEURE_DEBUT, HEURE_FIN, DESCRIPTION, TYPE, LIEU, PUBLIQUE, URL, CREATED_AT
                    )
                    SELECT 
                        @id, @userId, @templateId, NOM, GETDATE(), GETDATE(),
                        COULEUR, HEURE_DEBUT, HEURE_FIN, DESCRIPTION, TYPE, LIEU, PUBLIQUE, URL, GETDATE()
                    FROM EVENTTEMPLATES 
                    WHERE ID = @templateId";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.Parameters.AddWithValue("@templateId", templateId);
                    cmd.ExecuteNonQuery();
                }
            }

            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["message"] = "Événement ajouté depuis le modèle";
            result["id"] = id;

            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    private string GetString(Dictionary<string, object> dict, string key, string defaultValue)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
            return dict[key].ToString();
        return defaultValue;
    }

    public bool IsReusable { get { return false; } }
}