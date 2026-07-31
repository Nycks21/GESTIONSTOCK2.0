<%@ WebHandler Language="C#" Class="ModifierAbsence" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierAbsence : IHttpHandler, IRequiresSessionState
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

            if (data == null || !data.ContainsKey("id") || data["id"] == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant\"}");
                return;
            }

            Guid absenceId;
            if (!Guid.TryParse(data["id"].ToString(), out absenceId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide\"}");
                return;
            }

            string matricule = GetString(data, "matricule");
            string nom = GetString(data, "nom");
            string classeNom = GetString(data, "classe");
            string dateDebutStr = GetString(data, "dateDebut");
            string dateFinStr = GetString(data, "dateFin");
            string motif = GetString(data, "motif");
            bool justifie = GetBool(data, "justifie");
            string justification = GetString(data, "justification");

            if (string.IsNullOrEmpty(matricule) || string.IsNullOrEmpty(nom) || string.IsNullOrEmpty(classeNom) ||
                string.IsNullOrEmpty(dateDebutStr) || string.IsNullOrEmpty(dateFinStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Tous les champs sont obligatoires\"}");
                return;
            }

            DateTime dateDebut, dateFin;
            if (!DateTime.TryParse(dateDebutStr, out dateDebut) || !DateTime.TryParse(dateFinStr, out dateFin))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Format de date invalide\"}");
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
                UPDATE ABSENCES 
                SET ANNEE_ID = @anneeId,
                    MATRICULE = @matricule,
                    NOM = @nom,
                    CLASSE = @classeId,
                    DATE_DEBUT = @dateDebut,
                    DATE_FIN = @dateFin,
                    MOTIF = @motif,
                    JUSTIFIE = @justifie,
                    JUSTIFICATION = @justification,
                    UPDATED_AT = GETDATE()
                WHERE ID = @id", conn))
            {
                cmd.Parameters.AddWithValue("@id", absenceId);
                cmd.Parameters.AddWithValue("@anneeId", anneeId);
                cmd.Parameters.AddWithValue("@matricule", matricule);
                cmd.Parameters.AddWithValue("@nom", nom);
                cmd.Parameters.AddWithValue("@classeId", classeId);
                cmd.Parameters.AddWithValue("@dateDebut", dateDebut);
                cmd.Parameters.AddWithValue("@dateFin", dateFin);
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

            ctx.Response.Write("{\"success\":true,\"message\":\"Absence modifiée avec succès\"}");
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