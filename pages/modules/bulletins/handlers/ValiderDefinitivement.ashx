<%@ WebHandler Language="C#" Class="ValiderDefinitivement" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ValiderDefinitivement : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            // Lire le corps
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            if (string.IsNullOrWhiteSpace(body))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Corps de requête vide\"}");
                return;
            }

            var ser = new JavaScriptSerializer();
            var data = ser.Deserialize<Dictionary<string, object>>(body);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"JSON invalide\"}");
                return;
            }

            // Récupérer les paramètres
            int classeId = GetInt(data, "classeId");
            string matiereId = GetString(data, "matiereId");
            string periode = GetString(data, "periodeId");

            if (classeId <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Identifiant de classe invalide\"}");
                return;
            }
            if (string.IsNullOrEmpty(matiereId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Identifiant de matière invalide\"}");
                return;
            }

            // Validation de la période
            var periodesValides = new[] { "T1", "T2", "T3", "Sem1", "Sem2" };
            if (!Array.Exists(periodesValides, p => p == periode))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Période invalide\"}");
                return;
            }

            Guid matiereGuid;
            if (!Guid.TryParse(matiereId, out matiereGuid))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Identifiant de matière invalide\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            int updatedCount;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string sql = @"
                    UPDATE BULLETINS
                    SET    STATUT     = 'Validé',
                           UPDATED_AT = GETDATE()
                    WHERE  ELEVE_MATRICULE IN (
                               SELECT MATRICULE FROM ELEVES WHERE CLASSE = @classeId
                           )
                      AND  MATIERE_ID = @matiereId
                      AND  PERIODE    = @periode
                      AND  STATUT     = 'Enregistré'";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@classeId", classeId);
                    cmd.Parameters.AddWithValue("@matiereId", matiereGuid);
                    cmd.Parameters.AddWithValue("@periode", periode);
                    updatedCount = cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write("{\"success\":true,\"updated\":" + updatedCount + "}");
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

    private int GetInt(Dictionary<string, object> dict, string key)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
        {
            int val;
            if (int.TryParse(dict[key].ToString(), out val))
                return val;
        }
        return 0;
    }

    public bool IsReusable { get { return false; } }
}