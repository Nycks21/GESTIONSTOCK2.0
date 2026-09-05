<%@ Page Language="C#" ResponseEncoding="utf-8" EnableSessionState="True" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Collections.Generic" %>

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
        // ✅ Vérification d'authentification - Admin ou SuperAdmin
        if (!AuthHelper.RequireApiAuth(Context, 1)) // 1 = Admin
        {
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

        string jsonString = "";
        using (var reader = new System.IO.StreamReader(Request.InputStream))
        {
            jsonString = reader.ReadToEnd();
        }

        if (string.IsNullOrEmpty(jsonString))
        {
            WriteResponse(false, "Données JSON vides");
            return;
        }

        var serializer = new JavaScriptSerializer();
        Dictionary<string, object> data = null;

        try
        {
            data = serializer.Deserialize<Dictionary<string, object>>(jsonString);
        }
        catch (Exception ex)
        {
            WriteResponse(false, "Format JSON invalide");
            return;
        }

        if (data == null)
        {
            WriteResponse(false, "Données invalides");
            return;
        }

        string username = GetStringValue(data, "USERNAME");
        string nom = GetStringValue(data, "NOM");
        string password = GetStringValue(data, "PWD");
        string email = GetStringValue(data, "EMAIL");
        string telephone = GetStringValue(data, "TELEPHONE");
        int roleId = GetIntValue(data, "ROLEID", 1);
        int active = GetIntValue(data, "ACTIVE", 1);

        // ✅ Validation des entrées
        if (!ValidateUserData(username, nom, password, email, roleId))
        {
            return;
        }

        List<string> permissions = new List<string>();
        if (data.ContainsKey("PERMISSIONS") && data["PERMISSIONS"] != null)
        {
            object permsObj = data["PERMISSIONS"];
            if (permsObj is ArrayList)
            {
                foreach (var p in (ArrayList)permsObj)
                {
                    permissions.Add(p.ToString());
                }
            }
        }

        // 🔹 Récupération de l'ID de l'utilisateur connecté (celui qui crée)
        int currentUserId = AuthHelper.GetUserId(Context);

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            // ✅ Vérifier si l'utilisateur existe déjà
            using (SqlCommand checkCmd = new SqlCommand("SELECT COUNT(*) FROM USERS WHERE USERNAME = @USERNAME", conn))
            {
                checkCmd.Parameters.AddWithValue("@USERNAME", username);
                int existing = (int)checkCmd.ExecuteScalar();
                if (existing > 0)
                {
                    WriteResponse(false, "Ce nom d'utilisateur existe déjà");
                    return;
                }
            }

            // Sérialiser les permissions en JSON
            string permissionsJson = serializer.Serialize(permissions);

            // 🔹 Requête modifiée : CREATED_BY utilise @CREATED_BY
            using (SqlCommand cmd = new SqlCommand(
                @"INSERT INTO USERS (USERNAME, NOM, PWD, EMAIL, ROLEID, TELEPHONE, ACTIVE, MENU_PERMISSIONS, CREATED_AT, CREATED_BY)
                  OUTPUT INSERTED.IDUSER
                  VALUES (@USERNAME, @NOM, @PWD, @EMAIL, @ROLEID, @TELEPHONE, @ACTIVE, @MENU_PERMISSIONS, GETDATE(), @CREATED_BY)", conn))
            {
                cmd.Parameters.AddWithValue("@USERNAME", username);
                cmd.Parameters.AddWithValue("@NOM", nom);
                cmd.Parameters.AddWithValue("@PWD", PasswordHelper.HashPassword(password));
                cmd.Parameters.AddWithValue("@EMAIL", email);
                cmd.Parameters.AddWithValue("@ROLEID", roleId);
                cmd.Parameters.AddWithValue("@TELEPHONE", string.IsNullOrEmpty(telephone) ? (object)DBNull.Value : telephone);
                cmd.Parameters.AddWithValue("@ACTIVE", active);
                cmd.Parameters.AddWithValue("@MENU_PERMISSIONS", permissionsJson);
                // 🔹 Ajout du paramètre pour l'ID du créateur
                cmd.Parameters.AddWithValue("@CREATED_BY", currentUserId);

                int newUserId = (int)cmd.ExecuteScalar();

                // ✅ Journalisation de l'action
                LogSecurityAction(conn, currentUserId, "USER_CREATE", "Création de l'utilisateur " + username);

                WriteResponse(true, "Utilisateur ajouté avec succès", newUserId);
            }
        }
    }
    catch (SqlException ex)
    {
        if (ex.Number == 2627)
        {
            WriteResponse(false, "Ce nom d'utilisateur existe déjà");
        }
        else if (ex.Number == 547)
        {
            WriteResponse(false, "Violation de contrainte de clé étrangère");
        }
        else
        {
            LogSecurityAction(null, AuthHelper.GetUserId(Context), "SQL_ERROR", ex.Message);
            WriteResponse(false, "Erreur de base de données");
        }
    }
    catch (Exception ex)
    {
        Response.StatusCode = 500;
        LogSecurityAction(null, AuthHelper.GetUserId(Context), "SYSTEM_ERROR", ex.Message);
        WriteResponse(false, "Erreur système");
    }
}

