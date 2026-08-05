<%@ WebHandler Language="C#" Class="ModifierMatiere" %>

using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierMatiere : IHttpHandler, IRequiresSessionState
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

            if (string.IsNullOrWhiteSpace(payload.NOM))
                throw new ArgumentException("Le nom est obligatoire.");
            if (payload.ENSEIGNANT_ID <= 0)
                throw new ArgumentException("L'enseignant est obligatoire.");
            if (payload.COEFFICIENT <= 0)
                throw new ArgumentException("Le coefficient doit être supérieur à 0.");
            if (payload.HEURES_SEMAINE <= 0)
                throw new ArgumentException("Les heures par semaine doivent être supérieures à 0.");
            if (payload.CLASSE_ID <= 0)
                throw new ArgumentException("La classe est obligatoire.");

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"UPDATE [dbo].[MATIERES] SET 
                    NOM = @nom,
                    ENSEIGNANT = @enseignant,
                    COEFFICIENT = @coeff,
                    HEURES_SEMAINE = @heures,
                    CLASSE_ID = @classe,
                    UPDATED_AT = GETDATE(),
                    UPDATED_BY = @updatedBy,
                    DELETION_AT = NULL
                  WHERE ID = @id", conn))
            {
                cmd.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = matiereId;
                cmd.Parameters.Add("@nom", SqlDbType.NVarChar).Value = payload.NOM.Trim();
                cmd.Parameters.Add("@enseignant", SqlDbType.Int).Value = payload.ENSEIGNANT_ID;
                cmd.Parameters.Add("@coeff", SqlDbType.Decimal).Value = payload.COEFFICIENT;
                cmd.Parameters.Add("@heures", SqlDbType.Int).Value = payload.HEURES_SEMAINE;
                cmd.Parameters.Add("@classe", SqlDbType.Int).Value = payload.CLASSE_ID;
                cmd.Parameters.Add("@updatedBy", SqlDbType.Int).Value = userId;

                conn.Open();
                if (cmd.ExecuteNonQuery() == 0)
                    throw new Exception("Matière introuvable ou aucune modification effectuée.");
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Matière modifiée avec succès.\"}");
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
        public string NOM { get; set; }
        public int ENSEIGNANT_ID { get; set; }
        public decimal COEFFICIENT { get; set; }
        public int HEURES_SEMAINE { get; set; }
        public int CLASSE_ID { get; set; }
    }
}