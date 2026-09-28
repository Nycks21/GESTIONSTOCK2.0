<%@ Page Language="C#" ResponseEncoding="utf-8" EnableSessionState="True" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Linq" %>

<script runat="server">
private string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);
    Response.Clear();
    Response.Cache.SetNoStore();

    try
    {
        if (Request.HttpMethod == "OPTIONS")
        {
            Response.StatusCode = 200;
            Response.End();
            return;
        }

        if (Request.HttpMethod != "POST")
        {
            Response.StatusCode = 405;
            WriteResponse(false, "Méthode non autorisée");
            return;
        }

        // ✅ AUTH + CSRF + rôle Admin minimum (1)
        if (!AuthHelper.RequireCsrfSafePost(Context, 1))
        {
            Response.StatusCode = 403;
            WriteResponse(false, "Accès non autorisé");
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // LECTURE MULTI-SOURCE avec traçage serveur
        // ═══════════════════════════════════════════════════════════
        var data = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        string source = "unknown";

        // 1) Request.Form (x-www-form-urlencoded, multipart)
        try
        {
            if (Request.Form != null && Request.Form.Count > 0)
            {
                foreach (string k in Request.Form.Keys)
                    data[k] = Request.Form[k];
                if (data.Count > 0) source = "Form";
            }
        }
        catch (Exception ex) { LogDebug("Form read error: " + ex.Message); }

        // 2) JSON body (si Form vide)
        if (data.Count == 0)
        {
            try
            {
                if (Request.InputStream != null && Request.InputStream.CanRead)
                {
                    Request.InputStream.Position = 0;
                    using (var r = new System.IO.StreamReader(Request.InputStream, System.Text.Encoding.UTF8, true, 1024, true))
                    {
                        string raw = r.ReadToEnd();
                        if (!string.IsNullOrEmpty(raw) && raw.Length > 0 && raw[0] == '\uFEFF')
                            raw = raw.Substring(1);
                        raw = raw.Trim();

                        if (raw.StartsWith("{"))
                        {
                            var ser = new JavaScriptSerializer();
                            var dict = ser.Deserialize<Dictionary<string, object>>(raw);
                            if (dict != null)
                            {
                                foreach (var kv in dict) data[kv.Key] = kv.Value;
                                if (data.Count > 0) source = "JsonBody";
                            }
                        }
                    }
                }
            }
            catch (Exception ex) { LogDebug("JsonBody read error: " + ex.Message); }
        }

        // 3) QueryString (fallback diagnostic uniquement)
        if (data.Count == 0)
        {
            try
            {
                if (Request.QueryString != null && Request.QueryString.Count > 0)
                {
                    foreach (string k in Request.QueryString.Keys)
                        data[k] = Request.QueryString[k];
                    if (data.Count > 0) source = "QueryString";
                }
            }
            catch (Exception ex) { LogDebug("QueryString read error: " + ex.Message); }
        }

        // ─── Log systématique de ce qui a été reçu ───
        LogDebug(string.Format(
            "source={0} count={1} keys=[{2}] ct={3} cl={4}",
            source,
            data.Count,
            string.Join(", ", new List<string>(data.Keys).ToArray()),
            Request.ContentType ?? "(vide)",
            Request.ContentLength.ToString()
        ));

        // ─── Si aucune source n'a donné de données : diagnostic ───
        if (data.Count == 0)
        {
            var diag = new Dictionary<string, object>
            {
                { "success", false },
                { "message", "Aucune donnée reçue. Vérifiez le format d'envoi du client." },
                { "debug_contentType", Request.ContentType ?? "(vide)" },
                { "debug_contentLength", Request.ContentLength },
                { "debug_httpMethod", Request.HttpMethod },
                { "debug_formCount", SafeCount(() => Request.Form.Count) },
                { "debug_queryCount", SafeCount(() => Request.QueryString.Count) }
            };
            Response.Write(new JavaScriptSerializer().Serialize(diag));
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // EXTRACTION DES CHAMPS
        // ═══════════════════════════════════════════════════════════
        int userId             = GetIntValue(data, "id", 0);
        string nom             = GetStringValue(data, "nom");
        string email           = GetStringValue(data, "email");
        string telephone       = GetStringValue(data, "telephone");
        int roleId             = GetIntValue(data, "roleId", 1);
        int active             = GetIntValue(data, "active", 1);
        string password        = GetStringValue(data, "password");
        string permissionsJson = GetStringValue(data, "permissions");

        // ─── Validation ───
        if (userId <= 0) { WriteResponse(false, "ID utilisateur invalide (reçu : " + userId + ")"); return; }
        if (string.IsNullOrEmpty(nom)) { WriteResponse(false, "Le nom complet est requis"); return; }
        if (nom.Length > 100) { WriteResponse(false, "Le nom complet est trop long"); return; }
        if (string.IsNullOrEmpty(email)) { WriteResponse(false, "L'email est requis"); return; }
        if (!IsValidEmail(email)) { WriteResponse(false, "Format d'email invalide"); return; }

        int[] allowedRoles = { 0, 1, 2, 3, 4 };
        if (!Array.Exists(allowedRoles, r => r == roleId))
        { WriteResponse(false, "Rôle invalide (reçu : " + roleId + ")"); return; }

        if (!string.IsNullOrEmpty(password) && password.Length < 8)
        { WriteResponse(false, "Le mot de passe doit contenir au moins 8 caractères"); return; }

        List<string> validatedPermissions = new List<string>();
        if (!string.IsNullOrEmpty(permissionsJson))
        {
            try
            {
                var permsList = new JavaScriptSerializer().Deserialize<List<string>>(permissionsJson);
                if (permsList != null)
                {
                    foreach (string p in permsList)
                        if (AuthHelper.AllMenus.Any(m => m.Code == p))
                            validatedPermissions.Add(p);
                }
            }
            catch
            {
                WriteResponse(false, "Format de permissions invalide");
                return;
            }
        }

        int currentUserId = AuthHelper.GetUserId(Context);
        int callerRole = AuthHelper.GetUserRole(Context);

        // ═══════════════════════════════════════════════════════════
        // MISE À JOUR
        // ═══════════════════════════════════════════════════════════
        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            int targetCurrentRole = -1;
            using (SqlCommand getRoleCmd = new SqlCommand(
                "SELECT ROLEID FROM USERS WHERE IDUSER = @ID AND DELETION_AT IS NULL", conn))
            {
                getRoleCmd.Parameters.AddWithValue("@ID", userId);
                object result = getRoleCmd.ExecuteScalar();
                if (result == null || result == DBNull.Value)
                { WriteResponse(false, "Utilisateur non trouvé (id=" + userId + ")"); return; }
                targetCurrentRole = Convert.ToInt32(result);
            }

            if (targetCurrentRole == 0 && callerRole != 0)
            {
                LogSecurityAction(conn, currentUserId, "USER_UPDATE_DENIED",
                    "Tentative de modification d'un SuperAdmin (ID " + userId + ") par un rôle " + callerRole);
                WriteResponse(false, "Seul un SuperAdmin peut modifier un SuperAdmin");
                return;
            }
            if (roleId == 0 && callerRole != 0)
            {
                LogSecurityAction(conn, currentUserId, "USER_UPDATE_DENIED",
                    "Tentative d'attribution du rôle SuperAdmin à ID " + userId + " par un rôle " + callerRole);
                WriteResponse(false, "Seul un SuperAdmin peut attribuer le rôle SuperAdmin");
                return;
            }
            if (userId == currentUserId && callerRole != 0 && roleId == 0)
            {
                LogSecurityAction(conn, currentUserId, "USER_UPDATE_DENIED", "Tentative d'auto-promotion SuperAdmin");
                WriteResponse(false, "Auto-promotion interdite");
                return;
            }

            string query = @"
                UPDATE USERS SET
                    NOM = @NOM,
                    EMAIL = @EMAIL,
                    ROLEID = @ROLEID,
                    TELEPHONE = @TELEPHONE,
                    ACTIVE = @ACTIVE,
                    UPDATED_AT = GETDATE(),
                    UPDATED_BY = @UPDATED_BY";

            if (!string.IsNullOrEmpty(password)) query += ", PWD = @PWD";

            string validatedPermissionsJson = null;
            if (!string.IsNullOrEmpty(permissionsJson))
            {
                validatedPermissionsJson = new JavaScriptSerializer().Serialize(validatedPermissions);
                query += ", MENU_PERMISSIONS = @PERMISSIONS";
            }

            query += " WHERE IDUSER = @ID AND DELETION_AT IS NULL";

            using (SqlCommand cmd = new SqlCommand(query, conn))
            {
                cmd.Parameters.AddWithValue("@NOM", nom);
                cmd.Parameters.AddWithValue("@EMAIL", email);
                cmd.Parameters.AddWithValue("@ROLEID", roleId);
                cmd.Parameters.AddWithValue("@TELEPHONE", string.IsNullOrEmpty(telephone) ? (object)DBNull.Value : telephone);
                cmd.Parameters.AddWithValue("@ACTIVE", active);
                cmd.Parameters.AddWithValue("@UPDATED_BY", currentUserId);
                cmd.Parameters.AddWithValue("@ID", userId);

                if (!string.IsNullOrEmpty(password))
                    cmd.Parameters.AddWithValue("@PWD", PasswordHelper.HashPassword(password));
                if (validatedPermissionsJson != null)
                    cmd.Parameters.AddWithValue("@PERMISSIONS", validatedPermissionsJson);

                int rowsAffected = cmd.ExecuteNonQuery();
                if (rowsAffected == 0) { WriteResponse(false, "Aucune modification effectuée"); return; }
            }

            LogSecurityAction(conn, currentUserId, "USER_UPDATE",
                "Mise à jour de l'utilisateur ID " + userId + " (rôle: " + targetCurrentRole + " -> " + roleId + ")");

            WriteResponse(true, "Utilisateur mis à jour avec succès", userId);
        }
    }
    catch (SqlException ex)
    {
        if (ex.Number == 2627 || ex.Number == 2601) WriteResponse(false, "Conflit d'identifiant (email ou username déjà utilisé)");
        else if (ex.Number == 547) WriteResponse(false, "Violation de contrainte de clé étrangère");
        else { LogDebug("SQL_ERROR: " + ex.Message); WriteResponse(false, "Erreur de base de données : " + ex.Message); }
    }
    catch (Exception ex)
    {
        Response.StatusCode = 500;
        LogDebug("SYSTEM_ERROR: " + ex.Message);
        WriteResponse(false, "Erreur système : " + ex.Message);
    }
}

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════
private int SafeCount(Func<int> counter)
{
    try { return counter(); } catch { return -1; }
}

