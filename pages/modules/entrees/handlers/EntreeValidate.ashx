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
                        // 1. Vérifier le statut
                        string checkSql = "SELECT STATUT FROM SENTREE WHERE ID = @id";
                        string statut;
                        using (var cmd = new SqlCommand(checkSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            statut = cmd.ExecuteScalar() as string;
                        }
                        if (statut != "BROUILLON")
                            throw new Exception("Seul un bon en brouillon peut être validé.");

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

                        // 3. Mettre à jour le stock (utiliser un emplacement par défaut)
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
                            string checkStock = "SELECT ID FROM SSTOCK WHERE ARTICLE_ID = @articleId AND EMPLACEMENT_ID = @empl";
                            string stockId = null;
                            using (var cmd = new SqlCommand(checkStock, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                cmd.Parameters.AddWithValue("@empl", emplacementId);
                                var obj = cmd.ExecuteScalar();
                                if (obj != null)
                                    stockId = obj.ToString();
                            }

                            if (stockId != null)
                            {
                                string updateStock = "UPDATE SSTOCK SET QUANTITE = QUANTITE + @qte, UPDATED_AT = GETDATE(), UPDATED_BY = @userId WHERE ID = @stockId";
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
                                    INSERT INTO SSTOCK (ARTICLE_ID, EMPLACEMENT_ID, QUANTITE, CREATED_BY, CREATED_AT)
                                    VALUES (@articleId, @empl, @qte, @userId, GETDATE())";
                                using (var cmd = new SqlCommand(insertStock, conn, trans))
                                {
                                    cmd.Parameters.AddWithValue("@articleId", articleId);
                                    cmd.Parameters.AddWithValue("@empl", emplacementId);
                                    cmd.Parameters.AddWithValue("@qte", quantite);
                                    cmd.Parameters.AddWithValue("@userId", userId);
                                    cmd.ExecuteNonQuery();
                                }
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

    public bool IsReusable { get { return false; } }
}
