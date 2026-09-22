﻿<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Configuration" %>

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

    string id = Request.Form["id"];
    if (string.IsNullOrEmpty(id))
    {
        Response.StatusCode = 400;
        WriteResponse("error", "ID manquant");
        return;
    }

    int userId;
    if (!int.TryParse(id, out userId))
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

            // ============================================================
            // 1. Vérifier existence + statut + rôle
            // ============================================================
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

            // ============================================================
            // 2. Protéger les SuperAdmin
            // ============================================================
            int callerRole = AuthHelper.GetUserRole(Context);
            if (targetRole == 0 && callerRole != 0)
            {
                WriteResponse("error", "Seul un SuperAdmin peut supprimer un SuperAdmin");
                return;
            }

            // ============================================================
            // 3. SOFT DELETE STRICT
            //    - DELETION_AT : horodatage de la suppression
            //    - DELETION_BY : ID de l'admin qui supprime
            //    - ACTIVE = 0  : compte désactivé
            //    - SESSION_TOKEN = NULL : session invalidée immédiatement
            //    - LAST_PC = NULL : trace de connexion effacée
            //
            //    ⚠️ USERNAME et EMAIL NE SONT PAS modifiés :
            //       → ils restent réservés à vie (contrainte UNIQUE globale)
            //       → l'historique complet est conservé
            //       → impossible de recréer un compte avec ces identifiants
            // ============================================================
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
                    // Log de sécurité (ne casse pas la suppression si échec)
                    try
                    {
                        using (SqlCommand logCmd = new SqlCommand(
                            @"INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                              VALUES (@UserId, 'USER_DELETE', @Details, @IP, GETDATE())", conn))
                        {
                            logCmd.Parameters.AddWithValue("@UserId", currentUserId);
                            logCmd.Parameters.AddWithValue("@Details", "Suppression logique de l'utilisateur IDUSER=" + userId);
                            logCmd.Parameters.AddWithValue("@IP", Request.UserHostAddress);
                            logCmd.ExecuteNonQuery();
                        }
                    }
                    catch { /* ignore */ }

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
</script>
