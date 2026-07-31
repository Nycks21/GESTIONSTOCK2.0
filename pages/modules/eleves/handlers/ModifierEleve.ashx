<%@ WebHandler Language="C#" Class="ModifierEleve" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierEleve : IHttpHandler, IRequiresSessionState
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

            var payload = ser.Deserialize<ElevePayload>(body);
            if (payload == null) throw new ArgumentException("Données invalides.");

            Guid eleveGuid;
            if (string.IsNullOrEmpty(payload.ID) || !Guid.TryParse(payload.ID, out eleveGuid))
                throw new ArgumentException("ID d'élève invalide.");

            int classeId;
            if (!int.TryParse(payload.CLASSE, out classeId))
                throw new ArgumentException("Classe invalide.");

            DateTime? dateNaiss = null;
            if (!string.IsNullOrEmpty(payload.DATE_NAISSANCE))
            {
                DateTime d;
                if (DateTime.TryParse(payload.DATE_NAISSANCE, out d))
                    dateNaiss = d;
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"UPDATE [dbo].[ELEVES] SET 
                    NOM=@nom, 
                    CLASSE=@classe, 
                    EMAIL=@email, 
                    TELEPHONE=@tel, 
                    STATUT=@statut, 
                    GENRE=@genre, 
                    DATE_NAISSANCE=@dateNaiss, 
                    ADRESSE=@adresse, 
                    PARENT=@parent, 
                    UPDATED_AT=GETDATE(),
                    UPDATED_BY=@updatedBy
                  WHERE ID=@id", conn))
            {
                cmd.Parameters.AddWithValue("@id", eleveGuid);
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

                cmd.Parameters.AddWithValue("@dateNaiss", dateNaiss.HasValue ? (object)dateNaiss.Value : DBNull.Value);
                cmd.Parameters.AddWithValue("@adresse", payload.ADRESSE.Trim());
                cmd.Parameters.AddWithValue("@parent", payload.PARENT.Trim());
                cmd.Parameters.AddWithValue("@updatedBy", userId);

                conn.Open();
                if (cmd.ExecuteNonQuery() == 0)
                    throw new Exception("Élève introuvable ou aucune modification effectuée.");
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Profil élève mis à jour avec succès.\"}");
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

    private class ElevePayload
    {
        public string ID { get; set; }
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