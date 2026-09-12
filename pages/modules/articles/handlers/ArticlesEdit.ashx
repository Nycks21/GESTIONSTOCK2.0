<%@ WebHandler Language="C#" Class="ArticlesEdit" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ArticlesEdit : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
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

            string id = GetString(data, "id");
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant\"}");
                return;
            }

            string nom = GetString(data, "nom");
            string description = GetString(data, "description") ?? "";
            string categorieId = GetString(data, "categorieId");
            string fournisseurId = GetString(data, "fournisseurId");
            string uniteId = GetString(data, "uniteId");
            string emplacementId = GetString(data, "emplacementId");
            decimal seuilAlerte = GetDecimal(data, "seuilAlerte", 0);
            decimal seuilMin = GetDecimal(data, "seuilMin", 0);
            bool actif = GetBool(data, "actif", true);
            bool estService = GetBool(data, "estService", false);

            if (string.IsNullOrEmpty(nom) || string.IsNullOrEmpty(uniteId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Nom et unité sont obligatoires.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    UPDATE MARTICLE SET
                        NOM = @nom,
                        DESCRIPTION = @desc,
                        CATEGORIE_ID = @cat,
                        FOURNISSEUR_PREFERE_ID = @four,
                        UNITE_MESURE_ID = @unite,
                        EMPLACEMENT_ID = @empl,
                        SEUIL_ALERTE = @seuilAlerte,
                        SEUIL_MIN = @seuilMin,
                        ACTIVE = @active,
                        EST_SERVICE = @service,
                        UPDATED_BY = @userId,
                        UPDATED_AT = GETDATE()
                    WHERE ID = @id AND DELETION_AT IS NULL";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@desc", description ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@cat", string.IsNullOrEmpty(categorieId) ? (object)DBNull.Value : categorieId);
                    cmd.Parameters.AddWithValue("@four", string.IsNullOrEmpty(fournisseurId) ? (object)DBNull.Value : fournisseurId);
                    cmd.Parameters.AddWithValue("@unite", uniteId);
                    cmd.Parameters.AddWithValue("@empl", string.IsNullOrEmpty(emplacementId) ? (object)DBNull.Value : emplacementId);
                    cmd.Parameters.AddWithValue("@seuilAlerte", seuilAlerte);
                    cmd.Parameters.AddWithValue("@seuilMin", seuilMin);
                    cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                    cmd.Parameters.AddWithValue("@service", estService ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Article introuvable ou déjà supprimé.\"}");
                        return;
                    }
                }

                ctx.Response.Write(serializer.Serialize(new { success = true, message = "Article modifié avec succès." }));
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

    public bool IsReusable { get { return false; } }
}
