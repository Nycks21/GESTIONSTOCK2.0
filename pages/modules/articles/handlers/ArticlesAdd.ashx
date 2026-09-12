﻿<%@ WebHandler Language="C#" Class="ArticlesAdd" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ArticlesAdd : IHttpHandler, IRequiresSessionState
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

            // ⚠️ Le CODE n'est plus envoyé par le client : il est généré côté serveur.
            string nom = GetString(data, "nom");
            string description = GetString(data, "description") ?? "";
            string categorieId = GetString(data, "categorieId");
            string fournisseurId = GetString(data, "fournisseurId");
            string uniteId = GetString(data, "uniteId");
            string emplacementId = GetString(data, "emplacementId");
            decimal seuilAlerte = GetDecimal(data, "seuilAlerte", 0);
            decimal seuilMin = GetDecimal(data, "seuilMin", 0);
            decimal stockInitial = GetDecimal(data, "stockInitial", 0);
            bool actif = GetBool(data, "actif", true);
            bool estService = GetBool(data, "estService", false);

            if (string.IsNullOrEmpty(nom) || string.IsNullOrEmpty(uniteId) || string.IsNullOrEmpty(emplacementId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Nom, unité et emplacement sont obligatoires.\"}");
                return;
            }

            // 🔑 Récupération du code projet (Web.config : ProjectCode)
            string projetCode = AuthHelper.GetProjectCode(ctx);
            if (string.IsNullOrEmpty(projetCode)) projetCode = "TALIM";
            projetCode = projetCode.Trim().ToUpperInvariant().Replace(" ", "");

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string newId = Guid.NewGuid().ToString();
            string code;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var trans = conn.BeginTransaction())
                {
                    try
                    {
                        // -----------------------------------------------------------
                        // 1) Génération atomique du numéro de séquence pour le projet
                        //    UPDLOCK + HOLDLOCK verrouillent la ligne jusqu'au COMMIT
                        // -----------------------------------------------------------
                        string sqlSeq = @"
                            IF NOT EXISTS (
                                SELECT 1 FROM MARTICLE_SEQUENCE WITH (UPDLOCK, HOLDLOCK)
                                WHERE PROJET_CODE = @projet
                            )
                            BEGIN
                                INSERT INTO MARTICLE_SEQUENCE (PROJET_CODE, DERNIER_NUMERO)
                                VALUES (@projet, 0);
                            END

                            UPDATE MARTICLE_SEQUENCE
                            SET DERNIER_NUMERO = DERNIER_NUMERO + 1
                            OUTPUT INSERTED.DERNIER_NUMERO
                            WHERE PROJET_CODE = @projet;";

                        int numero;
                        using (var cmdSeq = new SqlCommand(sqlSeq, conn, trans))
                        {
                            cmdSeq.Parameters.AddWithValue("@projet", projetCode);
                            object scalar = cmdSeq.ExecuteScalar();
                            numero = Convert.ToInt32(scalar);
                        }

                        // -----------------------------------------------------------
                        // 2) Construction du code : ART-{PROJET}-{00001}
                        // -----------------------------------------------------------
                        code = string.Format("ART-{0}-{1:D5}", projetCode, numero);

                        // -----------------------------------------------------------
                        // 3) Vérification anti-doublon (ceinture + bretelles)
                        // -----------------------------------------------------------
                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM MARTICLE WHERE CODE = @code", conn, trans))
                        {
                            cmdCheck.Parameters.AddWithValue("@code", code);
                            int exists = Convert.ToInt32(cmdCheck.ExecuteScalar());
                            if (exists > 0)
                                throw new Exception("Le code généré existe déjà, veuillez réessayer.");
                        }

                        // -----------------------------------------------------------
                        // 4) Insertion de l'article
                        // -----------------------------------------------------------
                        string articleSql = @"
                            INSERT INTO MARTICLE (ID, CODE, NOM, DESCRIPTION, CATEGORIE_ID, FOURNISSEUR_PREFERE_ID, UNITE_MESURE_ID, EMPLACEMENT_ID,
                                                 SEUIL_ALERTE, SEUIL_MIN, ACTIVE, EST_SERVICE, CREATED_BY, CREATED_AT)
                            VALUES (@id, @code, @nom, @desc, @cat, @four, @unite, @empl, @seuil, @seuilMin, @active, @service, @userId, GETDATE())";
                        using (var cmd = new SqlCommand(articleSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", newId);
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@desc", description ?? (object)DBNull.Value);
                            cmd.Parameters.AddWithValue("@cat", string.IsNullOrEmpty(categorieId) ? (object)DBNull.Value : categorieId);
                            cmd.Parameters.AddWithValue("@four", string.IsNullOrEmpty(fournisseurId) ? (object)DBNull.Value : fournisseurId);
                            cmd.Parameters.AddWithValue("@unite", uniteId);
                            cmd.Parameters.AddWithValue("@empl", string.IsNullOrEmpty(emplacementId) ? (object)DBNull.Value : emplacementId);
                            cmd.Parameters.AddWithValue("@seuil", seuilAlerte);
                            cmd.Parameters.AddWithValue("@seuilMin", seuilMin);
                            cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                            cmd.Parameters.AddWithValue("@service", estService ? 1 : 0);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        // -----------------------------------------------------------
                        // 5) Stock initial (si fourni)
                        // -----------------------------------------------------------
                        if (stockInitial > 0 && !string.IsNullOrEmpty(emplacementId))
                        {
                            string stockSql = @"
                                INSERT INTO SSTOCK (ARTICLE_ID, EMPLACEMENT_ID, QUANTITE_MVT, QUANTITE_ACTUELLE, CREATED_BY, CREATED_AT)
                                VALUES (@articleId, @empl, @stock, @stock, @userId, GETDATE())";
                            using (var cmd = new SqlCommand(stockSql, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@articleId", newId);
                                cmd.Parameters.AddWithValue("@empl", emplacementId);
                                cmd.Parameters.AddWithValue("@stock", stockInitial);
                                cmd.Parameters.AddWithValue("@userId", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        trans.Commit();

                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = true,
                            id = newId,
                            code = code,
                            message = "Article ajouté avec succès (" + code + ")."
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

    private decimal GetDecimal(Dictionary<string, object> data, string key, decimal defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            decimal val;
            if (decimal.TryParse(data[key].ToString(), out val)) return val;
        }
        return defaultValue;
    }

    private bool GetBool(Dictionary<string, object> data, string key, bool defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool val;
            if (bool.TryParse(data[key].ToString(), out val)) return val;
        }
        return defaultValue;
    }

    public bool IsReusable { get { return false; } }
}
