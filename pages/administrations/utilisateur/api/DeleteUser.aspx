﻿<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = System.Text.Encoding.UTF8;
    Response.Clear();
    Response.Cache.SetNoStore();

    // Gestion OPTIONS (CORS preflight)
    if (Request.HttpMethod == "OPTIONS")
    {
        Response.StatusCode = 200;
        Response.End();
        return;
    }

    if (Request.HttpMethod != "POST")
    {
        Response.StatusCode = 405;
        WriteResponse("error", "Méthode non autorisée");
        return;
    }

    // ✅ AUTH + CSRF + rôle SuperAdmin
    if (!AuthHelper.RequireCsrfSafePost(Context, 0))
    {
        Response.StatusCode = 403;
        WriteResponse("error", "Accès non autorisé");
        return;
    }

    // ✅ Lecture depuis JSON body (cohérent avec users.aspx / updateUser.aspx)
    string jsonString = "";
    using (var reader = new System.IO.StreamReader(Request.InputStream))
    {
        jsonString = reader.ReadToEnd();
    }
    if (string.IsNullOrEmpty(jsonString))
    {
        Response.StatusCode = 400;
        WriteResponse("error", "Données JSON vides");
        return;
    }

    Dictionary<string, object> data = null;
    try
    {
        var serializer = new JavaScriptSerializer();
        data = serializer.Deserialize<Dictionary<string, object>>(jsonString);
    }
    catch
    {
        Response.StatusCode = 400;
        WriteResponse("error", "Format JSON invalide");
        return;
    }

    if (data == null || !data.ContainsKey("id") || data["id"] == null)
    {
        Response.StatusCode = 400;
        WriteResponse("error", "ID manquant");
        return;
    }

    int userId;
    if (!int.TryParse(data["id"].ToString(), out userId))
    {
        Response.StatusCode = 400;
        WriteResponse("error", "ID utilisateur invalide");
        return;
    }

    int currentUserId = AuthHelper.GetUserId(Context);

    // Sécurité : ne pas se supprimer soi-même
    if (userId == currentUserId)
    {
        WriteResponse("error", "Vous ne pouvez pas supprimer votre propre compte");
        return;
    }

    try
    {
        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            // 1. Vérifier existence + statut + rôle
            int targetRole;
            bool alreadyDeleted;

            using (SqlCommand checkCmd = new SqlCommand(
                "SELECT ROLEID, CASE WHEN DELETION_AT IS NULL THEN 0 ELSE 1 END FROM USERS WHERE IDUSER = @Id", conn))
            {
                checkCmd.Parameters.AddWithValue("@Id", userId);
                using (var reader = checkCmd.ExecuteReader())
                {
                    if (!reader.Read())
                    {
                        WriteResponse("error", "Aucun utilisateur trouvé avec cet ID");
                        return;
                    }
                    targetRole = reader.GetInt32(0);
                    alreadyDeleted = reader.GetInt32(1) == 1;
                }
            }

            if (alreadyDeleted)
            {
                WriteResponse("error", "Cet utilisateur est déjà supprimé");
                return;
            }

            // 2. Protéger les SuperAdmin
            int callerRole = AuthHelper.GetUserRole(Context);
            if (targetRole == 0 && callerRole != 0)
            {
                WriteResponse("error", "Seul un SuperAdmin peut supprimer un SuperAdmin");
                return;
            }

            // 3. SOFT DELETE STRICT
            //    - USERNAME et EMAIL restent intacts (contrainte UNIQUE globale)
            const string sql = @"
                UPDATE USERS
                   SET DELETION_AT    = GETDATE(),
                       DELETION_BY    = @by,
                       ACTIVE         = 0,
                       SESSION_TOKEN  = NULL,
                       LAST_PC        = NULL
                 WHERE IDUSER = @Id
                   AND DELETION_AT IS NULL";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@Id", userId);
                cmd.Parameters.AddWithValue("@by", currentUserId);
                int rows = cmd.ExecuteNonQuery();

                if (rows > 0)
                {
                    LogSecurityAction(conn, currentUserId, "USER_DELETE",
                        "Suppression logique de l'utilisateur IDUSER=" + userId);

                    WriteResponse("success", "Utilisateur supprimé avec succès");
                }
                else
                {
                    WriteResponse("error", "Erreur lors de la suppression");
                }
            }
        }
    }
    catch (Exception ex)
    {
        Response.StatusCode = 500;
        WriteResponse("error", ex.Message.Replace("\"", "'"));
    }
}

private void WriteResponse(string status, string message)
{
    string success = (status == "success") ? "true" : "false";
    string safeMessage = message.Replace("\"", "\\\"").Replace("\r", "").Replace("\n", "");
    string json = "{\"status\":\"" + status + "\",\"success\":" + success + ",\"message\":\"" + safeMessage + "\"}";
    Response.Write(json);
}

private void LogSecurityAction(SqlConnection conn, int userId, string action, string details)
{
    try
    {
        string sql = @"INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                       VALUES (@UserId, @Action, @Details, @IP, GETDATE())";
        using (SqlCommand cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@UserId", userId);
            cmd.Parameters.AddWithValue("@Action", action);
            cmd.Parameters.AddWithValue("@Details", details);
            cmd.Parameters.AddWithValue("@IP", Request.UserHostAddress);
            cmd.ExecuteNonQuery();
        }
    }
    catch { /* table absente → ignore */ }
}
</script>
