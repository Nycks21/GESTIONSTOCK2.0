<%@ WebHandler Language="C#" Class="EntreeAdd" %>
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

            // Récupération des champs
            string numero = GetString(data, "numero");
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
            if (string.IsNullOrEmpty(numero) || string.IsNullOrEmpty(fournisseurId) || lignes.Count == 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Numéro, fournisseur et au moins une ligne sont requis.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var trans = conn.BeginTransaction())
                {
                    try
                    {
                        string id = Guid.NewGuid().ToString();

                        // 1. Insertion de l'entête (statut = BROUILLON)
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

                        // 2. Insertion des lignes
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

                        // 3. Mise à jour des totaux dans l'entête
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
                            message = "Bon d'entrée créé avec succès."
                        }));
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
