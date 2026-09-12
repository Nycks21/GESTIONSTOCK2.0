<%@ WebHandler Language="C#" Class="FournisseurEdit" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class FournisseurEdit : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
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
                throw new Exception("ID manquant");

            string nom = GetString(data, "nom");
            string adresse = GetString(data, "adresse");
            string telephone = GetString(data, "telephone");
            string email = GetString(data, "email");
            string contactNom = GetString(data, "contactNom");
            string contactTelephone = GetString(data, "contactTelephone");
            string siret = GetString(data, "siret");
            bool actif = GetBool(data, "actif", true);

            if (string.IsNullOrEmpty(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le nom sont obligatoires.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    UPDATE SFOURNISSEUR
                    SET NOM = @nom, ADRESSE = @adresse, TELEPHONE = @telephone,
                        EMAIL = @email, CONTACT_NOM = @contactNom, CONTACT_TELEPHONE = @contactTelephone,
                        SIRET = @siret, ACTIVE = @actif, UPDATED_BY = @userId, UPDATED_AT = GETDATE()
                    WHERE ID = @id AND DELETION_AT IS NULL";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@adresse", (object)adresse ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@telephone", (object)telephone ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@email", (object)email ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@contactNom", (object)contactNom ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@contactTelephone", (object)contactTelephone ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@siret", (object)siret ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@actif", actif ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                        throw new Exception("Fournisseur introuvable ou déjà supprimé.");
                }

                ctx.Response.Write(serializer.Serialize(new { success = true, message = "Fournisseur modifié avec succès." }));
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
