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

            string id = GetString(data, "id");
            string code = GetString(data, "code");
            string nom = GetString(data, "nom");
            string description = GetString(data, "description") ?? "";
            string categorieId = GetString(data, "categorieId");
            string fournisseurId = GetString(data, "fournisseurId");
            string uniteId = GetString(data, "uniteId");
            decimal seuilAlerte = GetDecimal(data, "seuilAlerte");
            decimal seuilMin = GetDecimal(data, "seuilMin");
            bool active = GetBool(data, "actif", true);
            bool estService = GetBool(data, "estService", false);

            if (string.IsNullOrEmpty(id) || string.IsNullOrEmpty(code) || string.IsNullOrEmpty(nom) || string.IsNullOrEmpty(uniteId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID, code, nom et unité sont obligatoires.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    UPDATE MARTICLE
                    SET CODE = @code,
                        NOM = @nom,
                        DESCRIPTION = @desc,
                        CATEGORIE_ID = @cat,
                        FOURNISSEUR_PREFERE_ID = @four,
                        UNITE_MESURE_ID = @unite,
                        SEUIL_ALERTE = @seuil,
                        SEUIL_MIN = @seuilMin,
                        ACTIVE = @active,
                        EST_SERVICE = @service,
                        UPDATED_AT = GETDATE(),
                        UPDATED_BY = @userId
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@code", code);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@desc", description);
                    cmd.Parameters.AddWithValue("@cat", string.IsNullOrEmpty(categorieId) ? (object)DBNull.Value : categorieId);
                    cmd.Parameters.AddWithValue("@four", string.IsNullOrEmpty(fournisseurId) ? (object)DBNull.Value : fournisseurId);
                    cmd.Parameters.AddWithValue("@unite", uniteId);
                    cmd.Parameters.AddWithValue("@seuil", seuilAlerte);
                    cmd.Parameters.AddWithValue("@seuilMin", seuilMin);
                    cmd.Parameters.AddWithValue("@active", active);
                    cmd.Parameters.AddWithValue("@service", estService);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows > 0)
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, message = "Article modifié." }));
                    else
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = "Article non trouvé ou déjà supprimé." }));
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

    private decimal GetDecimal(Dictionary<string, object> data, string key)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            decimal val;
            if (decimal.TryParse(data[key].ToString(), out val))
                return val;
        }
        return 0;
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
