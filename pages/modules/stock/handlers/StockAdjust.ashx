<%@ WebHandler Language="C#" Class="StockAdjust" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class StockAdjust : IHttpHandler, IRequiresSessionState
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

            string articleId = GetString(data, "articleId");
            string emplacementId = GetString(data, "emplacementId");
            string type = GetString(data, "type"); // "ENTREE" ou "SORTIE"
            decimal quantite = GetDecimal(data, "quantite", 0);

            string motif = GetString(data, "motif") ?? "";

            if (string.IsNullOrEmpty(articleId) || string.IsNullOrEmpty(emplacementId) || string.IsNullOrEmpty(type) || quantite <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données incomplètes ou invalides.\"}");
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
                        string userName = GetUserName(conn, trans, userId);
                        // Récupérer la quantité actuelle
                        decimal quantiteActuelle = 0;
                        string getQte = "SELECT QUANTITE_ACTUELLE FROM SSTOCK WHERE ARTICLE_ID = @articleId AND EMPLACEMENT_ID = @emplacementId AND DELETION_AT IS NULL";
                        using (var cmd = new SqlCommand(getQte, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@articleId", articleId);
                            cmd.Parameters.AddWithValue("@emplacementId", emplacementId);
                            var obj = cmd.ExecuteScalar();
                            if (obj != null)
                                quantiteActuelle = Convert.ToDecimal(obj);
                        }

                        decimal nouvelleQuantite = quantiteActuelle;
                        if (type == "ENTREE")
                            nouvelleQuantite += quantite;
                        else if (type == "SORTIE")
                        {
                            if (quantite > quantiteActuelle)
                                throw new Exception("Quantité sortante supérieure au stock disponible.");
                            nouvelleQuantite -= quantite;
                        }
                        else
                            throw new Exception("Type de mouvement invalide.");

                        // Mettre à jour ou insérer dans SSTOCK
                        if (quantiteActuelle == 0 && type == "ENTREE")
                        {
                            // Insertion
                            string insertSql = @"
                                INSERT INTO SSTOCK (ARTICLE_ID, EMPLACEMENT_ID, QUANTITE_INITIAL, QUANTITE_MVT, QUANTITE_ACTUELLE, CREATED_BY, CREATED_AT)
                                VALUES (@articleId, @emplacementId, 0, 0, @newQte, @userId, GETDATE())";
                            using (var cmd = new SqlCommand(insertSql, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                cmd.Parameters.AddWithValue("@emplacementId", emplacementId);
                                cmd.Parameters.AddWithValue("@newQte", nouvelleQuantite);
                                cmd.Parameters.AddWithValue("@userId", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }
                        else
                        {
                            // Mise à jour
                            string updateSql = @"
                                UPDATE SSTOCK
                                SET QUANTITE_MVT = QUANTITE_MVT + @mvt,
                                    QUANTITE_ACTUELLE = @newQte,
                                    UPDATED_BY = @userId,
                                    UPDATED_AT = GETDATE()
                                WHERE ARTICLE_ID = @articleId AND EMPLACEMENT_ID = @emplacementId AND DELETION_AT IS NULL";
                            using (var cmd = new SqlCommand(updateSql, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                cmd.Parameters.AddWithValue("@emplacementId", emplacementId);
                                cmd.Parameters.AddWithValue("@mvt", type == "ENTREE" ? quantite : -quantite);
                                cmd.Parameters.AddWithValue("@newQte", nouvelleQuantite);
                                cmd.Parameters.AddWithValue("@userId", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        // Enregistrer le mouvement dans MSTOCK
                        string insertMvt = @"
                            INSERT INTO MSTOCK (ID, ARTICLE_ID, EMPLACEMENT_ID, TYPE, QUANTITE, QUANTITE_AVANT, QUANTITE_APRES, MOTIF, CREATED_BY, CREATED_AT)
                            VALUES (NEWID(), @articleId, @emplacementId, @type, @quantite, @avant, @apres, @motif, @userId, GETDATE())";
                        using (var cmd = new SqlCommand(insertMvt, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@articleId", articleId);
                            cmd.Parameters.AddWithValue("@emplacementId", emplacementId);
                            cmd.Parameters.AddWithValue("@type", type);
                            cmd.Parameters.AddWithValue("@quantite", quantite);
                            cmd.Parameters.AddWithValue("@avant", quantiteActuelle);
                            cmd.Parameters.AddWithValue("@apres", nouvelleQuantite);
                            cmd.Parameters.AddWithValue("@motif", BuildMotif(motif, userName));
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        trans.Commit();
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, message = "Ajustement effectué avec succès." }));
                    }
                    catch (Exception ex)
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

    private string GetString(Dictionary<string, object> data, string key)
    {
        if (data.ContainsKey(key) && data[key] != null)
            return data[key].ToString();
        return null;
    }

    private decimal GetDecimal(Dictionary<string, object> data, string key, decimal defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            decimal val;
            if (decimal.TryParse(data[key].ToString(), out val))
                return val;
        }
        return defaultValue;
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
        motif = (motif ?? "").Trim();
        return (motif.Length > 0 ? motif : "Action") + " par @" + userName;
    }

    public bool IsReusable { get { return false; } }
}
