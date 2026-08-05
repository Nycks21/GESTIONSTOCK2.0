<%@ WebHandler Language="C#" Class="SupprimerAbsence" %>

using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerAbsence : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        var ser = new JavaScriptSerializer();

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        if (ctx.Request.HttpMethod != "POST")
        {
            ctx.Response.StatusCode = 405;
            ctx.Response.Write("{\"success\":false,\"message\":\"Méthode non autorisée\"}");
            return;
        }

        int userId = AuthHelper.GetUserId(ctx);

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var payload = ser.Deserialize<IdPayload>(body);

            if (payload == null || string.IsNullOrWhiteSpace(payload.ID))
                throw new ArgumentException("ID d'absence invalide.");

            Guid absenceId;
            if (!Guid.TryParse(payload.ID, out absenceId))
                throw new ArgumentException("ID d'absence invalide (format GUID attendu).");

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérifier si l'absence existe et n'est pas déjà supprimée
                // ET si elle est justifiée (JUSTIFIE = 1)
                string checkSql = @"
                    SELECT 
                        CASE 
                            WHEN DELETION_AT IS NOT NULL THEN 'deleted'
                            WHEN JUSTIFIE = 1 THEN 'justified'
                            ELSE 'ok'
                        END AS Status
                    FROM ABSENCES 
                    WHERE ID = @id";

                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = absenceId;
                    using (var reader = checkCmd.ExecuteReader())
                    {
                        if (!reader.Read())
                        {
                            ctx.Response.Write("{\"success\":false,\"message\":\"Absence introuvable.\"}");
                            return;
                        }

                        string status = reader["Status"].ToString();
                        if (status == "deleted")
                        {
                            ctx.Response.Write("{\"success\":false,\"message\":\"Cette absence a déjà été supprimée.\"}");
                            return;
                        }
                        if (status == "justified")
                        {
                            ctx.Response.Write("{\"success\":false,\"message\":\"Impossible de supprimer une absence déjà justifiée.\"}");
                            return;
                        }
                        // status == "ok" → on peut supprimer
                    }
                }

                // Suppression logique
                using (var cmd = new SqlCommand(
                    @"UPDATE [dbo].[ABSENCES] 
                      SET DELETION_AT = GETDATE(), 
                          DELETION_BY = @deletedBy 
                      WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmd.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = absenceId;
                    cmd.Parameters.Add("@deletedBy", SqlDbType.Int).Value = userId;

                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        // Sécurité supplémentaire (normalement déjà couverte par la vérification)
                        ctx.Response.Write("{\"success\":false,\"message\":\"Aucune suppression effectuée.\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Absence supprimée avec succès.\"}");
        }
        catch (ArgumentException argEx)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + argEx.Message.Replace("\"", "\\\"") + "\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class IdPayload
    {
        public string ID { get; set; }
    }
}