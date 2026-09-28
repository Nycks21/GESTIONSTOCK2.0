﻿<%@ WebHandler Language="C#" Class="FournisseurEdit" %>

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

        // ✅ Sécurité renforcée : Session + Token CSRF + Origin/Referer
        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
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

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Corps de requête invalide.\"}");
                return;
            }

            string id = GetString(data, "id");
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant.\"}");
                return;
            }

            string nom = GetString(data, "nom");
            string adresse = GetString(data, "adresse");
            string telephone = GetString(data, "telephone");
            string email = GetString(data, "email");
            string contactNom = GetString(data, "contactNom");
            string contactTelephone = GetString(data, "contactTelephone");
            string siret = GetString(data, "siret");
            bool actif = GetBool(data, "actif", true);

            if (string.IsNullOrWhiteSpace(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le nom est obligatoire.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    UPDATE SFOURNISSEUR
                    SET NOM = @nom,
                        ADRESSE = @adresse,
                        TELEPHONE = @telephone,
                        EMAIL = @email,
                        CONTACT_NOM = @contactNom,
                        CONTACT_TELEPHONE = @contactTelephone,
                        SIRET = @siret,
                        ACTIVE = @actif,
                        UPDATED_BY = @userId,
                        UPDATED_AT = GETDATE()
                    WHERE ID = @id AND DELETION_AT IS NULL";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@adresse", string.IsNullOrEmpty(adresse) ? (object)DBNull.Value : adresse);
                    cmd.Parameters.AddWithValue("@telephone", string.IsNullOrEmpty(telephone) ? (object)DBNull.Value : telephone);
                    cmd.Parameters.AddWithValue("@email", string.IsNullOrEmpty(email) ? (object)DBNull.Value : email);
                    cmd.Parameters.AddWithValue("@contactNom", string.IsNullOrEmpty(contactNom) ? (object)DBNull.Value : contactNom);
                    cmd.Parameters.AddWithValue("@contactTelephone", string.IsNullOrEmpty(contactTelephone) ? (object)DBNull.Value : contactTelephone);
                    cmd.Parameters.AddWithValue("@siret", string.IsNullOrEmpty(siret) ? (object)DBNull.Value : siret);
                    cmd.Parameters.AddWithValue("@actif", actif ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);

                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Fournisseur introuvable ou déjà supprimé.\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new
            {
                success = true,
                message = "Fournisseur modifié avec succès."
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
            }));
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null;
    }

    private bool GetBool(Dictionary<string, object> data, string key, bool defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool val;
            if (bool.TryParse(data[key].ToString(), out val)) return val;
            string s = data[key].ToString().Trim();
            if (s == "1") return true;
            if (s == "0") return false;
        }
        return defaultValue;
    }

    public bool IsReusable { get { return false; } }
}
