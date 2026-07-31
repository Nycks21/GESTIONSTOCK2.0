<%@ WebHandler Language="C#" Class="ModifierBulletin" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierBulletin : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var ser = new JavaScriptSerializer();
            var data = ser.Deserialize<Dictionary<string, object>>(body);

            if (data == null || !data.ContainsKey("ELEVE_MATRICULE") || !data.ContainsKey("MATIERE_ID") || !data.ContainsKey("PERIODE"))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Paramètres manquants (ELEVE_MATRICULE, MATIERE_ID, PERIODE)\"}");
                return;
            }

            string matricule = data["ELEVE_MATRICULE"].ToString();
            string matiereIdStr = data["MATIERE_ID"].ToString();
            string periode = data["PERIODE"].ToString();

            Guid matiereId;
            if (!Guid.TryParse(matiereIdStr, out matiereId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"MATIERE_ID invalide (format GUID attendu)\"}");
                return;
            }

            decimal? note1 = GetDecimal(data, "NOTE1");
            decimal? note2 = GetDecimal(data, "NOTE2");
            decimal? noteProjet = GetDecimal(data, "NOTE_PROJET");
            decimal? totalNote = GetDecimal(data, "TOTAL_NOTE");
            string appreciation = GetString(data, "APPRECIATION");

            // Valider les notes
            foreach (var n in new[] { note1, note2, noteProjet })
            {
                if (n.HasValue && (n.Value < 0 || n.Value > 20))
                {
                    ctx.Response.Write("{\"success\":false,\"message\":\"Les notes doivent être comprises entre 0 et 20\"}");
                    return;
                }
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.StatusCode = 500;
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérifier si le bulletin est déjà validé
                string checkSql = "SELECT STATUT FROM BULLETINS WHERE ELEVE_MATRICULE = @matricule AND MATIERE_ID = @matiereId AND PERIODE = @periode";
                string existingStatut = null;

                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.AddWithValue("@matricule", matricule);
                    checkCmd.Parameters.AddWithValue("@matiereId", matiereId);
                    checkCmd.Parameters.AddWithValue("@periode", periode);

                    var result = checkCmd.ExecuteScalar();
                    if (result != null)
                        existingStatut = result.ToString();
                }

                if (existingStatut == "Validé")
                {
                    ctx.Response.Write("{\"success\":false,\"message\":\"Ce bulletin est déjà validé définitivement. Les notes ne peuvent plus être modifiées.\"}");
                    return;
                }

                bool hasAnyNote = note1.HasValue || note2.HasValue || noteProjet.HasValue;
                string nouveauStatut = hasAnyNote ? "Enregistré" : "Non saisi";

                if (existingStatut != null)
                {
                    string updateSql = @"
                        UPDATE BULLETINS SET
                            NOTE1 = @note1,
                            NOTE2 = @note2,
                            NOTE_PROJET = @noteProjet,
                            TOTAL_NOTE = @totalNote,
                            APPRECIATION = @appreciation,
                            STATUT = @statut,
                            UPDATED_AT = GETDATE()
                        WHERE ELEVE_MATRICULE = @matricule 
                          AND MATIERE_ID = @matiereId 
                          AND PERIODE = @periode";

                    using (var cmd = new SqlCommand(updateSql, conn))
                    {
                        cmd.Parameters.AddWithValue("@matricule", matricule);
                        cmd.Parameters.AddWithValue("@matiereId", matiereId);
                        cmd.Parameters.AddWithValue("@periode", periode);
                        cmd.Parameters.AddWithValue("@note1", note1.HasValue ? (object)note1.Value : DBNull.Value);
                        cmd.Parameters.AddWithValue("@note2", note2.HasValue ? (object)note2.Value : DBNull.Value);
                        cmd.Parameters.AddWithValue("@noteProjet", noteProjet.HasValue ? (object)noteProjet.Value : DBNull.Value);
                        cmd.Parameters.AddWithValue("@totalNote", totalNote.HasValue ? (object)totalNote.Value : DBNull.Value);
                        cmd.Parameters.AddWithValue("@appreciation", string.IsNullOrEmpty(appreciation) ? (object)DBNull.Value : appreciation);
                        cmd.Parameters.AddWithValue("@statut", nouveauStatut);
                        cmd.ExecuteNonQuery();
                    }
                }
                else
                {
                    string insertSql = @"
                        INSERT INTO BULLETINS (ID, ELEVE_MATRICULE, MATIERE_ID, NOTE1, NOTE2, NOTE_PROJET, TOTAL_NOTE, APPRECIATION, PERIODE, STATUT, CREATED_AT, UPDATED_AT)
                        VALUES (NEWID(), @matricule, @matiereId, @note1, @note2, @noteProjet, @totalNote, @appreciation, @periode, @statut, GETDATE(), GETDATE())";

                    using (var cmd = new SqlCommand(insertSql, conn))
                    {
                        cmd.Parameters.AddWithValue("@matricule", matricule);
                        cmd.Parameters.AddWithValue("@matiereId", matiereId);
                        cmd.Parameters.AddWithValue("@periode", periode);
                        cmd.Parameters.AddWithValue("@note1", note1.HasValue ? (object)note1.Value : DBNull.Value);
                        cmd.Parameters.AddWithValue("@note2", note2.HasValue ? (object)note2.Value : DBNull.Value);
                        cmd.Parameters.AddWithValue("@noteProjet", noteProjet.HasValue ? (object)noteProjet.Value : DBNull.Value);
                        cmd.Parameters.AddWithValue("@totalNote", totalNote.HasValue ? (object)totalNote.Value : DBNull.Value);
                        cmd.Parameters.AddWithValue("@appreciation", string.IsNullOrEmpty(appreciation) ? (object)DBNull.Value : appreciation);
                        cmd.Parameters.AddWithValue("@statut", nouveauStatut);
                        cmd.ExecuteNonQuery();
                    }
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Bulletin mis à jour\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    private string GetString(Dictionary<string, object> dict, string key)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
            return dict[key].ToString();
        return "";
    }

    private decimal? GetDecimal(Dictionary<string, object> dict, string key)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
        {
            decimal val;
            if (decimal.TryParse(dict[key].ToString(), out val))
                return val;
        }
        return null;
    }

    public bool IsReusable { get { return false; } }
}