﻿<%@ WebHandler Language="C#" Class="EntreeAdd" %>
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class EntreeAdd : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ✅ Authentification : tous les rôles authentifiés (0 à 4)
        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            // ⚠️ Le NUMERO n'est plus envoyé par le client : il est généré côté serveur.
            string dateEntreeStr = GetString(data, "dateEntree");
            DateTime dateEntree;
            if (string.IsNullOrEmpty(dateEntreeStr) || !DateTime.TryParse(dateEntreeStr, out dateEntree))
            {
                dateEntree = DateTime.Now;
            }

            string fournisseurId = GetString(data, "fournisseurId");
            string reference = GetString(data, "reference") ?? "";
            string notes = GetString(data, "notes") ?? "";

            // En .NET 4.0, JavaScriptSerializer convertit les tableaux en ArrayList
            ArrayList lignes = data.ContainsKey("lignes") ? (ArrayList)data["lignes"] : new ArrayList();

            // Validation
            if (string.IsNullOrEmpty(fournisseurId) || lignes.Count == 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Fournisseur et au moins une ligne sont requis.\"}");
                return;
            }

            // 🔑 Récupération du code projet (Web.config : ProjectCode)
            string projetCode = AuthHelper.GetProjectCode(ctx);
            if (string.IsNullOrEmpty(projetCode)) projetCode = "TALIM";
            projetCode = projetCode.Trim().ToUpperInvariant().Replace(" ", "");

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string id = Guid.NewGuid().ToString();
            string numero;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var trans = conn.BeginTransaction())
                {
                    try
                    {
                        // -----------------------------------------------------------
                        // 1) Génération atomique du numéro de séquence pour le projet
                        //    UPDLOCK + HOLDLOCK verrouillent la ligne jusqu'au COMMIT,
                        //    ce qui empêche toute collision entre utilisateurs simultanés.
                        // -----------------------------------------------------------
                        string sqlSeq = @"
                            IF NOT EXISTS (
                                SELECT 1 FROM SENTREE_SEQUENCE WITH (UPDLOCK, HOLDLOCK)
                                WHERE PROJET_CODE = @projet
                            )
                            BEGIN
                                INSERT INTO SENTREE_SEQUENCE (PROJET_CODE, DERNIER_NUMERO)
                                VALUES (@projet, 0);
                            END

                            UPDATE SENTREE_SEQUENCE
                            SET DERNIER_NUMERO = DERNIER_NUMERO + 1
                            OUTPUT INSERTED.DERNIER_NUMERO
                            WHERE PROJET_CODE = @projet;";

                        int seq;
                        using (var cmdSeq = new SqlCommand(sqlSeq, conn, trans))
                        {
                            cmdSeq.Parameters.AddWithValue("@projet", projetCode);
                            object scalar = cmdSeq.ExecuteScalar();
                            seq = Convert.ToInt32(scalar);
                        }

                        // -----------------------------------------------------------
                        // 2) Construction du numéro : ENT-{PROJET}-{00001}
                        // -----------------------------------------------------------
                        numero = string.Format("ENT-{0}-{1:D5}", projetCode, seq);

                        // -----------------------------------------------------------
                        // 3) Vérification anti-doublon (ceinture + bretelles)
                        // -----------------------------------------------------------
                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM SENTREE WHERE NUMERO = @numero", conn, trans))
                        {
                            cmdCheck.Parameters.AddWithValue("@numero", numero);
                            int exists = Convert.ToInt32(cmdCheck.ExecuteScalar());
                            if (exists > 0)
                                throw new Exception("Le numéro généré existe déjà, veuillez réessayer.");
                        }

                        // -----------------------------------------------------------
                        // 4) Insertion de l'entête (statut = BROUILLON)
                        // -----------------------------------------------------------
                        string sqlEntete = @"
                            INSERT INTO SENTREE (ID, NUMERO, DATE_ENTREE, FOURNISSEUR_ID, REFERENCE, NOTES, STATUT, CREATED_BY, CREATED_AT)
                            VALUES (@id, @numero, @date, @four, @ref, @notes, 'BROUILLON', @userId, GETDATE())";

                        using (var cmd = new SqlCommand(sqlEntete, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@numero", numero);
                            cmd.Parameters.AddWithValue("@date", dateEntree);
                            cmd.Parameters.AddWithValue("@four", fournisseurId);
                            cmd.Parameters.AddWithValue("@ref", reference);
                            cmd.Parameters.AddWithValue("@notes", notes);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        // -----------------------------------------------------------
                        // 5) Insertion des lignes
                        // -----------------------------------------------------------
                        decimal totalHT = 0, totalTVA = 0, totalTTC = 0;

                        foreach (Dictionary<string, object> ligne in lignes)
                        {
                            // Sécurisation des valeurs (pas d'opérateur ?. en C# 4.0)
                            string articleId = null;
                            if (ligne.ContainsKey("articleId") && ligne["articleId"] != null)
                            {
                                articleId = ligne["articleId"].ToString();
                            }
                            if (string.IsNullOrEmpty(articleId)) continue;

                            decimal quantite = 0;
                            if (ligne.ContainsKey("quantite") && ligne["quantite"] != null)
                            {
                                decimal.TryParse(ligne["quantite"].ToString(), out quantite);
                            }

                            decimal prixHT = 0;
                            if (ligne.ContainsKey("prixHT") && ligne["prixHT"] != null)
                            {
                                decimal.TryParse(ligne["prixHT"].ToString(), out prixHT);
                            }

                            decimal tva = 0;
                            if (ligne.ContainsKey("tva") && ligne["tva"] != null)
                            {
                                decimal.TryParse(ligne["tva"].ToString(), out tva);
                            }

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

                        // -----------------------------------------------------------
                        // 6) Mise à jour des totaux dans l'entête
                        // -----------------------------------------------------------
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

                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                        {
                            success = true,
                            id = id,
                            numero = numero,
                            message = "Bon d'entrée créé avec succès (" + numero + ")."
                        }));
                    }
                    catch
                    {
                        try { trans.Rollback(); } catch { /* ignore */ }
                        throw;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
            }));
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null;
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