// ✅ Validation des données (inchangé)
private bool ValidateUserData(string username, string nom, string password, string email, int roleId)
{
    if (string.IsNullOrEmpty(username))
    {
        WriteResponse(false, "Le nom d'utilisateur est requis");
        return false;
    }
    if (username.Length < 3 || username.Length > 50)
    {
        WriteResponse(false, "Le nom d'utilisateur doit contenir entre 3 et 50 caractères");
        return false;
    }
    if (!System.Text.RegularExpressions.Regex.IsMatch(username, @"^[a-zA-Z0-9_]+$"))
    {
        WriteResponse(false, "Le nom d'utilisateur contient des caractères invalides");
        return false;
    }

    if (string.IsNullOrEmpty(nom))
    {
        WriteResponse(false, "Le nom complet est requis");
        return false;
    }
    if (nom.Length > 100)
    {
        WriteResponse(false, "Le nom complet est trop long");
        return false;
    }

    if (string.IsNullOrEmpty(password))
    {
        WriteResponse(false, "Le mot de passe est requis");
        return false;
    }
    if (password.Length < 8)
    {
        WriteResponse(false, "Le mot de passe doit contenir au moins 8 caractères");
        return false;
    }

    if (string.IsNullOrEmpty(email))
    {
        WriteResponse(false, "L'email est requis");
        return false;
    }
    if (!IsValidEmail(email))
    {
        WriteResponse(false, "Format d'email invalide");
        return false;
    }

    // ✅ Rôles autorisés
    int[] allowedRoles = { 0, 1, 2, 3, 4 };
    if (!Array.Exists(allowedRoles, r => r == roleId))
    {
        WriteResponse(false, "Rôle invalide");
        return false;
    }

    return true;
}

private string GetStringValue(Dictionary<string, object> data, string key)
{
    if (data.ContainsKey(key) && data[key] != null)
        return data[key].ToString();
    return "";
}

private int GetIntValue(Dictionary<string, object> data, string key, int defaultValue)
{
    if (data.ContainsKey(key) && data[key] != null)
    {
        try
        {
            return Convert.ToInt32(data[key]);
        }
        catch
        {
            return defaultValue;
        }
    }
    return defaultValue;
}

private bool IsValidEmail(string email)
{
    try
    {
        var addr = new System.Net.Mail.MailAddress(email);
        return addr.Address == email;
    }
    catch
    {
        return false;
    }
}

private void WriteResponse(bool success, string message, int userId = 0)
{
    var serializer = new JavaScriptSerializer();
    var response = new Dictionary<string, object>();
    response["success"] = success;
    response["message"] = message;
    if (userId > 0)
    {
        response["userId"] = userId;
    }
    Response.Write(serializer.Serialize(response));
}

// ✅ Journalisation de sécurité (modifiée pour accepter l'ID)
private void LogSecurityAction(SqlConnection conn, int userId, string action, string details)
{
    try
    {
        bool closeConn = conn == null;
        if (closeConn)
        {
            conn = new SqlConnection(connStr);
            conn.Open();
        }

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

        if (closeConn)
            conn.Close();
    }
    catch { /* Ne pas échouer si le log échoue */ }
}
</script>
