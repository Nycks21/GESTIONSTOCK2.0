<%@ WebHandler Language="C#" Class="ArticlesDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ArticlesDelete : IHttpHandler, IRequiresSessionState
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
            var serializer = new JavaScriptSerializer(); // ← instance créée
            var data = serializer.Deserialize<Dictionary<string, object>>(json);
            string id = data.ContainsKey("id") && data["id"] != null ? data["id"].ToString() : null;
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérifier si l'article est utilisé dans des lignes d'entrée ou de sortie
                string referenceSql = @"
                    SELECT
                        (SELECT COUNT(*) FROM MLENTREE WHERE ARTICLE_ID = @id AND DELETION_AT IS NULL) +
                        (SELECT COUNT(*) FROM MLSORTIE WHERE ARTICLE_ID = @id AND DELETION_AT IS NULL)
                    AS TotalReferences";
                using (SqlCommand referenceCmd = new SqlCommand(referenceSql, conn))
                {
                    referenceCmd.Parameters.AddWithValue("@id", id);
                    int totalReferences = Convert.ToInt32(referenceCmd.ExecuteScalar());
                    if (totalReferences > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer, l'article est utilisé dans des bons d'entrée ou de sortie."
                        }));
                        return;
                    }
                }

                // Suppression logique de l'article
                string sql = "UPDATE MARTICLE SET DELETION_AT = GETDATE(), DELETION_BY = @userId WHERE ID = @id AND DELETION_AT IS NULL";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new { success = false, message = "Article introuvable ou déjà supprimé." }));
                        return;
                    }
                }

                // Suppression logique des lignes de stock associées
                string stockSql = "UPDATE SSTOCK SET DELETION_AT = GETDATE(), DELETION_BY = @userId WHERE ARTICLE_ID = @id AND DELETION_AT IS NULL";
                using (SqlCommand cmd = new SqlCommand(stockSql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.ExecuteNonQuery();
                }

                // Optionnel : supprimer logiquement les mouvements dans MSTOCK (pas obligatoire, mais cohérent)
                string mvtSql = "UPDATE MSTOCK SET DELETION_AT = GETDATE(), DELETION_BY = @userId WHERE ARTICLE_ID = @id AND DELETION_AT IS NULL";
                using (SqlCommand cmd = new SqlCommand(mvtSql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.ExecuteNonQuery();
                }

                ctx.Response.Write(serializer.Serialize(new { success = true, message = "Article supprimé." }));
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
