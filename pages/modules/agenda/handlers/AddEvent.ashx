<%@ WebHandler Language="C#" Class="AddEvent" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AddEvent : IHttpHandler, IRequiresSessionState
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

        // ✅ Vérifier la permission agenda
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

            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données JSON invalides\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string id = Guid.NewGuid().ToString();

            // Extraction sécurisée (sans ?.)
            string title = GetString(data, "title", "Sans titre");
            string type = GetString(data, "type", "autre");
            string start = GetString(data, "start", DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss"));
            string end = GetString(data, "end", null);
            string color = GetString(data, "color", "#6f42c1");
            string description = GetString(data, "description", "");
            string location = GetString(data, "location", "");
            string publique = GetString(data, "publique", "all");
            string url = GetString(data, "url", "");
            string heureDebut = GetString(data, "heureDebut", "");
            string heureFin = GetString(data, "heureFin", "");

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string sql = @"
                    INSERT INTO CALENDAREVENTS (
                        ID, IDUSER, TITRE, DATE_DEBUT, DATE_FIN, COULEUR, 
                        HEURE_DEBUT, HEURE_FIN, DESCRIPTION, TYPE, LIEU, PUBLIQUE, URL, CREATED_AT
                    ) VALUES (
                        @id, @userId, @title, @start, @end, @color,
                        @heureDebut, @heureFin, @description, @type, @location, @publique, @url, GETDATE()
                    )";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.Parameters.AddWithValue("@title", title);

                    DateTime startDate;
                    if (!DateTime.TryParse(start, out startDate))
                        startDate = DateTime.Now;
                    cmd.Parameters.AddWithValue("@start", startDate);

                    if (string.IsNullOrEmpty(end))
                        cmd.Parameters.AddWithValue("@end", DBNull.Value);
                    else
                    {
                        DateTime endDate;
                        if (DateTime.TryParse(end, out endDate))
                            cmd.Parameters.AddWithValue("@end", endDate);
                        else
                            cmd.Parameters.AddWithValue("@end", DBNull.Value);
                    }

                    cmd.Parameters.AddWithValue("@color", color);
                    cmd.Parameters.AddWithValue("@heureDebut", string.IsNullOrEmpty(heureDebut) ? (object)DBNull.Value : heureDebut);
                    cmd.Parameters.AddWithValue("@heureFin", string.IsNullOrEmpty(heureFin) ? (object)DBNull.Value : heureFin);
                    cmd.Parameters.AddWithValue("@description", string.IsNullOrEmpty(description) ? (object)DBNull.Value : description);
                    cmd.Parameters.AddWithValue("@type", type);
                    cmd.Parameters.AddWithValue("@location", string.IsNullOrEmpty(location) ? (object)DBNull.Value : location);
                    cmd.Parameters.AddWithValue("@publique", publique);
                    cmd.Parameters.AddWithValue("@url", string.IsNullOrEmpty(url) ? (object)DBNull.Value : url);

                    cmd.ExecuteNonQuery();
                }
            }

            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["message"] = "Événement ajouté avec succès";
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