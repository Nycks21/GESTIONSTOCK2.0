<%@ WebHandler Language="C#" Class="EntreeValidate" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class EntreeValidate : IHttpHandler, IRequiresSessionState
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
            var data = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(json);
            string id = data.ContainsKey("id") ? data["id"].ToString() : null;
            if (string.IsNullOrEmpty(id))
                throw new Exception("ID manquant");

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var trans = conn.BeginTransaction())
                {
                    try
                    {
                        string userName = GetUserName(conn, trans, userId);
                        // 1. Vérifier le statut et récupérer le numéro
                        string checkSql = "SELECT STATUT, NUMERO FROM SENTREE WHERE ID = @id";
                        string statut = null;
                        string numero = null;
                        using (var cmd = new SqlCommand(checkSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            using (var reader = cmd.ExecuteReader())
                            {
                                if (reader.Read())
                                {
                                    statut = reader["STATUT"] as string;
                                    numero = reader["NUMERO"] as string;
                                }
                            }
                        }

                        if (statut != "BROUILLON")
                            throw new Exception("Seul un bon en brouillon peut être validé.");

                        if (string.IsNullOrEmpty(numero))
                            throw new Exception("Numéro de bon introuvable.");

                        // 2. Récupérer les lignes
                        string lignesSql = @"
                            SELECT ARTICLE_ID, QUANTITE, PRIX_UNITAIRE_HT, TVA_TX
                            FROM MLENTREE WHERE BON_ENTREE_ID = @id";
                        var lignes = new List<Dictionary<string, object>>();
                        using (var cmd = new SqlCommand(lignesSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            using (var reader = cmd.ExecuteReader())
                            {
                                while (reader.Read())
                                {
                                    var l = new Dictionary<string, object>();
                                    l["articleId"] = reader["ARTICLE_ID"].ToString();
                                    l["quantite"] = Convert.ToDecimal(reader["QUANTITE"]);
                                    l["prixHT"] = Convert.ToDecimal(reader["PRIX_UNITAIRE_HT"]);
                                    l["tva"] = Convert.ToDecimal(reader["TVA_TX"]);
                                    lignes.Add(l);
                                }
                            }
                        }

                        if (lignes.Count == 0)
                            throw new Exception("Impossible de valider un bon sans ligne.");

                        // 3. Ajouter les quantités et journaliser les mouvements.
                        string getEmplacement = "SELECT TOP 1 ID FROM SEMPLACEMENT WHERE ACTIVE = 1 AND DELETION_AT IS NULL";
                        string emplacementId;
                        using (var cmd = new SqlCommand(getEmplacement, conn, trans))
                        {
                            var obj = cmd.ExecuteScalar();
                            if (obj == null)
                                throw new Exception("Aucun emplacement actif trouvé.");
                            emplacementId = obj.ToString();
                        }

                        foreach (var ligne in lignes)
                        {
                            string articleId = ligne["articleId"].ToString();
                            decimal quantite = Convert.ToDecimal(ligne["quantite"]);

                            // Vérifier si une ligne de stock existe
                            string checkStock = @"
                                SELECT ID, QUANTITE_ACTUELLE
                                FROM SSTOCK WITH (UPDLOCK, HOLDLOCK)
                                WHERE ARTICLE_ID = @articleId AND EMPLACEMENT_ID = @empl AND DELETION_AT IS NULL";
                            string stockId = null;
                            decimal quantiteAvant = 0;
                            using (var cmd = new SqlCommand(checkStock, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                cmd.Parameters.AddWithValue("@empl", emplacementId);
                                using (var reader = cmd.ExecuteReader())
                                {
                                    if (reader.Read())
                                    {
                                        stockId = reader["ID"].ToString();
                                        quantiteAvant = Convert.ToDecimal(reader["QUANTITE_ACTUELLE"]);
                                    }
                                }
                            }

                            if (stockId != null)
                            {
                                string updateStock = @"
                                    UPDATE SSTOCK SET
                                        QUANTITE_MVT = QUANTITE_MVT + @qte,
                                        QUANTITE_ACTUELLE = QUANTITE_ACTUELLE + @qte,
                                        UPDATED_AT = GETDATE(), UPDATED_BY = @userId
                                    WHERE ID = @stockId";
                                using (var cmd = new SqlCommand(updateStock, conn, trans))
                                {
                                    cmd.Parameters.AddWithValue("@qte", quantite);
                                    cmd.Parameters.AddWithValue("@userId", userId);
                                    cmd.Parameters.AddWithValue("@stockId", stockId);
                                    cmd.ExecuteNonQuery();
                                }
                            }
                            else
                            {
                                string insertStock = @"
                                    INSERT INTO SSTOCK (ARTICLE_ID, EMPLACEMENT_ID, QUANTITE_INITIAL, QUANTITE_MVT, QUANTITE_ACTUELLE, CREATED_BY, CREATED_AT)
                                    VALUES (@articleId, @empl, 0, @qte, @qte, @userId, GETDATE())";
                                using (var cmd = new SqlCommand(insertStock, conn, trans))
                                {
                                    cmd.Parameters.AddWithValue("@articleId", articleId);
                                    cmd.Parameters.AddWithValue("@empl", emplacementId);
                                    cmd.Parameters.AddWithValue("@qte", quantite);
                                    cmd.Parameters.AddWithValue("@userId", userId);
                                    cmd.ExecuteNonQuery();
                                }
                            }

                            string insertMvt = @"
                                INSERT INTO MSTOCK
                                    (ARTICLE_ID, EMPLACEMENT_ID, TYPE, QUANTITE, QUANTITE_AVANT, QUANTITE_APRES,
                                     REFERENCE_TYPE, REFERENCE_NUMERO, MOTIF, CREATED_BY, CREATED_AT)
                                VALUES
                                    (@articleId, @empl, 'ENTREE', @qte, @avant, @apres,
                                     'BON_ENTREE', @numero, @motif, @userId, GETDATE())";
                            using (var cmd = new SqlCommand(insertMvt, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                cmd.Parameters.AddWithValue("@empl", emplacementId);
                                cmd.Parameters.AddWithValue("@qte", quantite);
                                cmd.Parameters.AddWithValue("@avant", quantiteAvant);
                                cmd.Parameters.AddWithValue("@apres", quantiteAvant + quantite);
                                cmd.Parameters.AddWithValue("@numero", numero);
                                cmd.Parameters.AddWithValue("@motif", BuildMotif("Validation", userName));
                                cmd.Parameters.AddWithValue("@userId", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        // 4. Mettre à jour le statut du bon
                        string updateStatut = "UPDATE SENTREE SET STATUT = 'VALIDE', VALIDE_BY = @userId, VALIDE_AT = GETDATE() WHERE ID = @id";
                        using (var cmd = new SqlCommand(updateStatut, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        trans.Commit();
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, message = "Bon validé et stock mis à jour." }));
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

    private string GetUserName(SqlConnection conn, SqlTransaction trans, int userId)
    {
        using (var cmd = new SqlCommand("SELECT NOM FROM USERS WHERE IDUSER = @userId", conn, trans))
        {
            cmd.Parameters.AddWithValue("@userId", userId);
            var value = cmd.ExecuteScalar();
            if (value == null || value == DBNull.Value)
                throw new Exception("Utilisateur connecté introuvable.");
            return value.ToString().Trim();
        }
    }

    private string BuildMotif(string motif, string userName)
    {
        return (motif ?? "Action").Trim() + " par @" + userName;
    }

    public bool IsReusable { get { return false; } }
}
