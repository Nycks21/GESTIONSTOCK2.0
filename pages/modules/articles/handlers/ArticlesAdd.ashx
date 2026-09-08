<%@ WebHandler Language="C#" Class="ArticlesAdd" %>
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

            string id = data.ContainsKey("id") && data["id"] != null ? data["id"].ToString() : null;
            string code = GetString(data, "code");
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

            if (string.IsNullOrEmpty(code) || string.IsNullOrEmpty(nom) || string.IsNullOrEmpty(uniteId) || string.IsNullOrEmpty(emplacementId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Code, nom, unité et emplacement sont obligatoires.\"}");
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
                        string newId = Guid.NewGuid().ToString();

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

                        if (stockInitial > 0 && !string.IsNullOrEmpty(emplacementId))
                        {
                            string stockSql = @"
                                INSERT INTO SSTOCK (ARTICLE_ID, EMPLACEMENT_ID, QUANTITE_INITIAL, QUANTITE_MVT, QUANTITE_ACTUELLE, CREATED_BY, CREATED_AT)
                                VALUES (@articleId, @empl, @stock, 0, @stock, @userId, GETDATE())";
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
                        ctx.Response.Write(serializer.Serialize(new { success = true, id = newId, message = "Article ajouté avec succès." }));
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
