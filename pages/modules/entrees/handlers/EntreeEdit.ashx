<%@ WebHandler Language="C#" Class="EntreeEdit" %>
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class EntreeEdit : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            string id = GetString(data, "id");
            if (string.IsNullOrEmpty(id))
                throw new Exception("ID manquant");

            string numero = GetString(data, "numero");
            if (string.IsNullOrEmpty(numero))
                throw new Exception("Numéro manquant");

            string dateEntreeStr = GetString(data, "dateEntree");
            DateTime dateEntree;
            if (string.IsNullOrEmpty(dateEntreeStr) || !DateTime.TryParse(dateEntreeStr, out dateEntree))
                dateEntree = DateTime.Now;

            string fournisseurId = GetString(data, "fournisseurId");
            if (string.IsNullOrEmpty(fournisseurId))
                throw new Exception("Fournisseur manquant");

            string reference = GetString(data, "reference") ?? "";
            string notes = GetString(data, "notes") ?? "";
            ArrayList lignes = data.ContainsKey("lignes") ? (ArrayList)data["lignes"] : new ArrayList();

            if (lignes.Count == 0)
                throw new Exception("Au moins une ligne d’article est requise.");

            // Vérifier que le bon est en BROUILLON
            if (!CanEdit(ctx, id))
                throw new Exception("Impossible de modifier un bon validé ou annulé.");

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var trans = conn.BeginTransaction())
                {
                    try
                    {
                        // Mettre à jour l'entête
                        string sqlEntete = @"
                            UPDATE SENTREE SET NUMERO = @numero, DATE_ENTREE = @date, FOURNISSEUR_ID = @four,
                                REFERENCE = @ref, NOTES = @notes, UPDATED_BY = @userId, UPDATED_AT = GETDATE()
                            WHERE ID = @id AND STATUT = 'BROUILLON' AND DELETION_AT IS NULL";
                        using (var cmd = new SqlCommand(sqlEntete, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@numero", numero);
                            cmd.Parameters.AddWithValue("@date", dateEntree);
                            cmd.Parameters.AddWithValue("@four", fournisseurId);
                            cmd.Parameters.AddWithValue("@ref", reference);
                            cmd.Parameters.AddWithValue("@notes", notes);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            if (cmd.ExecuteNonQuery() != 1)
                                throw new Exception("Impossible de modifier un bon validé ou annulé.");
                        }

                        // Supprimer les anciennes lignes
                        string sqlDeleteLignes = "DELETE FROM MLENTREE WHERE BON_ENTREE_ID = @id";
                        using (var cmd = new SqlCommand(sqlDeleteLignes, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.ExecuteNonQuery();
                        }

                        // Réinsérer les nouvelles lignes
                        decimal totalHT = 0, totalTVA = 0, totalTTC = 0;
                        foreach (Dictionary<string, object> ligne in lignes)
                        {
                            if (ligne == null) continue;

                            string articleId = null;
                            if (ligne.ContainsKey("articleId") && ligne["articleId"] != null)
                                articleId = ligne["articleId"].ToString();
                            if (string.IsNullOrEmpty(articleId)) continue;

                            decimal quantite = 0;
                            if (ligne.ContainsKey("quantite") && ligne["quantite"] != null)
                                decimal.TryParse(ligne["quantite"].ToString(), out quantite);

                            decimal prixHT = 0;
                            if (ligne.ContainsKey("prixHT") && ligne["prixHT"] != null)
                                decimal.TryParse(ligne["prixHT"].ToString(), out prixHT);

                            decimal tva = 0;
                            if (ligne.ContainsKey("tva") && ligne["tva"] != null)
                                decimal.TryParse(ligne["tva"].ToString(), out tva);

                            if (quantite <= 0 || prixHT <= 0) continue;

                            decimal ht = quantite * prixHT;
                            decimal tvaAmount = ht * (tva / 100);
                            decimal ttc = ht + tvaAmount;

                            totalHT += ht;
                            totalTVA += tvaAmount;
                            totalTTC += ttc;

                            string sqlLigne = @"
                                INSERT INTO MLENTREE (ID, BON_ENTREE_ID, ARTICLE_ID, QUANTITE, PRIX_UNITAIRE_HT, TVA_TX, PRIX_UNITAIRE_TTC, TOTAL_HT, TOTAL_TVA, TOTAL_TTC)
                                VALUES (NEWID(), @bonId, @articleId, @qte, @prixHT, @tva, @prixTTC, @totalHT, @totalTVA, @totalTTC)";
                            using (var cmd = new SqlCommand(sqlLigne, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@bonId", id);
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                cmd.Parameters.AddWithValue("@qte", quantite);
                                cmd.Parameters.AddWithValue("@prixHT", prixHT);
                                cmd.Parameters.AddWithValue("@tva", tva);
                                cmd.Parameters.AddWithValue("@prixTTC", prixHT * (1 + tva / 100));
                                cmd.Parameters.AddWithValue("@totalHT", ht);
                                cmd.Parameters.AddWithValue("@totalTVA", tvaAmount);
                                cmd.Parameters.AddWithValue("@totalTTC", ttc);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        // Mettre à jour les totaux
                        string sqlUpdateTotaux = @"
                            UPDATE SENTREE SET TOTAL_HT = @totalHT, TOTAL_TVA = @totalTVA, TOTAL_TTC = @totalTTC
                            WHERE ID = @id";
                        using (var cmd = new SqlCommand(sqlUpdateTotaux, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@totalHT", totalHT);
                            cmd.Parameters.AddWithValue("@totalTVA", totalTVA);
                            cmd.Parameters.AddWithValue("@totalTTC", totalTTC);
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.ExecuteNonQuery();
                        }

                        trans.Commit();
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, message = "Bon modifié avec succès." }));
                    }
                    catch
                    {
                        trans.Rollback();
                        throw;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    private bool CanEdit(HttpContext ctx, string bonId)
    {
        string connStr = AuthHelper.ConnectionString;
        using (var conn = new SqlConnection(connStr))
        {
            conn.Open();
            string sql = "SELECT STATUT FROM SENTREE WHERE ID = @id";
            using (var cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@id", bonId);
                var statut = cmd.ExecuteScalar() as string;
                return statut == "BROUILLON";
            }
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null;
    }

    public bool IsReusable { get { return false; } }
}
