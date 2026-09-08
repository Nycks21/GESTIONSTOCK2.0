<%@ WebHandler Language="C#" Class="SortieValidate" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SortieValidate : IHttpHandler, IRequiresSessionState
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

            string id = null;
            if (data.ContainsKey("id") && data["id"] != null)
                id = data["id"].ToString();
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
                        // Vérifier statut et récupérer le numéro
                        string checkSql = "SELECT STATUT, NUMERO FROM SSORTIE WITH (UPDLOCK, HOLDLOCK) WHERE ID = @id AND DELETION_AT IS NULL";
                        string statut = null;
                        string numero = null;
                        using (var cmd = new SqlCommand(checkSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            using (var reader = cmd.ExecuteReader())
                            {
                                if (!reader.Read())
                                    throw new Exception("Bon de sortie introuvable.");
                                statut = reader["STATUT"].ToString();
                                numero = reader["NUMERO"].ToString();
                            }
                        }
                        if (statut != "BROUILLON")
                            throw new Exception("Seul un bon en brouillon peut être validé.");

                        // Récupérer les lignes (quantité R)
                        string lignesSql = @"
                            SELECT ARTICLE_ID, QUANTITE_R
                            FROM MLSORTIE WHERE BON_SORTIE_ID = @id AND DELETION_AT IS NULL";
                        var lignes = new List<Dictionary<string, object>>();
                        using (var cmd = new SqlCommand(lignesSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            using (var reader = cmd.ExecuteReader())
                            {
                                while (reader.Read())
                                {
                                    var ligne = new Dictionary<string, object>();
                                    ligne["articleId"] = reader["ARTICLE_ID"].ToString();
                                    ligne["qteR"] = Convert.ToDecimal(reader["QUANTITE_R"]);
                                    lignes.Add(ligne);
                                }
                            }
                        }

                        if (lignes.Count == 0)
                            throw new Exception("Impossible de valider un bon sans ligne.");

                        // Pour chaque ligne, déduire du stock et journaliser le mouvement.
                        foreach (var ligne in lignes)
                        {
                            string articleId = ligne["articleId"].ToString();
                            decimal qteR = Convert.ToDecimal(ligne["qteR"]);
                            if (qteR <= 0) continue;

                            // Verrouiller toutes les lignes disponibles afin de contrôler le total.
                            string findStock = @"
                                SELECT ID, QUANTITE_ACTUELLE
                                FROM SSTOCK WITH (UPDLOCK, HOLDLOCK)
                                WHERE ARTICLE_ID = @articleId AND DELETION_AT IS NULL AND QUANTITE_ACTUELLE > 0
                                ORDER BY QUANTITE_ACTUELLE DESC";
                            var stocks = new List<Dictionary<string, object>>();
                            using (var cmd = new SqlCommand(findStock, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                using (var reader = cmd.ExecuteReader())
                                {
                                    while (reader.Read())
                                    {
                                        var stock = new Dictionary<string, object>();
                                        stock["id"] = reader["ID"].ToString();
                                        stock["quantite"] = Convert.ToDecimal(reader["QUANTITE_ACTUELLE"]);
                                        stocks.Add(stock);
                                    }
                                }
                            }

                            decimal disponible = 0;
                            foreach (var stock in stocks)
                                disponible += Convert.ToDecimal(stock["quantite"]);
                            if (disponible < qteR)
                            {
                                // Utilisation de la concaténation classique (pas d'interpolation)
                                throw new Exception("Stock insuffisant pour l'article " + articleId +
                                    ". Disponible : " + disponible + ", demandé : " + qteR + ".");
                            }

                            decimal restant = qteR;
                            foreach (var stock in stocks)
                            {
                                if (restant <= 0) break;
                                decimal quantiteAvant = Convert.ToDecimal(stock["quantite"]);
                                decimal quantite = Math.Min(restant, quantiteAvant);
                                decimal quantiteApres = quantiteAvant - quantite;

                                string updateStock = @"
                                    UPDATE SSTOCK SET
                                        QUANTITE_MVT = QUANTITE_MVT - @qte,
                                        QUANTITE_ACTUELLE = QUANTITE_ACTUELLE - @qte,
                                        UPDATED_AT = GETDATE(), UPDATED_BY = @userId
                                    WHERE ID = @stockId AND QUANTITE_ACTUELLE >= @qte";
                                using (var cmd = new SqlCommand(updateStock, conn, trans))
                                {
                                    cmd.Parameters.AddWithValue("@qte", quantite);
                                    cmd.Parameters.AddWithValue("@userId", userId);
                                    cmd.Parameters.AddWithValue("@stockId", stock["id"]);
                                    if (cmd.ExecuteNonQuery() != 1)
                                        throw new Exception("Le stock a changé pendant la validation. Veuillez réessayer.");
                                }

                                string insertMvt = @"
                                    INSERT INTO MSTOCK
                                        (ARTICLE_ID, EMPLACEMENT_ID, TYPE, QUANTITE, QUANTITE_AVANT, QUANTITE_APRES,
                                         REFERENCE_TYPE, REFERENCE_NUMERO, MOTIF, CREATED_BY, CREATED_AT)
                                    SELECT @articleId, EMPLACEMENT_ID, 'SORTIE', @qte, @avant, @apres,
                                           'BON_SORTIE', @numero, @motif, @userId, GETDATE()
                                    FROM SSTOCK WHERE ID = @stockId";
                                using (var cmd = new SqlCommand(insertMvt, conn, trans))
                                {
                                    cmd.Parameters.AddWithValue("@articleId", articleId);
                                    cmd.Parameters.AddWithValue("@qte", quantite);
                                    cmd.Parameters.AddWithValue("@avant", quantiteAvant);
                                    cmd.Parameters.AddWithValue("@apres", quantiteApres);
                                    cmd.Parameters.AddWithValue("@numero", numero);
                                    cmd.Parameters.AddWithValue("@motif", BuildMotif("Validé", userName));
                                    cmd.Parameters.AddWithValue("@userId", userId);
                                    cmd.Parameters.AddWithValue("@stockId", stock["id"]);
                                    cmd.ExecuteNonQuery();
                                }
                                restant -= quantite;
                            }
                        }

                        // Mettre à jour le statut
                        string updateStatut = "UPDATE SSORTIE SET STATUT = 'VALIDE', VALIDE_BY = @userId, VALIDE_AT = GETDATE() WHERE ID = @id";
                        using (var cmd = new SqlCommand(updateStatut, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        trans.Commit();
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, message = "Bon de sortie validé et stock mis à jour." }));
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
