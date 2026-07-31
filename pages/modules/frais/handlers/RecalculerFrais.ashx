<%@ WebHandler Language="C#" Class="RecalculerFrais" %>
using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.SessionState;

public class RecalculerFrais : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        // ✅ Sécurité : 4 vérifications essentielles
    
    // 1. Authentification
    if (context.Session == null || context.Session["authenticated"] == null || !(bool)context.Session["authenticated"])
    {
        context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
        return;
    }
    
    // 2. Token de session valide
    if (!AuthHelper.RequireApiAuth(context))
    {
        context.Response.Write("{\"success\":false,\"message\":\"Session invalide\"}");
        return;
    }
    
    // 3. Permission (SuperAdmin = 0, Admin = 1, etc.)
    int role = AuthHelper.GetUserRole(context);
    if (role < 0 || role > 1) // Permissions minimales selon le handler
    {
        context.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
        return;
    }
    
    // 4. CSRF pour les méthodes POST/PUT/DELETE
    string method = context.Request.HttpMethod.ToUpper();
    if (method == "POST" || method == "PUT" || method == "DELETE")
    {
        string token = context.Request.Headers["X-CSRF-Token"];
        string sessionToken = context.Session["CSRF_TOKEN"]?.ToString();
        if (string.IsNullOrEmpty(token) || token != sessionToken)
        {
            context.Response.Write("{\"success\":false,\"message\":\"Token CSRF invalide\"}");
            return;
        }
    }
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
            if (ConfigurationManager.ConnectionStrings["MaConnexion"] != null)
            {
                connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
            }
            
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée\"}");
                return;
            }

            int classesMisesAJour = 0;
            int montantsRecalculés = 0;
            int nouveauxEleves = 0;
            int anneeId = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                
                // 1. Récupérer l'année active (non clôturée)
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
                
                // 2. Vérifier qu'il existe des tarifs pour cette année
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

                // 3. Ajouter les nouveaux élèves (ceux qui ne sont pas encore dans FRAIS)
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

                // 4. Mettre à jour les classes dans FRAIS (synchronisation)
                string updateClasseSql = @"
                    UPDATE f
                    SET f.CLASSE = e.CLASSE,
                        f.NOM = e.NOM,
                        f.UPDATED_AT = GETDATE()
                    FROM FRAIS f
                    INNER JOIN ELEVES e ON f.MATRICULE = e.MATRICULE
                    WHERE e.STATUT = 'actif'
                    AND f.ANNEE_ID = @anneeId
                    AND (f.CLASSE <> e.CLASSE OR f.NOM <> e.NOM)
                ";
                using (SqlCommand cmd = new SqlCommand(updateClasseSql, conn))
                {
                    cmd.Parameters.AddWithValue("@anneeId", anneeId);
                    classesMisesAJour = cmd.ExecuteNonQuery();
                }

                // 5. Recalculer les montants pour tous les élèves
                string recalculSql = @"
                    UPDATE f
                    SET f.TOTAL = t.MONTANT,
                        f.TARIF_ID = t.ID,
                        f.UPDATED_AT = GETDATE()
                    FROM FRAIS f
                    INNER JOIN ELEVES e ON f.MATRICULE = e.MATRICULE
                    INNER JOIN TARIFS_ECOLAGE t ON t.CLASSE_ID = e.CLASSE AND t.ANNEE_ID = @anneeId AND t.STATUT = 1
                    WHERE e.STATUT = 'actif'
                    AND f.ANNEE_ID = @anneeId
                ";
                using (SqlCommand cmd = new SqlCommand(recalculSql, conn))
                {
                    cmd.Parameters.AddWithValue("@anneeId", anneeId);
                    montantsRecalculés = cmd.ExecuteNonQuery();
                }
            }
            
            // Construction du résultat pour .NET 4.0
            string jsonResult = "{";
            jsonResult += "\"success\":true,";
            jsonResult += "\"message\":\"Recalcul des frais terminé avec succès\",";
            jsonResult += "\"anneeActiveId\":" + anneeId + ",";
            jsonResult += "\"classesMisesAJour\":" + classesMisesAJour + ",";
            jsonResult += "\"nouveauxEleves\":" + nouveauxEleves + ",";
            jsonResult += "\"montantsRecalculés\":" + montantsRecalculés;
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