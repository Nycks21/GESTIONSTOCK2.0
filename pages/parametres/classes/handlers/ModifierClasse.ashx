<%@ WebHandler Language="C#" Class="ModifierClasse" %>

using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierClasse : IHttpHandler, IRequiresSessionState
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

            int classeId;
            if (!int.TryParse(payload.ID, out classeId) || classeId <= 0)
                throw new ArgumentException("ID de classe invalide.");

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
                @"UPDATE [dbo].[CLASSES] SET 
                    NOM = @nom,
                    NIVEAU_ID = @niv,
                    TITULAIRE_ID = @tit,
                    SALLE_ID = @sal,
                    EFFECTIF = @eff,
                    STATUT = @stat,
                    UPDATED_AT = GETDATE(),
                    UPDATED_BY = @updatedBy
                  WHERE ID = @id", conn))
            {
                cmd.Parameters.Add("@id", SqlDbType.Int).Value = classeId;
                cmd.Parameters.Add("@nom", SqlDbType.NVarChar).Value = payload.NOM.Trim();
                cmd.Parameters.Add("@niv", SqlDbType.UniqueIdentifier).Value = niveauGuid;
                cmd.Parameters.Add("@tit", SqlDbType.Int).Value = payload.TITULAIRE_ID;
                cmd.Parameters.Add("@sal", SqlDbType.UniqueIdentifier).Value = salleGuid;
                cmd.Parameters.Add("@eff", SqlDbType.Int).Value = payload.EFFECTIF;
                cmd.Parameters.Add("@stat", SqlDbType.Bit).Value = (payload.STATUT == "actif" || payload.STATUT == "true" || payload.STATUT == "1");
                cmd.Parameters.Add("@updatedBy", SqlDbType.Int).Value = userId;

                conn.Open();
                if (cmd.ExecuteNonQuery() == 0)
                    throw new Exception("Classe introuvable ou aucune modification effectuée.");
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Classe modifiée avec succès.\"}");
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

    private class ClassePayload
    {
        public string ID { get; set; }
        public string NOM { get; set; }
        public string NIVEAU_ID { get; set; }
        public int TITULAIRE_ID { get; set; }
        public string SALLE_ID { get; set; }
        public int EFFECTIF { get; set; }
        public string STATUT { get; set; }
    }
}