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
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Dictionary<string, object> data = serializer.Deserialize<Dictionary<string, object>>(json);

            string code = GetString(data, "code");
            string nom = GetString(data, "nom");
            string description = GetString(data, "description") ?? "";
            string categorieId = GetString(data, "categorieId");
            string fournisseurId = GetString(data, "fournisseurId");
            string uniteId = GetString(data, "uniteId");
            decimal stock = GetDecimal(data, "stock", 0);
            decimal seuilAlerte = GetDecimal(data, "seuilAlerte", 0);
            decimal seuilMin = GetDecimal(data, "seuilMin", 0);
            bool active = GetBool(data, "actif", true);
            bool estService = GetBool(data, "estService", false);

            if (string.IsNullOrEmpty(code) || string.IsNullOrEmpty(nom) || string.IsNullOrEmpty(uniteId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Code, nom et unité sont obligatoires.\"}");
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
                        // Générer un nouveau GUID pour l'ID
                        string newId = Guid.NewGuid().ToString();

                        string articleSql = @"
                            INSERT INTO MARTICLE (ID, CODE, NOM, DESCRIPTION, CATEGORIE_ID, FOURNISSEUR_PREFERE_ID, UNITE_MESURE_ID, SEUIL_ALERTE, SEUIL_MIN, ACTIVE, EST_SERVICE, CREATED_BY, CREATED_AT)
                            VALUES (@id, @code, @nom, @desc, @cat, @four, @unite, @seuil, @seuilMin, @active, @service, @userId, GETDATE())";
                        using (var cmd = new SqlCommand(articleSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", newId);
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@desc", description);
                            cmd.Parameters.AddWithValue("@cat", string.IsNullOrEmpty(categorieId) ? (object)DBNull.Value : categorieId);
                            cmd.Parameters.AddWithValue("@four", string.IsNullOrEmpty(fournisseurId) ? (object)DBNull.Value : fournisseurId);
                            cmd.Parameters.AddWithValue("@unite", uniteId);
                            cmd.Parameters.AddWithValue("@seuil", seuilAlerte);
                            cmd.Parameters.AddWithValue("@seuilMin", seuilMin);
                            cmd.Parameters.AddWithValue("@active", active ? 1 : 0);
                            cmd.Parameters.AddWithValue("@service", estService ? 1 : 0);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        // Ajouter le stock initial si > 0
                        if (stock > 0)
                        {
                            string getEmpl = "SELECT TOP 1 ID FROM SEMPLACEMENT WHERE ACTIVE = 1 AND DELETION_AT IS NULL";
                            string emplacementId;
                            using (var cmd = new SqlCommand(getEmpl, conn, trans))
                            {
                                var obj = cmd.ExecuteScalar();
                                if (obj == null)
                                    throw new Exception("Aucun emplacement actif trouvé pour le stock.");
                                emplacementId = obj.ToString();
                            }

                            string stockSql = @"
                                INSERT INTO SSTOCK (ARTICLE_ID, EMPLACEMENT_ID, QUANTITE, CREATED_BY, CREATED_AT)
                                VALUES (@articleId, @empl, @stock, @userId, GETDATE())";
                            using (var cmd = new SqlCommand(stockSql, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@articleId", newId);
                                cmd.Parameters.AddWithValue("@empl", emplacementId);
                                cmd.Parameters.AddWithValue("@stock", stock);
                                cmd.Parameters.AddWithValue("@userId", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        trans.Commit();
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, id = newId, message = "Article ajouté avec succès." }));
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

    private bool GetBool(Dictionary<string, object> data, string key, bool defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool val;
            if (bool.TryParse(data[key].ToString(), out val))
                return val;
        }
        return defaultValue;
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
