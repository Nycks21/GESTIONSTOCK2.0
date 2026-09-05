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

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (SqlTransaction trans = conn.BeginTransaction())
                {
                    try
                    {
                        // 1. Suppression logique des lignes de stock associées (UPDATE au lieu de DELETE)
                        string sqlStock = @"
                            UPDATE SSTOCK
                            SET DELETION_AT = GETDATE(),
                                DELETION_BY = @userId
                            WHERE ARTICLE_ID = @id
                              AND DELETION_AT IS NULL";
                        using (SqlCommand cmd = new SqlCommand(sqlStock, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        // 2. Suppression logique de l'article
                        string sqlArticle = @"
                            UPDATE MARTICLE
                            SET DELETION_AT = GETDATE(),
                                DELETION_BY = @userId
                            WHERE ID = @id
                              AND DELETION_AT IS NULL";
                        using (SqlCommand cmd = new SqlCommand(sqlArticle, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            int rows = cmd.ExecuteNonQuery();
                            if (rows == 0)
                            {
                                ctx.Response.Write(serializer.Serialize(new { success = false, message = "Article non trouvé ou déjà supprimé." }));
                                return;
                            }
                        }

                        trans.Commit();
                        ctx.Response.Write(serializer.Serialize(new { success = true, message = "Article et ses lignes de stock supprimés logiquement." }));
                    }
                    catch (SqlException ex)
                    {
                        trans.Rollback();
                        // Gestion des erreurs de contrainte éventuelles
                        ctx.Response.StatusCode = 500;
                        ctx.Response.Write(serializer.Serialize(new { success = false, message = "Impossible de supprimer : cet article est référencé dans d'autres tables (mouvements, entrées, sorties)." }));
                    }
                    catch (Exception ex)
                    {
                        trans.Rollback();
                        throw;
                    }
                }
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
