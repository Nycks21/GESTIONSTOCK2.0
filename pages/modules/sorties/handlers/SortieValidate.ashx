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
                        // Vérifier statut
                        string checkSql = "SELECT STATUT FROM SSORTIE WHERE ID = @id";
                        string statut;
                        using (var cmd = new SqlCommand(checkSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            var obj = cmd.ExecuteScalar();
                            statut = obj != null ? obj.ToString() : null;
                        }
                        if (statut != "BROUILLON")
                            throw new Exception("Seul un bon en brouillon peut être validé.");

                        // Récupérer les lignes (quantité R)
                        string lignesSql = @"
                            SELECT ARTICLE_ID, QUANTITE_R
                            FROM MLSORTIE WHERE BON_SORTIE_ID = @id AND DELETION_AT IS NULL";
                        var lignes = new List<dynamic>();
                        using (var cmd = new SqlCommand(lignesSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            using (var reader = cmd.ExecuteReader())
                            {
                                while (reader.Read())
                                {
                                    lignes.Add(new
                                    {
                                        articleId = reader["ARTICLE_ID"].ToString(),
                                        qteR = Convert.ToDecimal(reader["QUANTITE_R"])
                                    });
                                }
                            }
                        }

                        // Pour chaque ligne, déduire du stock
                        foreach (var ligne in lignes)
                        {
                            if (ligne.qteR == 0) continue;

                            // Trouver un emplacement avec quantité suffisante
                            string findStock = @"
                                SELECT TOP 1 ID, QUANTITE
                                FROM SSTOCK
                                WHERE ARTICLE_ID = @articleId AND DELETION_AT IS NULL AND QUANTITE >= @qte
                                ORDER BY QUANTITE DESC";
                            string stockId = null;
                            using (var cmd = new SqlCommand(findStock, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@articleId", ligne.articleId);
                                cmd.Parameters.AddWithValue("@qte", ligne.qteR);
                                using (var reader = cmd.ExecuteReader())
                                {
                                    if (reader.Read())
                                    {
                                        stockId = reader["ID"].ToString();
                                    }
                                }
                            }
                            if (string.IsNullOrEmpty(stockId))
                                throw new Exception($"Stock insuffisant pour l'article {ligne.articleId}.");

                            // Mettre à jour le stock
                            string updateStock = "UPDATE SSTOCK SET QUANTITE = QUANTITE - @qte, UPDATED_AT = GETDATE(), UPDATED_BY = @userId WHERE ID = @stockId";
                            using (var cmd = new SqlCommand(updateStock, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@qte", ligne.qteR);
                                cmd.Parameters.AddWithValue("@userId", userId);
                                cmd.Parameters.AddWithValue("@stockId", stockId);
                                cmd.ExecuteNonQuery();
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

    public bool IsReusable { get { return false; } }
}
