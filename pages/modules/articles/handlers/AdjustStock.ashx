<%@ WebHandler Language="C#" Class="AdjustStock" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AdjustStock : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
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
            string articleId = data.ContainsKey("articleId") && data["articleId"] != null ? data["articleId"].ToString() : null;
            string emplacementId = data.ContainsKey("emplacementId") && data["emplacementId"] != null ? data["emplacementId"].ToString() : null;
            string type = data.ContainsKey("type") && data["type"] != null ? data["type"].ToString() : "ENTREE";
            decimal quantite = 0;
            if (data.ContainsKey("quantite") && data["quantite"] != null)
                decimal.TryParse(data["quantite"].ToString(), out quantite);
            string motif = data.ContainsKey("motif") && data["motif"] != null ? data["motif"].ToString() : "";

            if (string.IsNullOrEmpty(articleId) || string.IsNullOrEmpty(emplacementId) || quantite <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données invalides\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (SqlTransaction trans = conn.BeginTransaction())
                {
                    try
                    {
                        string getStockSql = @"
                            SELECT ID, QUANTITE_ACTUELLE FROM SSTOCK
                            WHERE ARTICLE_ID = @articleId AND EMPLACEMENT_ID = @empl AND DELETION_AT IS NULL";
                        int stockId = 0;
                        decimal quantiteActuelle = 0;
                        using (SqlCommand cmd = new SqlCommand(getStockSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@articleId", articleId);
                            cmd.Parameters.AddWithValue("@empl", emplacementId);
                            using (SqlDataReader rdr = cmd.ExecuteReader())
                            {
                                if (rdr.Read())
                                {
                                    stockId = Convert.ToInt32(rdr["ID"]);
                                    quantiteActuelle = Convert.ToDecimal(rdr["QUANTITE_ACTUELLE"]);
                                }
                                rdr.Close();
                            }
                        }

                        decimal nouvelleQuantite = quantiteActuelle;
                        if (type == "ENTREE")
                            nouvelleQuantite += quantite;
                        else if (type == "SORTIE")
                            nouvelleQuantite -= quantite;
                        else
                            throw new Exception("Type de mouvement invalide");

                        if (nouvelleQuantite < 0)
                            throw new Exception("Stock négatif non autorisé");

                        string updateStock = @"
                            UPDATE SSTOCK SET
                                QUANTITE_ACTUELLE = @newQte,
                                QUANTITE_MVT = QUANTITE_MVT + @mvt,
                                UPDATED_AT = GETDATE(),
                                UPDATED_BY = @userId
                            WHERE ID = @stockId";
                        using (SqlCommand cmd = new SqlCommand(updateStock, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@newQte", nouvelleQuantite);
                            cmd.Parameters.AddWithValue("@mvt", type == "ENTREE" ? quantite : -quantite);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.Parameters.AddWithValue("@stockId", stockId);
                            cmd.ExecuteNonQuery();
                        }

                        string insertMvt = @"
                            INSERT INTO MSTOCK (ID, ARTICLE_ID, EMPLACEMENT_ID, TYPE, QUANTITE, QUANTITE_AVANT, QUANTITE_APRES, MOTIF, CREATED_BY, CREATED_AT)
                            VALUES (@id, @articleId, @empl, @type, @qte, @avant, @apres, @motif, @userId, GETDATE())";
                        using (SqlCommand cmd = new SqlCommand(insertMvt, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", Guid.NewGuid().ToString());
                            cmd.Parameters.AddWithValue("@articleId", articleId);
                            cmd.Parameters.AddWithValue("@empl", emplacementId);
                            cmd.Parameters.AddWithValue("@type", type);
                            cmd.Parameters.AddWithValue("@qte", quantite);
                            cmd.Parameters.AddWithValue("@avant", quantiteActuelle);
                            cmd.Parameters.AddWithValue("@apres", nouvelleQuantite);
                            cmd.Parameters.AddWithValue("@motif", string.IsNullOrEmpty(motif) ? (object)DBNull.Value : motif);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        trans.Commit();
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, message = "Ajustement effectué" }));
                    }
                    catch (Exception)
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