private string GetStringValue(Dictionary<string, object> data, string key)
{
    if (data == null) return "";
    foreach (var k in data.Keys)
    {
        if (string.Equals(k, key, StringComparison.OrdinalIgnoreCase) && data[k] != null)
            return data[k].ToString().Trim();
    }
    return "";
}

private int GetIntValue(Dictionary<string, object> data, string key, int defaultValue)
{
    if (data == null) return defaultValue;
    foreach (var k in data.Keys)
    {
        if (string.Equals(k, key, StringComparison.OrdinalIgnoreCase) && data[k] != null)
        {
            try { return Convert.ToInt32(data[k]); }
            catch { return defaultValue; }
        }
    }
    return defaultValue;
}

private bool IsValidEmail(string email)
{
    try { var addr = new System.Net.Mail.MailAddress(email); return addr.Address == email; }
    catch { return false; }
}

private void WriteResponse(bool success, string message, int userId = 0)
{
    var response = new Dictionary<string, object>
    {
        { "success", success },
        { "message", message }
    };
    if (userId > 0) response["userId"] = userId;
    Response.Write(new JavaScriptSerializer().Serialize(response));
}

// ═══════════════════════════════════════════════════════════════
// LOGS
// ═══════════════════════════════════════════════════════════════
private void LogDebug(string message)
{
    try
    {
        string logFile = Server.MapPath("~/App_Data/update_user.log");
        string entry = string.Format("[{0}] {1} IP={2}\n",
            DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
            message,
            Request.UserHostAddress);
        System.IO.File.AppendAllText(logFile, entry);
    }
    catch { }
}

private void LogSecurityAction(SqlConnection conn, int userId, string action, string details)
{
    try
    {
        bool closeConn = conn == null;
        if (closeConn) { conn = new SqlConnection(connStr); conn.Open(); }

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

        if (closeConn) conn.Close();
    }
    catch { /* table absente → ignore */ }
}
</script>
