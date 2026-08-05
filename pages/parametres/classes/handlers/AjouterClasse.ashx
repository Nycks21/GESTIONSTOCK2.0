<%@ WebHandler Language="C#" Class="AjouterClasse" %>

using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterClasse : IHttpHandler, IRequiresSessionState
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

            var payload = ser.Deserialize<ClassePayload>(body);
            if (payload == null)
                throw new ArgumentException("Données invalides.");

            // Validations
            if (string.IsNullOrWhiteSpace(payload.NOM))
                throw new ArgumentException("Le nom de la classe est obligatoire.");
            if (payload.TITULAIRE_ID <= 0)
                throw new ArgumentException("Le titulaire est obligatoire.");
            if (string.IsNullOrEmpty(payload.NIVEAU_ID))
                throw new ArgumentException("Le niveau est obligatoire.");
            if (string.IsNullOrEmpty(payload.SALLE_ID))
                throw new ArgumentException("La salle est obligatoire.");

            Guid niveauGuid, salleGuid;
            if (!Guid.TryParse(payload.NIVEAU_ID, out niveauGuid))
                throw new ArgumentException("Le niveau sélectionné n'est pas valide.");
            if (!Guid.TryParse(payload.SALLE_ID, out salleGuid))
                throw new ArgumentException("La salle sélectionnée n'est pas valide.");

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"INSERT INTO [dbo].[CLASSES] 
                  (NOM, NIVEAU_ID, TITULAIRE_ID, SALLE_ID, EFFECTIF, STATUT, CREATED_AT, CREATED_BY, UPDATED_AT, UPDATED_BY) 
                  VALUES (@nom, @niv, @tit, @sal, @eff, @stat, GETDATE(), @createdBy, NULL, NULL)", conn))
            {
                cmd.Parameters.Add("@nom", SqlDbType.NVarChar).Value = payload.NOM.Trim();
                cmd.Parameters.Add("@niv", SqlDbType.UniqueIdentifier).Value = niveauGuid;
                cmd.Parameters.Add("@tit", SqlDbType.Int).Value = payload.TITULAIRE_ID;
                cmd.Parameters.Add("@sal", SqlDbType.UniqueIdentifier).Value = salleGuid;
                cmd.Parameters.Add("@eff", SqlDbType.Int).Value = payload.EFFECTIF;
                cmd.Parameters.Add("@stat", SqlDbType.Bit).Value = (payload.STATUT == "actif" || payload.STATUT == "true" || payload.STATUT == "1");
                cmd.Parameters.Add("@createdBy", SqlDbType.Int).Value = userId;

                conn.Open();
                cmd.ExecuteNonQuery();
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Classe ajoutée avec succès.\"}");
        }
        catch (ArgumentException argEx)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + argEx.Message.Replace("\"", "\\\"") + "\"}");
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            string errorMsg = sqlEx.Message.Replace("\"", "\\\"");
            ctx.Response.Write("{\"success\":false,\"message\":\"" + errorMsg + "\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class ClassePayload
    {
        public string NOM { get; set; }
        public string NIVEAU_ID { get; set; }
        public int TITULAIRE_ID { get; set; }
        public string SALLE_ID { get; set; }
        public int EFFECTIF { get; set; }
        public string STATUT { get; set; }
    }
}