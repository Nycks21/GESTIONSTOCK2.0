<%@ WebHandler Language="C#" Class="SortieDelete" %>
using System;
using System.Collections.Generic;
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

            string id = null;
            if (data.ContainsKey("id") && data["id"] != null)
                id = data["id"].ToString();
            if (string.IsNullOrEmpty(id))
                throw new Exception("ID manquant");

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
                string sql = "UPDATE SSORTIE SET DELETION_AT = GETDATE(), DELETION_BY = @userId WHERE ID = @id AND STATUT = 'BROUILLON'";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                        throw new Exception("Impossible de supprimer : le bon est déjà validé.");
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, message = "Bon de sortie supprimé." }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}
