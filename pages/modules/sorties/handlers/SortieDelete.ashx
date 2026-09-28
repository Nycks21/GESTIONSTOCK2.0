﻿<%@ WebHandler Language="C#" Class="SortieDelete" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SortieDelete : IHttpHandler, IRequiresSessionState
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

            // ─────────────────────────────────────────────────────────
            // ✅ VÉRIFICATION DU MOT DE PASSE DE SUPPRESSION (obligatoire)
            //    Double protection : CSRF (header) + mot de passe serveur.
            //    La comparaison se fait UNIQUEMENT côté serveur.
            // ─────────────────────────────────────────────────────────
            string password = null;
            if (data.ContainsKey("password") && data["password"] != null)
                password = data["password"].ToString();

            string expectedPassword = ConfigurationManager.AppSettings["suppr"];

            if (string.IsNullOrEmpty(expectedPassword))
            {
                ctx.Response.Write(serializer.Serialize(new
                {
                    success = false,
                    message = "Mot de passe de suppression non configuré sur le serveur."
                }));
                return;
            }

            if (string.IsNullOrEmpty(password) || password != expectedPassword)
            {
                ctx.Response.Write(serializer.Serialize(new
                {
                    success = false,
                    passwordError = true,
                    message = "Mot de passe incorrect. Veuillez réessayer."
                }));
                return;
            }

            // ─────────────────────────────────────────────────────────
            // Récupération de l'ID
            // ─────────────────────────────────────────────────────────
            string id = null;
            if (data.ContainsKey("id") && data["id"] != null)
                id = data["id"].ToString();
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string referenceSql = @"
                    SELECT STATUT
                    FROM SSORTIE
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (SqlCommand referenceCmd = new SqlCommand(referenceSql, conn))
                {
                    referenceCmd.Parameters.AddWithValue("@id", id);
                    object statut = referenceCmd.ExecuteScalar();
                    if (statut != null && statut.ToString() == "VALIDE")
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Attention : Impossible de supprimer un bon de sortie validé."
                        }));
                        return;
                    }
                }

                string sql = @"
                    UPDATE SSORTIE
                    SET DELETION_AT = GETDATE(),
                        DELETION_BY = @userId
                    WHERE ID = @id AND STATUT = 'BROUILLON'";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Impossible de supprimer : le bon est déjà validé.\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                message = "Bon de sortie supprimé."
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

    public bool IsReusable { get { return false; } }
}
