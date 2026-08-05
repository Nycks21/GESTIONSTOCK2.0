<%@ WebHandler Language="C#" Class="AjouterMatiere" %>

using System;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterMatiere : IHttpHandler, IRequiresSessionState
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

            // Validations
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
                @"INSERT INTO [dbo].[MATIERES] 
                  (NOM, ENSEIGNANT, COEFFICIENT, HEURES_SEMAINE, CLASSE_ID, CREATED_AT, CREATED_BY, UPDATED_AT, UPDATED_BY, DELETION_AT, DELETION_BY) 
                  VALUES (@nom, @enseignant, @coeff, @heures, @classe, GETDATE(), @createdBy, GETDATE(), @updatedBy, NULL, NULL)", conn))
            {
                cmd.Parameters.Add("@nom", SqlDbType.NVarChar).Value = payload.NOM.Trim();
                cmd.Parameters.Add("@enseignant", SqlDbType.Int).Value = payload.ENSEIGNANT_ID;
                cmd.Parameters.Add("@coeff", SqlDbType.Decimal).Value = payload.COEFFICIENT;
                cmd.Parameters.Add("@heures", SqlDbType.Int).Value = payload.HEURES_SEMAINE;
                cmd.Parameters.Add("@classe", SqlDbType.Int).Value = payload.CLASSE_ID;
                cmd.Parameters.Add("@createdBy", SqlDbType.Int).Value = userId;
                cmd.Parameters.Add("@updatedBy", SqlDbType.Int).Value = userId;

                conn.Open();
                cmd.ExecuteNonQuery();
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Matière ajoutée avec succès.\"}");
        }
        catch (ArgumentException argEx)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + argEx.Message.Replace("\"", "\\\"") + "\"}");
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur lors de l'insertion en base de données.\"}");
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
        public string NOM { get; set; }
        public int ENSEIGNANT_ID { get; set; }
        public decimal COEFFICIENT { get; set; }
        public int HEURES_SEMAINE { get; set; }
        public int CLASSE_ID { get; set; }
    }
}