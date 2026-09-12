﻿<%@ WebHandler Language="C#" Class="SortieAdd" %>
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SortieAdd : IHttpHandler, IRequiresSessionState
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
            string dateSortieStr = GetString(data, "dateSortie");
            DateTime dateSortie;
            if (string.IsNullOrEmpty(dateSortieStr) || !DateTime.TryParse(dateSortieStr, out dateSortie))
                dateSortie = DateTime.Now;

            string destination = GetString(data, "destination") ?? "";
            string nom = GetString(data, "nom") ?? "";
            string fonction = GetString(data, "fonction") ?? "";
            string notes = GetString(data, "notes") ?? "";

            ArrayList lignes = data.ContainsKey("lignes") ? (ArrayList)data["lignes"] : new ArrayList();

            if (string.IsNullOrEmpty(destination) || lignes.Count == 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Destination et au moins une ligne sont requis.\"}");
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
                                SELECT 1 FROM SSORTIE_SEQUENCE WITH (UPDLOCK, HOLDLOCK)
                                WHERE PROJET_CODE = @projet
                            )
                            BEGIN
                                INSERT INTO SSORTIE_SEQUENCE (PROJET_CODE, DERNIER_NUMERO)
                                VALUES (@projet, 0);
                            END

                            UPDATE SSORTIE_SEQUENCE
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
                        // 2) Construction du numéro : SOR-{PROJET}-{00001}
                        // -----------------------------------------------------------
                        numero = string.Format("SOR-{0}-{1:D5}", projetCode, seq);

                        // -----------------------------------------------------------
                        // 3) Vérification anti-doublon (ceinture + bretelles)
                        // -----------------------------------------------------------
                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM SSORTIE WHERE NUMERO = @numero", conn, trans))
                        {
                            cmdCheck.Parameters.AddWithValue("@numero", numero);
                            int exists = Convert.ToInt32(cmdCheck.ExecuteScalar());
                            if (exists > 0)
                                throw new Exception("Le numéro généré existe déjà, veuillez réessayer.");
                        }

                        // -----------------------------------------------------------
                        // 4) Création de l'entête avec STATUT = 'BROUILLON'
                        // -----------------------------------------------------------
                        string sqlEntete = @"
                            INSERT INTO SSORTIE (ID, NUMERO, DATE_SORTIE, DESTINATION, NOM, FONCTION, NOTES, STATUT, CREATED_BY, CREATED_AT)
                            VALUES (@id, @numero, @date, @dest, @nom, @fonction, @notes, 'BROUILLON', @userId, GETDATE())";
                        using (var cmd = new SqlCommand(sqlEntete, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@numero", numero);
                            cmd.Parameters.AddWithValue("@date", dateSortie);
                            cmd.Parameters.AddWithValue("@dest", destination);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@fonction", fonction);
                            cmd.Parameters.AddWithValue("@notes", notes);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        // -----------------------------------------------------------
                        // 5) Insertion des lignes
                        // -----------------------------------------------------------
                        foreach (Dictionary<string, object> ligne in lignes)
                        {
                            string articleId = null;
                            if (ligne.ContainsKey("articleId") && ligne["articleId"] != null)
                                articleId = ligne["articleId"].ToString();
                            if (string.IsNullOrEmpty(articleId)) continue;

                            decimal qteD = 0, qteR = 0;
                            if (ligne.ContainsKey("quantiteD") && ligne["quantiteD"] != null)
                                decimal.TryParse(ligne["quantiteD"].ToString(), out qteD);
                            if (ligne.ContainsKey("quantiteR") && ligne["quantiteR"] != null)
                                decimal.TryParse(ligne["quantiteR"].ToString(), out qteR);

                            string observations = "";
                            if (ligne.ContainsKey("observations") && ligne["observations"] != null)
                                observations = ligne["observations"].ToString();

                            string sqlLigne = @"
                                INSERT INTO MLSORTIE (ID, BON_SORTIE_ID, ARTICLE_ID, QUANTITE_D, QUANTITE_R, OBSERVATIONS, CREATED_BY, CREATED_AT)
                                VALUES (NEWID(), @bonId, @articleId, @qteD, @qteR, @obs, @userId, GETDATE())";
                            using (var cmd = new SqlCommand(sqlLigne, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@bonId", id);
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                cmd.Parameters.AddWithValue("@qteD", qteD);
                                cmd.Parameters.AddWithValue("@qteR", qteR);
                                cmd.Parameters.AddWithValue("@obs", observations);
                                cmd.Parameters.AddWithValue("@userId", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        // 6. Pas de mise à jour du statut (reste 'BROUILLON')
                        trans.Commit();

                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                        {
                            success = true,
                            id = id,
                            numero = numero,
                            message = "Bon de sortie créé avec succès (" + numero + ")."
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

    public bool IsReusable { get { return false; } }
}
