﻿<%@ WebHandler Language="C#" Class="CategorieDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class CategorieDelete : IHttpHandler, IRequiresSessionState
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

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérification : catégorie référencée par un article ?
                string referenceSql = @"
                    SELECT COUNT(*)
                    FROM MARTICLE
                    WHERE CATEGORIE_ID = @id AND DELETION_AT IS NULL";
                using (var referenceCmd = new SqlCommand(referenceSql, conn))
                {
                    referenceCmd.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(referenceCmd.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer, codification rattachée"
                        }));
                        return;
                    }
                }

                // Vérification : sous-catégories rattachées ?
                string childrenSql = @"
                    SELECT COUNT(*)
                    FROM SCATEGORIE
                    WHERE PARENT_ID = @id AND DELETION_AT IS NULL";
                using (var childCmd = new SqlCommand(childrenSql, conn))
                {
                    childCmd.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(childCmd.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer, sous-catégories rattachées"
                        }));
                        return;
                    }
                }

                string sql = @"
                    UPDATE SCATEGORIE
                    SET DELETION_AT = GETDATE(),
                        DELETION_BY = @userId
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Catégorie introuvable ou déjà supprimée.\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new { success = true, message = "Catégorie supprimée." }));
        }
        catch (SqlException ex)
        {
            if (ex.Number == 547) // Contrainte FK violée
            {
                ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                {
                    success = false,
                    message = "Impossible de supprimer, codification rattachée"
                }));
                return;
            }
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
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

    public bool IsReusable { get { return false; } }
}
