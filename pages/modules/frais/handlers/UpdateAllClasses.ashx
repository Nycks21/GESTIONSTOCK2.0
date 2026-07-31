<%@ WebHandler Language="C#" Class="UpdateAllClasses" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class UpdateAllClasses : IHttpHandler, IRequiresSessionState
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
        ctx.Response.Cache.SetNoStore();
        
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

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                
                // Récupérer l'année non clôturée (CLOTURE = 0)
                int anneeActiveId = 0;
                string getAnneeSql = "SELECT TOP 1 ID FROM RANNEE WHERE CLOTURE = 0 ORDER BY ANNEE DESC";
                using (SqlCommand cmd = new SqlCommand(getAnneeSql, conn))
                {
                    object result = cmd.ExecuteScalar();
                    if (result != null)
                    {
                        anneeActiveId = Convert.ToInt32(result);
                    }
                }
                
                if (anneeActiveId == 0)
                {
                    throw new Exception("Aucune année non clôturée trouvée");
                }
                
                // 1. Mettre à jour les classes dans FRAIS
                string updateSql = @"
                    UPDATE f
                    SET f.CLASSE = c.ID,
                        f.UPDATED_AT = GETDATE()
                    FROM FRAIS f
                    INNER JOIN ELEVES e ON f.MATRICULE = e.MATRICULE
                    INNER JOIN CLASSES c ON e.CLASSE = c.ID
                    WHERE e.STATUT = 'actif'
                ";
                
                int classesMisesAJour = 0;
                using (SqlCommand cmd = new SqlCommand(updateSql, conn))
                {
                    classesMisesAJour = cmd.ExecuteNonQuery();
                }
                
                // 2. Ajouter les nouveaux élèves dans FRAIS
                string insertSql = @"
                    INSERT INTO FRAIS (ANNEE_ID, MATRICULE, NOM, CLASSE, TOTAL, PAYE, CREATED_AT, UPDATED_AT)
                    SELECT 
                        @AnneeId,
                        e.MATRICULE,
                        e.NOM,
                        e.CLASSE,
                        ISNULL(t.MONTANT, 0),
                        0,
                        GETDATE(),
                        GETDATE()
                    FROM ELEVES e
                    LEFT JOIN TARIFS_ECOLAGE t ON e.CLASSE = t.CLASSE_ID AND t.ANNEE_ID = @AnneeId
                    LEFT JOIN FRAIS f ON e.MATRICULE = f.MATRICULE AND f.ANNEE_ID = @AnneeId
                    WHERE e.STATUT = 'actif'
                    AND f.MATRICULE IS NULL
                ";
                
                int elevesAjoutes = 0;
                using (SqlCommand cmd = new SqlCommand(insertSql, conn))
                {
                    cmd.Parameters.AddWithValue("@AnneeId", anneeActiveId);
                    elevesAjoutes = cmd.ExecuteNonQuery();
                }
                
                // 3. Recalculer les montants pour tous les élèves
                string recalculSql = @"
                    UPDATE f
                    SET f.TOTAL = ISNULL(t.MONTANT, 0),
                        f.UPDATED_AT = GETDATE()
                    FROM FRAIS f
                    INNER JOIN ELEVES e ON f.MATRICULE = e.MATRICULE
                    LEFT JOIN TARIFS_ECOLAGE t ON e.CLASSE = t.CLASSE_ID AND t.ANNEE_ID = @AnneeId
                    WHERE e.STATUT = 'actif'
                    AND f.ANNEE_ID = @AnneeId
                ";
                
                int montantsRecalculés = 0;
                using (SqlCommand cmd = new SqlCommand(recalculSql, conn))
                {
                    cmd.Parameters.AddWithValue("@AnneeId", anneeActiveId);
                    montantsRecalculés = cmd.ExecuteNonQuery();
                }
                
                // 4. Mettre à jour les noms des élèves dans FRAIS
                string updateNomSql = @"
                    UPDATE f
                    SET f.NOM = e.NOM,
                        f.UPDATED_AT = GETDATE()
                    FROM FRAIS f
                    INNER JOIN ELEVES e ON f.MATRICULE = e.MATRICULE
                    WHERE f.ANNEE_ID = @AnneeId
                    AND f.NOM <> e.NOM
                ";
                
                int nomsMisAJour = 0;
                using (SqlCommand cmd = new SqlCommand(updateNomSql, conn))
                {
                    cmd.Parameters.AddWithValue("@AnneeId", anneeActiveId);
                    nomsMisAJour = cmd.ExecuteNonQuery();
                }
                
                // Construction du résultat
                Dictionary<string, object> dataResult = new Dictionary<string, object>();
                dataResult["success"] = true;
                dataResult["message"] = "Mise à jour des classes et des frais terminée";
                dataResult["anneeActiveId"] = anneeActiveId;
                dataResult["classesMisesAJour"] = classesMisesAJour;
                dataResult["elevesAjoutes"] = elevesAjoutes;
                dataResult["montantsRecalculés"] = montantsRecalculés;
                dataResult["nomsMisAJour"] = nomsMisAJour;
                
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                ctx.Response.Write(serializer.Serialize(dataResult));
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            Dictionary<string, object> errorResult = new Dictionary<string, object>();
            errorResult["success"] = false;
            errorResult["message"] = ex.Message;
            
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            ctx.Response.Write(serializer.Serialize(errorResult));
        }
    }
    
    public bool IsReusable
    {
        get { return false; }
    }
}