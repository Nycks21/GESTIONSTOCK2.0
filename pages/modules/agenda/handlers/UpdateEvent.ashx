<%@ WebHandler Language="C#" Class="UpdateEvent" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class UpdateEvent : IHttpHandler, IRequiresSessionState
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

            string id = GetString(data, "id", "");
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string title = GetString(data, "title", "Sans titre");
            string type = GetString(data, "type", "autre");
            string start = GetString(data, "start", null);
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

                // Vérifier que l'événement appartient à l'utilisateur
                string checkSql = "SELECT COUNT(*) FROM CALENDAREVENTS WHERE ID = @id AND (IDUSER = @userId OR IDUSER IS NULL)";
                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.AddWithValue("@id", id);
                    checkCmd.Parameters.AddWithValue("@userId", userId);
                    int count = (int)checkCmd.ExecuteScalar();
                    if (count == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Événement non trouvé ou non autorisé\"}");
                        return;
                    }
                }

                string sql = @"
                    UPDATE CALENDAREVENTS SET
                        TITRE = @title,
                        DATE_DEBUT = @start,
                        DATE_FIN = @end,
                        COULEUR = @color,
                        HEURE_DEBUT = @heureDebut,
                        HEURE_FIN = @heureFin,
                        DESCRIPTION = @description,
                        TYPE = @type,
                        LIEU = @location,
                        PUBLIQUE = @publique,
                        URL = @url
                    WHERE ID = @id";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@title", title);

                    if (string.IsNullOrEmpty(start))
                        cmd.Parameters.AddWithValue("@start", DBNull.Value);
                    else
                    {
                        DateTime startDate;
                        if (DateTime.TryParse(start, out startDate))
                            cmd.Parameters.AddWithValue("@start", startDate);
                        else
                            cmd.Parameters.AddWithValue("@start", DBNull.Value);
                    }

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
            result["message"] = "Événement modifié avec succès";

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