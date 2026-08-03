<%@ WebHandler Language="C#" Class="SaveEmploi" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;
using System.IO;

public class SaveEmploi : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        // ✅ Seuls les rôles 0, 1 et 4 peuvent modifier l'emploi du temps
        if (!AuthHelper.RequireApiAuth(ctx, 0) || !AuthHelper.CanManageEmploi(ctx))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        string json = new StreamReader(ctx.Request.InputStream).ReadToEnd();
        if (string.IsNullOrEmpty(json))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Données JSON manquantes\"}");
            return;
        }

        try
        {
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données JSON invalides\"}");
                return;
            }

            string classe = GetString(data, "classe");
            string jour = GetString(data, "jour");
            string heureDebut = GetString(data, "heureDebut");
            string heureFin = GetString(data, "heureFin");
            string matiere = GetString(data, "matiere");
            string prof = GetString(data, "prof");
            string salle = GetString(data, "salle");
            string couleur = GetString(data, "couleur");
            string type = GetString(data, "type");
            string url = GetString(data, "url");
            string description = GetString(data, "description");

            if (string.IsNullOrEmpty(classe) || string.IsNullOrEmpty(jour) || string.IsNullOrEmpty(heureDebut) || string.IsNullOrEmpty(matiere))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Champs obligatoires manquants\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string checkSql = "SELECT COUNT(*) FROM EMPLOI_TEMPS WHERE CLASSE_ID = @classe AND JOUR = @jour AND HEURE_DEBUT = @heureDebut";
                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.AddWithValue("@classe", classe);
                    checkCmd.Parameters.AddWithValue("@jour", jour);
                    checkCmd.Parameters.AddWithValue("@heureDebut", heureDebut);
                    int count = (int)checkCmd.ExecuteScalar();

                    if (count > 0)
                    {
                        string updateSql = @"
                            UPDATE EMPLOI_TEMPS SET
                                HEURE_FIN = @heureFin,
                                MATIERE_ID = @matiere,
                                PROFESSEUR = @prof,
                                SALLE = @salle,
                                COULEUR = @couleur,
                                TYPE = @type,
                                URL = @url,
                                DESCRIPTION = @description,
                                UPDATED_AT = GETDATE()
                            WHERE CLASSE_ID = @classe AND JOUR = @jour AND HEURE_DEBUT = @heureDebut";
                        using (var cmd = new SqlCommand(updateSql, conn))
                        {
                            cmd.Parameters.AddWithValue("@heureFin", string.IsNullOrEmpty(heureFin) ? (object)DBNull.Value : heureFin);
                            cmd.Parameters.AddWithValue("@matiere", matiere);
                            cmd.Parameters.AddWithValue("@prof", string.IsNullOrEmpty(prof) ? (object)DBNull.Value : prof);
                            cmd.Parameters.AddWithValue("@salle", string.IsNullOrEmpty(salle) ? (object)DBNull.Value : salle);
                            cmd.Parameters.AddWithValue("@couleur", string.IsNullOrEmpty(couleur) ? (object)DBNull.Value : couleur);
                            cmd.Parameters.AddWithValue("@type", string.IsNullOrEmpty(type) ? (object)DBNull.Value : type);
                            cmd.Parameters.AddWithValue("@url", string.IsNullOrEmpty(url) ? (object)DBNull.Value : url);
                            cmd.Parameters.AddWithValue("@description", string.IsNullOrEmpty(description) ? (object)DBNull.Value : description);
                            cmd.Parameters.AddWithValue("@classe", classe);
                            cmd.Parameters.AddWithValue("@jour", jour);
                            cmd.Parameters.AddWithValue("@heureDebut", heureDebut);
                            cmd.ExecuteNonQuery();
                        }
                    }
                    else
                    {
                        string insertSql = @"
                            INSERT INTO EMPLOI_TEMPS (CLASSE_ID, JOUR, HEURE_DEBUT, HEURE_FIN, MATIERE_ID, PROFESSEUR, SALLE, COULEUR, TYPE, URL, DESCRIPTION, CREATED_AT)
                            VALUES (@classe, @jour, @heureDebut, @heureFin, @matiere, @prof, @salle, @couleur, @type, @url, @description, GETDATE())";
                        using (var cmd = new SqlCommand(insertSql, conn))
                        {
                            cmd.Parameters.AddWithValue("@classe", classe);
                            cmd.Parameters.AddWithValue("@jour", jour);
                            cmd.Parameters.AddWithValue("@heureDebut", heureDebut);
                            cmd.Parameters.AddWithValue("@heureFin", string.IsNullOrEmpty(heureFin) ? (object)DBNull.Value : heureFin);
                            cmd.Parameters.AddWithValue("@matiere", matiere);
                            cmd.Parameters.AddWithValue("@prof", string.IsNullOrEmpty(prof) ? (object)DBNull.Value : prof);
                            cmd.Parameters.AddWithValue("@salle", string.IsNullOrEmpty(salle) ? (object)DBNull.Value : salle);
                            cmd.Parameters.AddWithValue("@couleur", string.IsNullOrEmpty(couleur) ? (object)DBNull.Value : couleur);
                            cmd.Parameters.AddWithValue("@type", string.IsNullOrEmpty(type) ? (object)DBNull.Value : type);
                            cmd.Parameters.AddWithValue("@url", string.IsNullOrEmpty(url) ? (object)DBNull.Value : url);
                            cmd.Parameters.AddWithValue("@description", string.IsNullOrEmpty(description) ? (object)DBNull.Value : description);
                            cmd.ExecuteNonQuery();
                        }
                    }
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Emploi enregistré avec succès\"}");
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

    public bool IsReusable { get { return false; } }
}