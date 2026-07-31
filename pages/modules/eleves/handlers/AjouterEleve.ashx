<%@ WebHandler Language="C#" Class="AjouterEleve" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterEleve : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        var ser = new JavaScriptSerializer();

        // ✅ Vérification d'authentification et de rôle (Admin ou SuperAdmin)
        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        // Récupérer l'ID de l'utilisateur connecté
        int userId = AuthHelper.GetUserId(ctx);

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var payload = ser.Deserialize<ElevePayload>(body);
            if (payload == null)
                throw new ArgumentException("Données invalides.");

            // Validations
            if (string.IsNullOrWhiteSpace(payload.NOM))
                throw new ArgumentException("Le nom est obligatoire.");
            if (string.IsNullOrWhiteSpace(payload.MATRICULE))
                throw new ArgumentException("Le matricule est obligatoire.");
            if (string.IsNullOrWhiteSpace(payload.DATE_NAISSANCE))
                throw new ArgumentException("La date de naissance est obligatoire.");
            if (string.IsNullOrWhiteSpace(payload.ADRESSE))
                throw new ArgumentException("L'adresse est obligatoire.");
            if (string.IsNullOrWhiteSpace(payload.PARENT))
                throw new ArgumentException("Le parent/tuteur est obligatoire.");

            int anneeId;
            if (!int.TryParse(payload.ANNEE_ID, out anneeId))
                throw new ArgumentException("L'année scolaire est invalide.");

            int classeId;
            if (!int.TryParse(payload.CLASSE, out classeId))
                throw new ArgumentException("La classe sélectionnée est invalide.");

            DateTime dateNaiss;
            if (!DateTime.TryParse(payload.DATE_NAISSANCE, out dateNaiss))
                throw new ArgumentException("La date de naissance est invalide.");

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"INSERT INTO [dbo].[ELEVES] 
                  (ANNEE_ID, MATRICULE, NOM, CLASSE, EMAIL, TELEPHONE, STATUT, GENRE, DATE_NAISSANCE, ADRESSE, PARENT, CREATED_AT, CREATED_BY, UPDATED_AT, UPDATED_BY) 
                  VALUES (@anneeId, @matricule, @nom, @classe, @email, @tel, @statut, @genre, @dateNaiss, @adresse, @parent, GETDATE(), @createdBy, NULL, NULL)", conn))
            {
                cmd.Parameters.AddWithValue("@anneeId", anneeId);
                cmd.Parameters.AddWithValue("@matricule", payload.MATRICULE.Trim());
                cmd.Parameters.AddWithValue("@nom", payload.NOM.Trim());
                cmd.Parameters.AddWithValue("@classe", classeId);

                object emailParam = (string.IsNullOrEmpty(payload.EMAIL)) ? (object)DBNull.Value : payload.EMAIL.Trim();
                cmd.Parameters.AddWithValue("@email", emailParam);

                object telParam = (string.IsNullOrEmpty(payload.TELEPHONE)) ? (object)DBNull.Value : payload.TELEPHONE.Trim();
                cmd.Parameters.AddWithValue("@tel", telParam);

                string statut = string.IsNullOrEmpty(payload.STATUT) ? "actif" : payload.STATUT.Trim().ToLower();
                cmd.Parameters.AddWithValue("@statut", statut);

                string genre = string.IsNullOrEmpty(payload.GENRE) ? "M" : payload.GENRE.Trim().ToUpper().Substring(0, 1);
                cmd.Parameters.AddWithValue("@genre", genre);

                cmd.Parameters.AddWithValue("@dateNaiss", dateNaiss);
                cmd.Parameters.AddWithValue("@adresse", payload.ADRESSE.Trim());
                cmd.Parameters.AddWithValue("@parent", payload.PARENT.Trim());
                cmd.Parameters.AddWithValue("@createdBy", userId);

                conn.Open();
                cmd.ExecuteNonQuery();
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Élève ajouté avec succès.\"}");
        }
        catch (ArgumentException argEx)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + argEx.Message.Replace("\"", "\\\"") + "\"}");
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            if (sqlEx.Number == 2627)
                ctx.Response.Write("{\"success\":false,\"message\":\"Ce matricule existe déjà. Veuillez en choisir un autre.\"}");
            else
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur lors de l'insertion en base de données.\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class ElevePayload
    {
        public string ANNEE_ID { get; set; }
        public string MATRICULE { get; set; }
        public string NOM { get; set; }
        public string CLASSE { get; set; }
        public string EMAIL { get; set; }
        public string TELEPHONE { get; set; }
        public string STATUT { get; set; }
        public string GENRE { get; set; }
        public string DATE_NAISSANCE { get; set; }
        public string ADRESSE { get; set; }
        public string PARENT { get; set; }
    }
}