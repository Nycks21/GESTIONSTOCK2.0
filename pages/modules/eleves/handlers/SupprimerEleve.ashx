<%@ WebHandler Language="C#" Class="SupprimerEleve" %>

using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerEleve : IHttpHandler, IRequiresSessionState
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
                throw new ArgumentException("ID d'élève invalide.");

            Guid eleveGuid;
            if (!Guid.TryParse(payload.ID, out eleveGuid))
                throw new ArgumentException("ID d'élève invalide (format GUID attendu).");

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"UPDATE [dbo].[ELEVES] 
                  SET DELETION_AT = GETDATE(), 
                      DELETION_BY = @deletedBy 
                  WHERE ID = @id AND DELETION_AT IS NULL", conn))
            {
                cmd.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = eleveGuid;
                cmd.Parameters.Add("@deletedBy", SqlDbType.Int).Value = userId;

                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0)
                {
                    // Vérifier si l'élève existe déjà supprimé ou n'existe pas
                    using (var checkCmd = new SqlCommand("SELECT COUNT(*) FROM [dbo].[ELEVES] WHERE ID = @id", conn))
                    {
                        checkCmd.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = eleveGuid;
                        int exists = (int)checkCmd.ExecuteScalar();
                        if (exists == 0)
                            throw new Exception("Élève introuvable (ID=" + payload.ID + ").");
                        else
                            throw new Exception("L'élève a déjà été supprimé.");
                    }
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Élève supprimé avec succès.\"}");
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