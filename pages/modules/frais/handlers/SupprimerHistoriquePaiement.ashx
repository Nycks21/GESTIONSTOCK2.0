<%@ WebHandler Language="C#" Class="SupprimerHistoriquePaiement" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerHistoriquePaiement : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        try
        {
            ctx.Response.ContentType = "application/json";
            ctx.Response.Charset = "utf-8";
            ctx.Response.Headers.Add("Access-Control-Allow-Origin", "*");

            // Vérifier l'authentification
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            // Lire le corps de la requête
            string body = "";
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            // Si le body est vide, essayer de lire depuis QueryString
            if (string.IsNullOrEmpty(body))
            {
                string idParam = ctx.Request.QueryString["id"];
                if (!string.IsNullOrEmpty(idParam))
                {
                    body = "{\"id\":\"" + idParam + "\"}";
                }
                else
                {
                    ctx.Response.Write("{\"success\":false,\"message\":\"Aucune donnée reçue\"}");
                    return;
                }
            }

            var ser = new JavaScriptSerializer();
            Dictionary<string, object> data = null;

            try
            {
                data = ser.Deserialize<Dictionary<string, object>>(body);
            }
            catch (Exception ex)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de parsing JSON: " + ex.Message.Replace("\"", "\\\"") + "\"}");
                return;
            }

            if (data == null || !data.ContainsKey("id"))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données invalides. Champ 'id' manquant.\"}");
                return;
            }

            string idString = data["id"].ToString();

            if (string.IsNullOrEmpty(idString))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide ou vide\"}");
                return;
            }

            Guid id = Guid.Empty;
            if (!Guid.TryParse(idString, out id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide. Format GUID attendu.\"}");
                return;
            }

            // Récupérer la chaîne de connexion
            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }

            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.StatusCode = 500;
                ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée dans Web.config\"}");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var transaction = conn.BeginTransaction())
                {
                    try
                    {
                        // 1. Récupérer le montant et le FRAIS_ID avant suppression
                        decimal montant = 0;
                        Guid fraisId = Guid.Empty;

                        string selectSql = "SELECT MONTANT, FRAIS_ID FROM HISTORIQUE_PAIEMENTS WHERE ID = @id";

                        using (var cmd = new SqlCommand(selectSql, conn, transaction))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            using (var rdr = cmd.ExecuteReader())
                            {
                                if (!rdr.Read())
                                {
                                    transaction.Rollback();
                                    ctx.Response.Write("{\"success\":false,\"message\":\"Paiement introuvable\"}");
                                    return;
                                }
                                montant = rdr.GetDecimal(0);
                                fraisId = rdr.GetGuid(1);
                            }
                        }

                        // 2. Supprimer l'historique
                        string deleteSql = "DELETE FROM HISTORIQUE_PAIEMENTS WHERE ID = @id";

                        using (var cmd = new SqlCommand(deleteSql, conn, transaction))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            int rowsAffected = cmd.ExecuteNonQuery();

                            if (rowsAffected == 0)
                            {
                                transaction.Rollback();
                                ctx.Response.Write("{\"success\":false,\"message\":\"Aucune ligne supprimée\"}");
                                return;
                            }
                        }

                        // 3. Recalculer FRAIS
                        string updateSql = @"
                            UPDATE FRAIS
                            SET PAYE = CASE 
                                        WHEN PAYE - @montant < 0 THEN 0 
                                        ELSE PAYE - @montant 
                                      END,
                                UPDATED_AT = GETDATE()
                            WHERE ID = @fraisId";

                        using (var cmd = new SqlCommand(updateSql, conn, transaction))
                        {
                            cmd.Parameters.AddWithValue("@montant", montant);
                            cmd.Parameters.AddWithValue("@fraisId", fraisId);
                            int rowsUpdated = cmd.ExecuteNonQuery();

                            if (rowsUpdated == 0)
                            {
                                transaction.Rollback();
                                ctx.Response.Write("{\"success\":false,\"message\":\"Aucun frais trouvé avec l'ID: " + fraisId.ToString() + "\"}");
                                return;
                            }
                        }

                        transaction.Commit();

                        ctx.Response.Write("{\"success\":true,\"message\":\"Paiement supprimé avec succès\", \"fraisId\":\"" + fraisId.ToString() + "\", \"montant\":\"" + montant.ToString() + "\"}");
                    }
                    catch (SqlException sqlEx)
                    {
                        transaction.Rollback();
                        ctx.Response.StatusCode = 500;
                        ctx.Response.Write("{\"success\":false,\"message\":\"Erreur SQL: " + sqlEx.Message.Replace("\"", "\\\"") + "\", \"errorCode\":\"" + sqlEx.Number.ToString() + "\"}");
                    }
                    catch (Exception ex)
                    {
                        transaction.Rollback();
                        ctx.Response.StatusCode = 500;
                        ctx.Response.Write("{\"success\":false,\"message\":\"Erreur: " + ex.Message.Replace("\"", "\\\"") + "\"}");
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur serveur: " + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}