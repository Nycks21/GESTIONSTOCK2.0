<%@ WebHandler Language="C#" Class="UpdateAllFrais" %>
using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.SessionState;

public class UpdateAllFrais : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        try
        {
            // Vérification de l'authentification
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }
            
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée\"}");
                return;
            }

            int elevesTraites = 0;
            int nouveauxEleves = 0;
            int nomsMisAJour = 0;
            int anneeId = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // 1. Récupérer l'année active
                string getAnneeSql = "SELECT TOP 1 ID FROM RANNEE WHERE CLOTURE = 0 ORDER BY DATE_DEBUT DESC";
                using (SqlCommand cmd = new SqlCommand(getAnneeSql, conn))
                {
                    object result = cmd.ExecuteScalar();
                    if (result != null)
                    {
                        anneeId = Convert.ToInt32(result);
                    }
                }

                if (anneeId == 0)
                {
                    ctx.Response.Write("{\"success\":false,\"message\":\"Aucune année active trouvée\"}");
                    return;
                }

                // 2. Compter les élèves actifs
                string countSql = "SELECT COUNT(*) FROM ELEVES WHERE STATUT = 'actif'";
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    elevesTraites = (int)cmd.ExecuteScalar();
                }

                // 3. Vérifier les tarifs
                int tarifCount = 0;
                string checkTarifSql = "SELECT COUNT(*) FROM TARIFS_ECOLAGE WHERE ANNEE_ID = @anneeId AND STATUT = 1";
                using (SqlCommand cmd = new SqlCommand(checkTarifSql, conn))
                {
                    cmd.Parameters.AddWithValue("@anneeId", anneeId);
                    tarifCount = (int)cmd.ExecuteScalar();
                }

                if (tarifCount == 0)
                {
                    ctx.Response.Write("{\"success\":false,\"message\":\"Aucun tarif actif trouvé pour l'année en cours. Veuillez d'abord créer les tarifs par classe.\"}");
                    return;
                }

                // 4. Ajouter les nouveaux élèves
                string insertSql = @"
                    INSERT INTO FRAIS (ID, ANNEE_ID, MATRICULE, NOM, CLASSE, TOTAL, PAYE, TARIF_ID, CREATED_AT, UPDATED_AT)
                    SELECT
                        NEWID(), 
                        @anneeId, 
                        e.MATRICULE, 
                        e.NOM, 
                        e.CLASSE,
                        ISNULL(t.MONTANT, 0), 
                        0, 
                        t.ID, 
                        GETDATE(),
                        GETDATE()
                    FROM ELEVES e
                    LEFT JOIN TARIFS_ECOLAGE t ON t.CLASSE_ID = e.CLASSE AND t.ANNEE_ID = @anneeId AND t.STATUT = 1
                    WHERE e.STATUT = 'actif'
                    AND NOT EXISTS (
                        SELECT 1 FROM FRAIS f WHERE f.MATRICULE = e.MATRICULE AND f.ANNEE_ID = @anneeId
                    )
                ";
                using (SqlCommand cmd = new SqlCommand(insertSql, conn))
                {
                    cmd.Parameters.AddWithValue("@anneeId", anneeId);
                    nouveauxEleves = cmd.ExecuteNonQuery();
                }

                // 5. Mettre à jour les noms et classes
                string updateNomSql = @"
                    UPDATE f
                    SET f.NOM = e.NOM,
                        f.CLASSE = e.CLASSE,
                        f.UPDATED_AT = GETDATE()
                    FROM FRAIS f
                    INNER JOIN ELEVES e ON f.MATRICULE = e.MATRICULE
                    WHERE e.STATUT = 'actif'
                    AND f.ANNEE_ID = @anneeId
                    AND (f.NOM <> e.NOM OR f.CLASSE <> e.CLASSE)
                ";
                using (SqlCommand cmd = new SqlCommand(updateNomSql, conn))
                {
                    cmd.Parameters.AddWithValue("@anneeId", anneeId);
                    nomsMisAJour = cmd.ExecuteNonQuery();
                }
            }

            // Construction du résultat
            string jsonResult = "{";
            jsonResult += "\"success\":true,";
            jsonResult += "\"message\":\"Mise à jour des frais terminée avec succès\",";
            jsonResult += "\"anneeActiveId\":" + anneeId + ",";
            jsonResult += "\"elevesTraites\":" + elevesTraites + ",";
            jsonResult += "\"nouveauxEleves\":" + nouveauxEleves + ",";
            jsonResult += "\"nomsMisAJour\":" + nomsMisAJour;
            jsonResult += "}";

            ctx.Response.Write(jsonResult);
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            string errorMsg = ex.Message.Replace("\"", "'").Replace("\r", "").Replace("\n", "");
            ctx.Response.Write("{\"success\":false,\"message\":\"" + errorMsg + "\"}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}