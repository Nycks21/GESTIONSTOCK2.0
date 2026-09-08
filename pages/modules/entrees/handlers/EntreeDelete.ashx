<%@ WebHandler Language="C#" Class="EntreeDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class EntreeDelete : IHttpHandler, IRequiresSessionState
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

            string id = null;
            if (data.ContainsKey("id") && data["id"] != null)
            {
                id = data["id"].ToString();
            }
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            // Soft delete : mettre DELETION_AT
            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string referenceSql = @"
                    SELECT COUNT(*)
                    FROM SENTREE
                    WHERE STATUT = 'VALIDÉ' AND VALIDE_BY IS NOT NULL AND VALIDE_AT IS NOT NULL AND ID = @id";
                using (SqlCommand referenceCmd = new SqlCommand(referenceSql, conn))
                {
                    referenceCmd.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(referenceCmd.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer, le bon est déjà validé."
                        }));
                        return;
                    }
                }
                string sql = "UPDATE SENTREE SET DELETION_AT = GETDATE(), DELETION_BY = @userId WHERE ID = @id AND STATUT = 'BROUILLON'";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                        throw new Exception("Impossible de supprimer : bon non trouvé ou déjà validé/annulé.");
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, message = "Bon supprimé." }));
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
