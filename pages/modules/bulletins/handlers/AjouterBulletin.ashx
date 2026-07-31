<%@ WebHandler Language="C#" Class="AjouterBulletin" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterBulletin : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ✅ Sécurité centralisée (Admin ou SuperAdmin)
        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        JavaScriptSerializer ser = new JavaScriptSerializer();

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var data = ser.Deserialize<Dictionary<string, object>>(body);
            if (data == null)
                throw new ArgumentException("Données invalides.");

            string matricule = GetString(data, "MATRICULE");
            string matiereIdStr = GetString(data, "MATIERE_ID");
            string periode = GetString(data, "PERIODE");
            decimal? note1 = GetDecimal(data, "NOTE1");
            decimal? note2 = GetDecimal(data, "NOTE2");
            decimal? noteProjet = GetDecimal(data, "NOTE_PROJET");
            decimal? totalNote = GetDecimal(data, "TOTAL_NOTE");
            string appreciation = GetString(data, "APPRECIATION");

            if (string.IsNullOrEmpty(matricule))
                throw new ArgumentException("Le matricule est obligatoire.");
            if (string.IsNullOrEmpty(matiereIdStr))
                throw new ArgumentException("La matière est obligatoire.");
            if (string.IsNullOrEmpty(periode))
                throw new ArgumentException("La période est obligatoire.");

            Guid matiereId;
            if (!Guid.TryParse(matiereIdStr, out matiereId))
                throw new ArgumentException("MATIERE_ID invalide (format GUID attendu).");

            // Calculer TOTAL_NOTE si non fourni
            if (!totalNote.HasValue)
            {
                totalNote = CalculerTotalNote(note1, note2, noteProjet);
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérifier si un bulletin existe déjà
                string checkSql = @"SELECT COUNT(*) FROM BULLETINS 
                                    WHERE ELEVE_MATRICULE = @matricule 
                                    AND MATIERE_ID = @matiereId 
                                    AND PERIODE = @periode";

                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.AddWithValue("@matricule", matricule);
                    checkCmd.Parameters.AddWithValue("@matiereId", matiereId);
                    checkCmd.Parameters.AddWithValue("@periode", periode);

                    int existing = Convert.ToInt32(checkCmd.ExecuteScalar());
                    if (existing > 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Un bulletin existe déjà pour cet élève dans cette matière et période\"}");
                        return;
                    }
                }

                string insertSql = @"INSERT INTO BULLETINS 
                    (ID, ELEVE_MATRICULE, MATIERE_ID, NOTE1, NOTE2, NOTE_PROJET, TOTAL_NOTE, APPRECIATION, PERIODE, STATUT, CREATED_AT, UPDATED_AT) 
                    VALUES (NEWID(), @matricule, @matiereId, @note1, @note2, @noteProjet, @totalNote, @appreciation, @periode, 'Non saisi', GETDATE(), GETDATE())";

                using (var cmd = new SqlCommand(insertSql, conn))
                {
                    cmd.Parameters.AddWithValue("@matricule", matricule);
                    cmd.Parameters.AddWithValue("@matiereId", matiereId);
                    cmd.Parameters.AddWithValue("@note1", note1.HasValue ? (object)note1.Value : DBNull.Value);
                    cmd.Parameters.AddWithValue("@note2", note2.HasValue ? (object)note2.Value : DBNull.Value);
                    cmd.Parameters.AddWithValue("@noteProjet", noteProjet.HasValue ? (object)noteProjet.Value : DBNull.Value);
                    cmd.Parameters.AddWithValue("@totalNote", totalNote.HasValue ? (object)totalNote.Value : DBNull.Value);
                    cmd.Parameters.AddWithValue("@appreciation", string.IsNullOrEmpty(appreciation) ? (object)DBNull.Value : appreciation);
                    cmd.Parameters.AddWithValue("@periode", periode);

                    cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Bulletin ajouté avec succès.\"}");
        }
        catch (ArgumentException ex)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
        catch (SqlException ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur base de données\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    private decimal CalculerTotalNote(decimal? note1, decimal? note2, decimal? noteProjet)
    {
        decimal coeff1 = 1;
        decimal coeff2 = 2;
        decimal coeffProjet = 1;

        decimal total = 0;
        if (note1.HasValue && note1.Value >= 0 && note1.Value <= 20)
            total += note1.Value * coeff1;
        if (note2.HasValue && note2.Value >= 0 && note2.Value <= 20)
            total += note2.Value * coeff2;
        if (noteProjet.HasValue && noteProjet.Value >= 0 && noteProjet.Value <= 20)
            total += noteProjet.Value * coeffProjet;

        return total;
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