<%@ WebHandler Language="C#" Class="AjouterPaiementFrais" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterPaiementFrais : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        try
        {
            // Vérification session
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            // Lecture du corps de la requête
            string body = "";
            using (var reader = new StreamReader(ctx.Request.InputStream))
            {
                body = reader.ReadToEnd();
            }

            var ser = new JavaScriptSerializer();
            var data = ser.Deserialize<Dictionary<string, object>>(body);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données invalides\"}");
                return;
            }

            // Extraction des données
            string matricule = GetString(data, "matricule");
            decimal montant = GetDecimal(data, "montant");
            DateTime datePaiement = GetDateTime(data, "datePaiement");
            string modePaiement = GetString(data, "modePaiement");
            string reference = GetString(data, "reference");
            string commentaire = GetString(data, "commentaire");
            string moisPaiement = GetString(data, "moisPaiement");
            string annee = GetString(data, "annee");

            if (string.IsNullOrEmpty(matricule))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Matricule requis\"}");
                return;
            }

            if (montant <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Montant invalide\"}");
                return;
            }

            // Correction : pas d'opérateur ?.
            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }

            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            string username = "Systeme";
            if (ctx.Session["username"] != null)
            {
                username = ctx.Session["username"].ToString();
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // 1. Récupérer les infos de l'élève
                string selectSql = @"
                    SELECT ID, TOTAL, PAYE, CLASSE, NOM, ANNEE_ID 
                    FROM FRAIS 
                    WHERE MATRICULE = @matricule";

                Guid fraisId = Guid.Empty;
                decimal ancienTotal = 0;
                decimal ancienPaye = 0;
                int classeId = 0;
                string nom = "";
                int anneeId = 0;

                using (var cmd = new SqlCommand(selectSql, conn))
                {
                    cmd.Parameters.AddWithValue("@matricule", matricule);
                    using (var reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            fraisId = reader.GetGuid(0);
                            ancienTotal = reader.GetDecimal(1);
                            ancienPaye = reader.GetDecimal(2);
                            classeId = reader.GetInt32(3);
                            nom = reader.GetString(4);
                            anneeId = reader.GetInt32(5);
                        }
                        else
                        {
                            ctx.Response.Write("{\"success\":false,\"message\":\"Élève non trouvé dans la table des frais\"}");
                            return;
                        }
                    }
                }

                decimal nouveauPaye = ancienPaye + montant;

                // 2. Mettre à jour FRAIS
                string updateSql = @"
                    UPDATE FRAIS 
                    SET PAYE = @nouveauPaye,
                        MODEPAIE = @modePaiement,
                        REFERENCE = @reference,
                        COMMENTAIRE = @commentaire,
                        DERNIER_PAIEMENT = @datePaiement,
                        UPDATED_AT = GETDATE()
                    WHERE ID = @fraisId";

                using (var cmd = new SqlCommand(updateSql, conn))
                {
                    cmd.Parameters.AddWithValue("@nouveauPaye", nouveauPaye);
                    cmd.Parameters.AddWithValue("@modePaiement", modePaiement);
                    if (string.IsNullOrEmpty(reference))
                        cmd.Parameters.AddWithValue("@reference", DBNull.Value);
                    else
                        cmd.Parameters.AddWithValue("@reference", reference);
                    if (string.IsNullOrEmpty(commentaire))
                        cmd.Parameters.AddWithValue("@commentaire", DBNull.Value);
                    else
                        cmd.Parameters.AddWithValue("@commentaire", commentaire);
                    cmd.Parameters.AddWithValue("@datePaiement", datePaiement);
                    cmd.Parameters.AddWithValue("@fraisId", fraisId);
                    cmd.ExecuteNonQuery();
                }

                // 3. Insérer dans l'historique
                string insertSql = @"
                    INSERT INTO HISTORIQUE_PAIEMENTS 
                    (ID, FRAIS_ID, MATRICULE, NOM, CLASSE, ANNEE_ID, 
                     MONTANT, DATE_PAIEMENT, MODE_PAIEMENT, REFERENCE, COMMENTAIRE,
                     USERNAME, ANCIEN_TOTAL, ANCIEN_PAYE, NOUVEAU_TOTAL, NOUVEAU_PAYE,
                     MOIS, ANNEE, CREATED_AT)
                    VALUES 
                    (NEWID(), @fraisId, @matricule, @nom, @classeId, @anneeId,
                     @montant, @datePaiement, @modePaiement, @reference, @commentaire,
                     @username, @ancienTotal, @ancienPaye, @ancienTotal, @nouveauPaye,
                     @moisPaiement, @annee, GETDATE())";

                using (var cmd = new SqlCommand(insertSql, conn))
                {
                    cmd.Parameters.AddWithValue("@fraisId", fraisId);
                    cmd.Parameters.AddWithValue("@matricule", matricule);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@classeId", classeId);
                    cmd.Parameters.AddWithValue("@anneeId", anneeId);
                    cmd.Parameters.AddWithValue("@montant", montant);
                    cmd.Parameters.AddWithValue("@datePaiement", datePaiement);
                    cmd.Parameters.AddWithValue("@modePaiement", modePaiement);
                    if (string.IsNullOrEmpty(reference))
                        cmd.Parameters.AddWithValue("@reference", DBNull.Value);
                    else
                        cmd.Parameters.AddWithValue("@reference", reference);
                    if (string.IsNullOrEmpty(commentaire))
                        cmd.Parameters.AddWithValue("@commentaire", DBNull.Value);
                    else
                        cmd.Parameters.AddWithValue("@commentaire", commentaire);
                    cmd.Parameters.AddWithValue("@username", username);
                    cmd.Parameters.AddWithValue("@ancienTotal", ancienTotal);
                    cmd.Parameters.AddWithValue("@ancienPaye", ancienPaye);
                    cmd.Parameters.AddWithValue("@nouveauPaye", nouveauPaye);
                    if (string.IsNullOrEmpty(moisPaiement))
                        cmd.Parameters.AddWithValue("@moisPaiement", DBNull.Value);
                    else
                        cmd.Parameters.AddWithValue("@moisPaiement", moisPaiement);
                    if (string.IsNullOrEmpty(annee))
                        cmd.Parameters.AddWithValue("@annee", DBNull.Value);
                    else
                        cmd.Parameters.AddWithValue("@annee", annee);
                    
                    cmd.ExecuteNonQuery();
                }

                ctx.Response.Write("{\"success\":true,\"message\":\"Paiement enregistré avec succès\"}");
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            string errorMsg = ex.Message.Replace("\"", "'").Replace("\r", " ").Replace("\n", " ");
            ctx.Response.Write("{\"success\":false,\"message\":\"" + errorMsg + "\"}");
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        if (data.ContainsKey(key) && data[key] != null)
            return data[key].ToString();
        return "";
    }

    private decimal GetDecimal(Dictionary<string, object> data, string key)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            decimal result;
            if (decimal.TryParse(data[key].ToString(), out result))
                return result;
        }
        return 0;
    }

    private DateTime GetDateTime(Dictionary<string, object> data, string key)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            DateTime result;
            if (DateTime.TryParse(data[key].ToString(), out result))
                return result;
        }
        return DateTime.Now;
    }

    public bool IsReusable
    {
        get { return false; }
    }
}