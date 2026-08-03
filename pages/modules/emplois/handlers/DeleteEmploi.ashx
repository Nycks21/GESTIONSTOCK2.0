<%@ WebHandler Language="C#" Class="DeleteEmploi" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;
using System.IO;

public class DeleteEmploi : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        // ✅ Seuls les rôles 0, 1 et 4 peuvent supprimer un créneau
        if (!AuthHelper.RequireApiAuth(ctx, 0) || !AuthHelper.CanManageEmploi(ctx))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        string json = new StreamReader(ctx.Request.InputStream).ReadToEnd();
        if (string.IsNullOrEmpty(json))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Données JSON manquantes\"}");
            return;
        }

        try
        {
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données JSON invalides\"}");
                return;
            }

            string classe = GetString(data, "classe");
            string jour = GetString(data, "jour");
            string heureDebut = GetString(data, "heureDebut");

            if (string.IsNullOrEmpty(classe) || string.IsNullOrEmpty(jour) || string.IsNullOrEmpty(heureDebut))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Paramètres manquants\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = "DELETE FROM EMPLOI_TEMPS WHERE CLASSE_ID = @classe AND JOUR = @jour AND HEURE_DEBUT = @heureDebut";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@classe", classe);
                    cmd.Parameters.AddWithValue("@jour", jour);
                    cmd.Parameters.AddWithValue("@heureDebut", heureDebut);
                    cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Emploi supprimé avec succès\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    private string GetString(Dictionary<string, object> dict, string key)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
            return dict[key].ToString();
        return "";
    }

    public bool IsReusable { get { return false; } }
}