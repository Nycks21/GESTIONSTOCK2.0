<%@ WebHandler Language="C#" Class="ModifierRetard" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierRetard : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        // ✅ Sécurité centralisée
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

            if (data == null || !data.ContainsKey("id") || data["id"] == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant\"}");
                return;
            }

            Guid retardId;
            if (!Guid.TryParse(data["id"].ToString(), out retardId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide\"}");
                return;
            }

            string matricule = GetString(data, "matricule");
            string nom = GetString(data, "nom");
            string classeNom = GetString(data, "classe");
            string dateStr = GetString(data, "date");
            string heurePrevueStr = GetString(data, "heurePrevue");
            string heureArriveeStr = GetString(data, "heureArrivee");
            string dureeStr = GetString(data, "duree");
            string motif = GetString(data, "motif");
            bool justifie = GetBool(data, "justifie");
            string justification = GetString(data, "justification");

            if (string.IsNullOrEmpty(matricule) || string.IsNullOrEmpty(nom) || string.IsNullOrEmpty(classeNom) ||
                string.IsNullOrEmpty(dateStr) || string.IsNullOrEmpty(heurePrevueStr) || string.IsNullOrEmpty(heureArriveeStr) ||
                string.IsNullOrEmpty(dureeStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Tous les champs sont obligatoires\"}");
                return;
            }

            DateTime date;
            if (!DateTime.TryParse(dateStr, out date))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Date invalide\"}");
                return;
            }

            TimeSpan heurePrevue;
            if (!TimeSpan.TryParse(heurePrevueStr, out heurePrevue))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Heure prévue invalide\"}");
                return;
            }

            TimeSpan heureArrivee;
            if (!TimeSpan.TryParse(heureArriveeStr, out heureArrivee))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Heure d'arrivée invalide\"}");
                return;
            }

            int duree;
            if (!int.TryParse(dureeStr, out duree))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Durée invalide\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            int anneeId = GetCurrentAnneeId(connStr);
            int classeId = GetClasseIdByName(connStr, classeNom);

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(@"
                UPDATE RETARDS 
                SET ANNEE_ID = @anneeId,
                    MATRICULE = @matricule,
                    NOM = @nom,
                    CLASSE = @classeId,
                    DATE_RETARD = @date,
                    HEURE_PREVUE = @heurePrevue,
                    HEURE_ARRIVEE = @heureArrivee,
                    DUREE = @duree,
                    MOTIF = @motif,
                    JUSTIFIE = @justifie,
                    JUSTIFICATION = @justification,
                    UPDATED_AT = GETDATE()
                WHERE ID = @id", conn))
            {
                cmd.Parameters.AddWithValue("@id", retardId);
                cmd.Parameters.AddWithValue("@anneeId", anneeId);
                cmd.Parameters.AddWithValue("@matricule", matricule);
                cmd.Parameters.AddWithValue("@nom", nom);
                cmd.Parameters.AddWithValue("@classeId", classeId);
                cmd.Parameters.AddWithValue("@date", date);
                cmd.Parameters.AddWithValue("@heurePrevue", heurePrevue);
                cmd.Parameters.AddWithValue("@heureArrivee", heureArrivee);
                cmd.Parameters.AddWithValue("@duree", duree);
                cmd.Parameters.AddWithValue("@motif", string.IsNullOrEmpty(motif) ? (object)DBNull.Value : motif);
                cmd.Parameters.AddWithValue("@justifie", justifie ? 1 : 0);
                cmd.Parameters.AddWithValue("@justification", string.IsNullOrEmpty(justification) ? (object)DBNull.Value : justification);

                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0)
                {
                    ctx.Response.Write("{\"success\":false,\"message\":\"Aucune modification effectuée\"}");
                    return;
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Retard modifié avec succès\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    private int GetCurrentAnneeId(string connStr)
    {
        try
        {
            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand("SELECT TOP 1 ID FROM RANNEE WHERE CLOTURE = 0 ORDER BY DATE_DEBUT DESC", conn))
            {
                conn.Open();
                object result = cmd.ExecuteScalar();
                return result != null ? Convert.ToInt32(result) : 1;
            }
        }
        catch
        {
            return 1;
        }
    }

    private int GetClasseIdByName(string connStr, string className)
    {
        if (string.IsNullOrEmpty(className)) return 1;
        try
        {
            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand("SELECT TOP 1 ID FROM CLASSES WHERE NOM = @nom", conn))
            {
                cmd.Parameters.AddWithValue("@nom", className);
                conn.Open();
                object result = cmd.ExecuteScalar();
                return result != null ? Convert.ToInt32(result) : 1;
            }
        }
        catch
        {
            return 1;
        }
    }

    private string GetString(Dictionary<string, object> dict, string key)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
            return dict[key].ToString();
        return "";
    }

    private bool GetBool(Dictionary<string, object> dict, string key)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
        {
            try { return Convert.ToBoolean(dict[key]); }
            catch { return false; }
        }
        return false;
    }

    public bool IsReusable { get { return false; } }
}