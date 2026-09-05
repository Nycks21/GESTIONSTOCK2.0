<%@ WebHandler Language="C#" Class="FournisseurAdd" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class FournisseurAdd : IHttpHandler, IRequiresSessionState
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

            string code = GetString(data, "code");
            string nom = GetString(data, "nom");
            string adresse = GetString(data, "adresse");
            string telephone = GetString(data, "telephone");
            string email = GetString(data, "email");
            string contactNom = GetString(data, "contactNom");
            string contactTelephone = GetString(data, "contactTelephone");
            string siret = GetString(data, "siret");
            bool actif = GetBool(data, "actif", true);

            if (string.IsNullOrEmpty(code) || string.IsNullOrEmpty(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le code et le nom sont obligatoires.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string newId = Guid.NewGuid().ToString();
                string sql = @"
                    INSERT INTO SFOURNISSEUR (ID, CODE, NOM, ADRESSE, TELEPHONE, EMAIL, CONTACT_NOM, CONTACT_TELEPHONE, SIRET, ACTIVE, CREATED_BY, CREATED_AT)
                    VALUES (@id, @code, @nom, @adresse, @telephone, @email, @contactNom, @contactTelephone, @siret, @actif, @userId, GETDATE())";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", newId);
                    cmd.Parameters.AddWithValue("@code", code);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@adresse", (object)adresse ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@telephone", (object)telephone ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@email", (object)email ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@contactNom", (object)contactNom ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@contactTelephone", (object)contactTelephone ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@siret", (object)siret ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@actif", actif ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.ExecuteNonQuery();
                }

                ctx.Response.Write(serializer.Serialize(new { success = true, id = newId, message = "Fournisseur ajouté avec succès." }));
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
