﻿<%@ Page Language="C#" ResponseEncoding="utf-8" EnableSessionState="True" %>
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
        // ✅ AUTH + CSRF + rôle Admin minimum (1)
        if (!AuthHelper.RequireCsrfSafePost(Context, 1))
        {
            Response.StatusCode = 403;
            WriteResponse(false, "Accès non autorisé");
            return;
        }

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

        int userId = GetQueryInt("id", 0);
        string nom = GetQueryString("nom");
        string email = GetQueryString("email");
        string telephone = GetQueryString("telephone");
        int roleId = GetQueryInt("roleId", 1);
        int active = GetQueryInt("active", 1);
        string password = GetQueryString("password");
        string permissionsJson = GetQueryString("permissions");

        if (userId <= 0) { WriteResponse(false, "ID utilisateur invalide"); return; }
        if (string.IsNullOrEmpty(nom)) { WriteResponse(false, "Le nom complet est requis"); return; }
        if (nom.Length > 100) { WriteResponse(false, "Le nom complet est trop long"); return; }
        if (string.IsNullOrEmpty(email)) { WriteResponse(false, "L'email est requis"); return; }
        if (!IsValidEmail(email)) { WriteResponse(false, "Format d'email invalide"); return; }

        int[] allowedRoles = { 0, 1, 2, 3, 4 };
        if (!Array.Exists(allowedRoles, r => r == roleId)) { WriteResponse(false, "Rôle invalide"); return; }
        if (!string.IsNullOrEmpty(password) && password.Length < 8) { WriteResponse(false, "Le mot de passe doit contenir au moins 8 caractères"); return; }

        List<string> validatedPermissions = new List<string>();
        if (!string.IsNullOrEmpty(permissionsJson))
        {
            try
            {
                var serializer = new JavaScriptSerializer();
                var permsList = serializer.Deserialize<List<string>>(permissionsJson);
                if (permsList != null)
                {
                    foreach (string p in permsList)
                    {
                        if (AuthHelper.AllMenus.Any(m => m.Code == p))
                            validatedPermissions.Add(p);
                    }
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

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            int targetCurrentRole = -1;
            using (SqlCommand getRoleCmd = new SqlCommand("SELECT ROLEID FROM USERS WHERE IDUSER = @ID", conn))
            {
                getRoleCmd.Parameters.AddWithValue("@ID", userId);
                object result = getRoleCmd.ExecuteScalar();
                if (result == null || result == DBNull.Value) { WriteResponse(false, "Utilisateur non trouvé"); return; }
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
                    "Tentative d'attribution du rôle SuperAdmin à l'utilisateur ID " + userId + " par un rôle " + callerRole);
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
                var serializer = new JavaScriptSerializer();
                validatedPermissionsJson = serializer.Serialize(validatedPermissions);
                query += ", MENU_PERMISSIONS = @PERMISSIONS";
            }

            query += " WHERE IDUSER = @ID";

            using (SqlCommand cmd = new SqlCommand(query, conn))
            {
                cmd.Parameters.AddWithValue("@NOM", nom);
                cmd.Parameters.AddWithValue("@EMAIL", email);
                cmd.Parameters.AddWithValue("@ROLEID", roleId);
                cmd.Parameters.AddWithValue("@TELEPHONE", string.IsNullOrEmpty(telephone) ? (object)DBNull.Value : telephone);
                cmd.Parameters.AddWithValue("@ACTIVE", active);
                cmd.Parameters.AddWithValue("@UPDATED_BY", currentUserId);
                cmd.Parameters.AddWithValue("@ID", userId);

                if (!string.IsNullOrEmpty(password)) cmd.Parameters.AddWithValue("@PWD", PasswordHelper.HashPassword(password));
                if (validatedPermissionsJson != null) cmd.Parameters.AddWithValue("@PERMISSIONS", validatedPermissionsJson);

                int rowsAffected = cmd.ExecuteNonQuery();
                if (rowsAffected == 0) { WriteResponse(false, "Aucune modification effectuée"); return; }
            }

            LogSecurityAction(conn, currentUserId, "USER_UPDATE",
                "Mise à jour de l'utilisateur ID " + userId + " (rôle cible: " + targetCurrentRole + " -> " + roleId + ")");

            WriteResponse(true, "Utilisateur mis à jour avec succès", userId);
        }
    }
    catch (SqlException ex)
    {
        if (ex.Number == 2627) WriteResponse(false, "Conflit d'identifiant (peut-être email déjà utilisé)");
        else if (ex.Number == 547) WriteResponse(false, "Violation de contrainte de clé étrangère");
        else { LogSecurityAction(null, AuthHelper.GetUserId(Context), "SQL_ERROR", ex.Message); WriteResponse(false, "Erreur de base de données"); }
    }
    catch (Exception ex)
    {
        Response.StatusCode = 500;
        LogSecurityAction(null, AuthHelper.GetUserId(Context), "SYSTEM_ERROR", ex.Message);
        WriteResponse(false, "Erreur système");
    }
}

private string GetQueryString(string key) { string val = Request.QueryString[key]; return val != null ? val.Trim() : ""; }
private int GetQueryInt(string key, int defaultValue) { string val = Request.QueryString[key]; if (string.IsNullOrEmpty(val)) return defaultValue; int r; return int.TryParse(val, out r) ? r : defaultValue; }
private bool IsValidEmail(string email) { try { var addr = new System.Net.Mail.MailAddress(email); return addr.Address == email; } catch { return false; } }

private void WriteResponse(bool success, string message, int userId = 0)
{
    var serializer = new JavaScriptSerializer();
    var response = new Dictionary<string, object>();
    response["success"] = success;
    response["message"] = message;
    if (userId > 0) response["userId"] = userId;
    Response.Write(serializer.Serialize(response));
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
    catch { }
}
</script>
