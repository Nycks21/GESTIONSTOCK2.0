<%@ Page Language="C#" ResponseEncoding="utf-8" EnableSessionState="True" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
private string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
private const int MIN_PWD_LENGTH = 8;
private const int MAX_PWD_LENGTH = 128;

protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = new UTF8Encoding(false);
    Response.Clear();
    Response.Cache.SetNoStore();

    try
    {
        // ---- 0) PREFLIGHT CORS ----
        if (Request.HttpMethod == "OPTIONS")
        {
            Response.StatusCode = 200;
            Response.End();
            return;
        }

        // ---- 1) MÉTHODE ----
        if (Request.HttpMethod != "POST")
        {
            WriteResponse(false, "Méthode non autorisée");
            return;
        }

        // ---- 2) AUTHENTIFICATION + CSRF ----
        // RequireCsrfSafePost = RequireApiAuth + ValidateCsrfToken + ValidateOrigin
        // Pas de rôle minimum (-1) : tout utilisateur connecté peut changer
        // son propre mot de passe.
        if (!AuthHelper.RequireCsrfSafePost(Context))
        {
            Response.StatusCode = 403;
            WriteResponse(false, "Session expirée ou requête non autorisée. Veuillez vous reconnecter.");
            return;
        }

        // ---- 3) UTILISATEUR CONNECTÉ ----
        int userId = AuthHelper.GetUserId(Context);
        if (userId <= 0)
        {
            WriteResponse(false, "Utilisateur non identifié.");
            return;
        }

        // ---- 4) PARAMÈTRES ----
        string oldPwd     = (Request.Form["oldPwd"]     ?? Request["oldPwd"]     ?? "").Trim();
        string newPwd     = (Request.Form["newPwd"]     ?? Request["newPwd"]     ?? "").Trim();
        string confirmPwd = (Request.Form["confirmPwd"] ?? Request["confirmPwd"] ?? "").Trim();

        // ---- 5) VALIDATIONS ----
        if (string.IsNullOrEmpty(oldPwd) || string.IsNullOrEmpty(newPwd) || string.IsNullOrEmpty(confirmPwd))
        {
            LogSecurityAction(userId, "PWD_CHANGE_FAILED", "Champs manquants");
            WriteResponse(false, "Tous les champs sont obligatoires.");
            return;
        }
        if (newPwd.Length < MIN_PWD_LENGTH)
        {
            LogSecurityAction(userId, "PWD_CHANGE_FAILED", "Nouveau mot de passe trop court");
            WriteResponse(false, "Le nouveau mot de passe doit contenir au moins " + MIN_PWD_LENGTH + " caractères.");
            return;
        }
        if (newPwd.Length > MAX_PWD_LENGTH || oldPwd.Length > MAX_PWD_LENGTH)
        {
            LogSecurityAction(userId, "PWD_CHANGE_FAILED", "Mot de passe trop long");
            WriteResponse(false, "Mot de passe trop long (max " + MAX_PWD_LENGTH + " caractères).");
            return;
        }
        if (!string.Equals(newPwd, confirmPwd, StringComparison.Ordinal))
        {
            LogSecurityAction(userId, "PWD_CHANGE_FAILED", "Confirmation différente");
            WriteResponse(false, "Le nouveau mot de passe et sa confirmation ne correspondent pas.");
            return;
        }
        if (string.Equals(oldPwd, newPwd, StringComparison.Ordinal))
        {
            LogSecurityAction(userId, "PWD_CHANGE_FAILED", "Nouveau mot de passe identique à l'ancien");
            WriteResponse(false, "Le nouveau mot de passe doit être différent de l'ancien.");
            return;
        }

        // ---- 6) TRAITEMENT SQL ----
        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            // 6.1) Récupérer le hash stocké
            string storedPwd;
            using (SqlCommand cmd = new SqlCommand(
                "SELECT PWD FROM USERS WHERE IDUSER = @id AND DELETION_AT IS NULL", conn))
            {
                cmd.Parameters.AddWithValue("@id", userId);
                object o = cmd.ExecuteScalar();
                if (o == null || o == DBNull.Value)
                {
                    LogSecurityAction(userId, "PWD_CHANGE_FAILED", "Utilisateur introuvable");
                    WriteResponse(false, "Utilisateur introuvable.");
                    return;
                }
                storedPwd = o.ToString();
            }

            // 6.2) Vérifier l'ancien mot de passe
            //      ✅ Délégation à PasswordHelper (même logique que Login.aspx)
            bool needsRehash;
            bool pwdOk = PasswordHelper.VerifyPassword(storedPwd, oldPwd, out needsRehash);

            if (!pwdOk)
            {
                // ⚠️ Log critique : échec de vérification = tentative potentiellement malveillante
                LogSecurityAction(userId, "PWD_CHANGE_DENIED", "Ancien mot de passe incorrect");
                WriteResponse(false, "L'ancien mot de passe est incorrect.");
                return;
            }

            // 6.3) Mettre à jour avec un hash neuf (PBKDF2 via PasswordHelper)
            string newHash = PasswordHelper.HashPassword(newPwd);
            using (SqlCommand cmd = new SqlCommand(
                "UPDATE USERS SET PWD = @pwd, UPDATED_AT = GETDATE(), UPDATED_BY = @by WHERE IDUSER = @id AND DELETION_AT IS NULL", conn))
            {
                cmd.Parameters.AddWithValue("@pwd", newHash);
                cmd.Parameters.AddWithValue("@by",  userId);
                cmd.Parameters.AddWithValue("@id",  userId);

                if (cmd.ExecuteNonQuery() <= 0)
                {
                    LogSecurityAction(userId, "PWD_CHANGE_FAILED", "Aucune ligne mise à jour");
                    WriteResponse(false, "Aucune ligne mise à jour.");
                    return;
                }
            }

            // ✅ Log de succès
            LogSecurityAction(userId, "PWD_CHANGE_SUCCESS", "Mot de passe modifié avec succès");
        }

        WriteResponse(true, "Mot de passe mis à jour avec succès.");
    }
    catch (SqlException ex)
    {
        LogError("SQL_ERROR", ex);
        WriteResponse(false, "Erreur base de données. Veuillez réessayer.");
    }
    catch (Exception ex)
    {
        LogError("SYSTEM_ERROR", ex);
        WriteResponse(false, "Une erreur est survenue lors du traitement.");
    }
}

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════
private void WriteResponse(bool success, string message)
{
    var serializer = new JavaScriptSerializer();
    var response = new Dictionary<string, object>();
    response["success"] = success;
    response["message"] = message;
    Response.Write(serializer.Serialize(response));
}

// Audit de sécurité : enregistre les tentatives de changement de mot de passe
private void LogSecurityAction(int userId, string action, string details)
{
    // 1) Log SQL (SECURITY_LOG)
    try
    {
        using (var conn = new SqlConnection(connStr))
        {
            conn.Open();
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
    }
    catch { /* table absente → ignore */ }

    // 2) Log fichier (fallback si la table n'existe pas)
    try
    {
        string logFile = Server.MapPath("~/App_Data/password_changes.log");
        string entry = string.Format(
            "[{0}] userId={1} action={2} details=\"{3}\" IP={4}\n",
            DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
            userId, action, details,
            Request.UserHostAddress);
        System.IO.File.AppendAllText(logFile, entry);
    }
    catch { }
}

// Log d'erreur système/SQL (fichier)
private void LogError(string type, Exception ex)
{
    try
    {
        string logFile = Server.MapPath("~/App_Data/password_changes.log");
        string entry = string.Format(
            "[{0}] {1} msg=\"{2}\" userId={3} IP={4}\n",
            DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
            type,
            (ex != null ? ex.Message : ""),
            AuthHelper.GetUserId(Context),
            Request.UserHostAddress);
        System.IO.File.AppendAllText(logFile, entry);
    }
    catch { }
}
</script>
