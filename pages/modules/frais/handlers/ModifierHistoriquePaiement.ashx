<%@ WebHandler Language="C#" Class="ModifierHistoriquePaiement" %>
using System;
using System.Collections.Generic;  // ← AJOUTER CETTE LIGNE
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierHistoriquePaiement : IHttpHandler, IRequiresSessionState
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
            // Lire le corps de la requête
            string body = new StreamReader(ctx.Request.InputStream).ReadToEnd();
            
            var ser = new JavaScriptSerializer();
            var data = ser.Deserialize<Dictionary<string, object>>(body);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données invalides\"}");
                return;
            }

            // Extraction des valeurs
            string idStr = data.ContainsKey("id") ? data["id"].ToString() : "";
            string matricule = data.ContainsKey("matricule") ? data["matricule"].ToString() : "";
            string montantStr = data.ContainsKey("montant") ? data["montant"].ToString() : "0";
            string datePaieStr = data.ContainsKey("datePaiement") ? data["datePaiement"].ToString() : "";
            string modePaie = data.ContainsKey("modePaiement") ? data["modePaiement"].ToString() : "";
            string reference = data.ContainsKey("reference") ? data["reference"].ToString() : "";
            string commentaire = data.ContainsKey("commentaire") ? data["commentaire"].ToString() : "";
            string mois = data.ContainsKey("moisPaiement") ? data["moisPaiement"].ToString() : "";
            string annee = data.ContainsKey("annee") ? data["annee"].ToString() : "";

            if (string.IsNullOrEmpty(idStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant\"}");
                return;
            }

            Guid id = new Guid(idStr);
            decimal montant;
            if (!decimal.TryParse(montantStr, out montant) || montant <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Montant invalide\"}");
                return;
            }

            DateTime datePaie;
            if (!DateTime.TryParse(datePaieStr, out datePaie))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Date invalide\"}");
                return;
            }

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var transaction = conn.BeginTransaction())
                {
                    try
                    {
                        // 1. Récupérer l'ancien montant
                        decimal ancienMontant = 0;
                        Guid fraisId = Guid.Empty;
                        decimal ancienPaye = 0;

                        string selectSql = "SELECT MONTANT, FRAIS_ID FROM HISTORIQUE_PAIEMENTS WHERE ID = @id";
                        using (var cmd = new SqlCommand(selectSql, conn, transaction))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            using (var rdr = cmd.ExecuteReader())
                            {
                                if (rdr.Read())
                                {
                                    ancienMontant = Convert.ToDecimal(rdr["MONTANT"]);
                                    fraisId = (Guid)rdr["FRAIS_ID"];
                                }
                                else
                                {
                                    transaction.Rollback();
                                    ctx.Response.Write("{\"success\":false,\"message\":\"Paiement non trouvé\"}");
                                    return;
                                }
                            }
                        }

                        // Récupérer l'ancien PAYE
                        string selectPayeSql = "SELECT PAYE FROM FRAIS WHERE ID = @fraisId";
                        using (var cmd = new SqlCommand(selectPayeSql, conn, transaction))
                        {
                            cmd.Parameters.AddWithValue("@fraisId", fraisId);
                            ancienPaye = Convert.ToDecimal(cmd.ExecuteScalar());
                        }

                        // 2. Mettre à jour HISTORIQUE_PAIEMENTS
                        string updateHistorySql = @"
                            UPDATE HISTORIQUE_PAIEMENTS
                            SET MONTANT = @montant,
                                MOIS = @mois,
                                ANNEE = @annee,
                                DATE_PAIEMENT = @datePaie,
                                MODE_PAIEMENT = @mode,
                                REFERENCE = @ref,
                                COMMENTAIRE = @comm
                            WHERE ID = @id";

                        using (var cmd = new SqlCommand(updateHistorySql, conn, transaction))
                        {
                            cmd.Parameters.AddWithValue("@montant", montant);
                            cmd.Parameters.AddWithValue("@mois", string.IsNullOrEmpty(mois) ? (object)DBNull.Value : mois);
                            cmd.Parameters.AddWithValue("@annee", string.IsNullOrEmpty(annee) ? (object)DBNull.Value : annee);
                            cmd.Parameters.AddWithValue("@datePaie", datePaie);
                            cmd.Parameters.AddWithValue("@mode", modePaie);
                            cmd.Parameters.AddWithValue("@ref", string.IsNullOrEmpty(reference) ? (object)DBNull.Value : reference);
                            cmd.Parameters.AddWithValue("@comm", string.IsNullOrEmpty(commentaire) ? (object)DBNull.Value : commentaire);
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.ExecuteNonQuery();
                        }

                        // 3. Mettre à jour FRAIS
                        decimal nouveauPaye = ancienPaye - ancienMontant + montant;
                        
                        string updateFraisSql = "UPDATE FRAIS SET PAYE = @nouveauPaye, UPDATED_AT = GETDATE() WHERE ID = @fraisId";

                        using (var cmd = new SqlCommand(updateFraisSql, conn, transaction))
                        {
                            cmd.Parameters.AddWithValue("@nouveauPaye", nouveauPaye);
                            cmd.Parameters.AddWithValue("@fraisId", fraisId);
                            cmd.ExecuteNonQuery();
                        }

                        transaction.Commit();
                        ctx.Response.Write("{\"success\":true,\"message\":\"Paiement modifié avec succès\"}");
                    }
                    catch (Exception ex)
                    {
                        transaction.Rollback();
                        throw;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}