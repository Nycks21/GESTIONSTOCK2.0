<%@ WebHandler Language="C#" Class="ModifierHistoriquePaiement" %>
using System;
using System.Collections.Generic;
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
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        try
        {
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

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

            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }

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
                            if (string.IsNullOrEmpty(mois))
                                cmd.Parameters.AddWithValue("@mois", DBNull.Value);
                            else
                                cmd.Parameters.AddWithValue("@mois", mois);
                            if (string.IsNullOrEmpty(annee))
                                cmd.Parameters.AddWithValue("@annee", DBNull.Value);
                            else
                                cmd.Parameters.AddWithValue("@annee", annee);
                            cmd.Parameters.AddWithValue("@datePaie", datePaie);
                            cmd.Parameters.AddWithValue("@mode", modePaie);
                            if (string.IsNullOrEmpty(reference))
                                cmd.Parameters.AddWithValue("@ref", DBNull.Value);
                            else
                                cmd.Parameters.AddWithValue("@ref", reference);
                            if (string.IsNullOrEmpty(commentaire))
                                cmd.Parameters.AddWithValue("@comm", DBNull.Value);
                            else
                                cmd.Parameters.AddWithValue("@comm", commentaire);
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
                    catch
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

    public bool IsReusable
    {
        get { return false; }
    }
}