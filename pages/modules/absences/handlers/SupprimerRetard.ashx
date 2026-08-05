<%@ WebHandler Language="C#" Class="SupprimerRetard" %>
using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerRetard : IHttpHandler, IRequiresSessionState
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
                throw new ArgumentException("ID de retard invalide.");

            Guid retardId;
            if (!Guid.TryParse(payload.ID, out retardId))
                throw new ArgumentException("ID de retard invalide (format GUID attendu).");

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérifier si le retard existe et n'est pas déjà supprimé, et s'il est justifié
                string checkSql = @"
                    SELECT 
                        CASE 
                            WHEN DELETION_AT IS NOT NULL THEN 'deleted'
                            WHEN JUSTIFIE = 1 THEN 'justified'
                            ELSE 'ok'
                        END AS Status
                    FROM RETARDS 
                    WHERE ID = @id";

                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = retardId;
                    using (var reader = checkCmd.ExecuteReader())
                    {
                        if (!reader.Read())
                        {
                            ctx.Response.Write("{\"success\":false,\"message\":\"Retard introuvable.\"}");
                            return;
                        }

                        string status = reader["Status"].ToString();
                        if (status == "deleted")
                        {
                            ctx.Response.Write("{\"success\":false,\"message\":\"Ce retard a déjà été supprimé.\"}");
                            return;
                        }
                        if (status == "justified")
                        {
                            ctx.Response.Write("{\"success\":false,\"message\":\"Impossible de supprimer un retard déjà justifié.\"}");
                            return;
                        }
                        // status == "ok" → on peut supprimer
                    }
                }

                // Suppression logique
                using (var cmd = new SqlCommand(
                    @"UPDATE [dbo].[RETARDS] 
                      SET DELETION_AT = GETDATE(), 
                          DELETION_BY = @deletedBy 
                      WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmd.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = retardId;
                    cmd.Parameters.Add("@deletedBy", SqlDbType.Int).Value = userId;

                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Aucune suppression effectuée.\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Retard supprimé avec succès.\"}");
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