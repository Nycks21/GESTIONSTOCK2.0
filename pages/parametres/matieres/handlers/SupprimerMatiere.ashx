<%@ WebHandler Language="C#" Class="SupprimerMatiere" %>

using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerMatiere : IHttpHandler, IRequiresSessionState
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

        int userId = AuthHelper.GetUserId(ctx);

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var payload = ser.Deserialize<MatierePayload>(body);
            if (payload == null)
                throw new ArgumentException("Données invalides.");

            Guid matiereId;
            if (string.IsNullOrEmpty(payload.ID) || !Guid.TryParse(payload.ID, out matiereId))
                throw new ArgumentException("ID de matière invalide.");

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"UPDATE [dbo].[MATIERES] SET
                    DELETION_BY = @deletionBy,
                    DELETION_AT = GETDATE()
                  WHERE ID = @id", conn))
            {
                cmd.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = matiereId;
                cmd.Parameters.Add("@deletionBy", SqlDbType.Int).Value = userId;

                conn.Open();
                if (cmd.ExecuteNonQuery() == 0)
                    throw new Exception("Matière introuvable.");
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Matière supprimée avec succès.\"}");
        }
        catch (ArgumentException argEx)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + argEx.Message.Replace("\"", "\\\"") + "\"}");
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur lors de la mise à jour.\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class MatierePayload
    {
        public string ID { get; set; }
    }
}