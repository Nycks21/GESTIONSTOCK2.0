<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Security.Cryptography" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json; charset=utf-8";
    Response.ContentEncoding = System.Text.Encoding.UTF8;
    Response.Clear();
    Response.Cache.SetNoStore();

    if (!AuthHelper.RequireApiAuth(Context, 1))
    {
        WriteJson(401, "error", "Accès non autorisé");
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
        WriteJson(405, "error", "Méthode non autorisée");
        return;
    }

    string idStr = Request.QueryString["id"];
    string nom = Request.QueryString["nom"];
    string email = Request.QueryString["email"];
    string roleStr = Request.QueryString["roleId"];
    string telephone = Request.QueryString["telephone"];
    string activeStr = Request.QueryString["active"];
    string password = Request.QueryString["password"];
    string permissionsJson = Request.QueryString["permissions"];

    if (nom != null) nom = nom.Trim();
    if (email != null) email = email.Trim();
    if (telephone != null) telephone = telephone.Trim();
    if (password != null) password = password.Trim();

    int id;
    if (string.IsNullOrEmpty(idStr) || !int.TryParse(idStr, out id))
    {
        WriteJson(400, "error", "ID utilisateur invalide");
        return;
    }

    if (string.IsNullOrEmpty(nom))
    {
        WriteJson(400, "error", "Le nom est requis");
        return;
    }
    if (string.IsNullOrEmpty(email))
    {
        WriteJson(400, "error", "L'email est requis");
        return;
    }

    int roleId = 1;
    if (!string.IsNullOrEmpty(roleStr))
        int.TryParse(roleStr, out roleId);

    int active = 0;
    if (!string.IsNullOrEmpty(activeStr))
        active = (activeStr == "1" || activeStr.Equals("true", StringComparison.OrdinalIgnoreCase)) ? 1 : 0;

    try
    {
        var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
        if (connSetting == null)
        {
            WriteJson(500, "error", "Chaîne de connexion introuvable");
            return;
        }

        using (SqlConnection conn = new SqlConnection(connSetting.ConnectionString))
        {
            conn.Open();

            using (SqlCommand checkCmd = new SqlCommand("SELECT COUNT(*) FROM USERS WHERE IDUSER = @ID", conn))
            {
                checkCmd.Parameters.AddWithValue("@ID", id);
                int exists = (int)checkCmd.ExecuteScalar();
                if (exists == 0)
                {
                    WriteJson(404, "error", "Utilisateur non trouvé");
                    return;
                }
            }

            // Mise à jour des informations de base
            string query = @"
                UPDATE USERS SET 
                    NOM = @NOM,
                    EMAIL = @EMAIL,
                    ROLEID = @ROLEID,
                    TELEPHONE = @TELEPHONE,
                    ACTIVE = @ACTIVE";

            if (!string.IsNullOrEmpty(password) && password.Length >= 8)
            {
                query += ", PWD = @PWD";
            }

            query += " WHERE IDUSER = @ID";

            using (SqlCommand cmd = new SqlCommand(query, conn))
            {
                cmd.Parameters.Add("@NOM", SqlDbType.NVarChar, 200).Value = nom;
                cmd.Parameters.Add("@EMAIL", SqlDbType.NVarChar, 200).Value = email;
                cmd.Parameters.Add("@ROLEID", SqlDbType.Int).Value = roleId;
                cmd.Parameters.Add("@TELEPHONE", SqlDbType.NVarChar, 50).Value = string.IsNullOrEmpty(telephone) ? (object)DBNull.Value : telephone;
                cmd.Parameters.Add("@ACTIVE", SqlDbType.Bit).Value = active;
                cmd.Parameters.Add("@ID", SqlDbType.Int).Value = id;

                if (!string.IsNullOrEmpty(password) && password.Length >= 8)
                {
                    cmd.Parameters.Add("@PWD", SqlDbType.NVarChar, 512).Value = PasswordHelper.HashPassword(password);
                }

                cmd.ExecuteNonQuery();
            }

            // Sauvegarde des permissions
            if (!string.IsNullOrEmpty(permissionsJson))
            {
                SavePermissions(id, permissionsJson, conn);
            }

            WriteJson(200, "success", "Utilisateur mis à jour avec succès");
        }
    }
    catch (Exception ex)
    {
        string safeMessage = ex.Message.Replace("\"", "'").Replace("\r", "").Replace("\n", " ");
        WriteJson(500, "error", "Erreur serveur: " + safeMessage);
    }
}

private void SavePermissions(int userId, string permissionsJson, SqlConnection conn)
{
    // Vérifier si la colonne MENU_PERMISSIONS existe
    string checkColumnQuery = @"
        SELECT COUNT(*) 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'MENU_PERMISSIONS'";
    
    SqlCommand checkCmd = new SqlCommand(checkColumnQuery, conn);
    int columnExists = (int)checkCmd.ExecuteScalar();
    
    if (columnExists > 0)
    {
        // Utiliser la colonne JSON
        string sql = "UPDATE USERS SET MENU_PERMISSIONS = @permissions WHERE IDUSER = @id";
        SqlCommand cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@permissions", permissionsJson);
        cmd.Parameters.AddWithValue("@id", userId);
        cmd.ExecuteNonQuery();
    }
    else
    {
        // Vérifier si la table USER_PERMISSIONS existe
        string checkTableQuery = @"
            SELECT COUNT(*) 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_NAME = 'USER_PERMISSIONS'";
        
        SqlCommand checkTableCmd = new SqlCommand(checkTableQuery, conn);
        int tableExists = (int)checkTableCmd.ExecuteScalar();
        
        if (tableExists > 0)
        {
            // Supprimer les anciennes permissions
            string deleteSql = "DELETE FROM USER_PERMISSIONS WHERE USER_ID = @id";
            SqlCommand deleteCmd = new SqlCommand(deleteSql, conn);
            deleteCmd.Parameters.AddWithValue("@id", userId);
            deleteCmd.ExecuteNonQuery();
            
            // Insérer les nouvelles permissions
            var serializer = new JavaScriptSerializer();
            List<string> permissions = serializer.Deserialize<List<string>>(permissionsJson);
            
            foreach (string perm in permissions)
            {
                string insertSql = "INSERT INTO USER_PERMISSIONS (USER_ID, PERMISSION_NAME) VALUES (@id, @perm)";
                SqlCommand insertCmd = new SqlCommand(insertSql, conn);
                insertCmd.Parameters.AddWithValue("@id", userId);
                insertCmd.Parameters.AddWithValue("@perm", perm);
                insertCmd.ExecuteNonQuery();
            }
        }
    }
}

private void WriteJson(int statusCode, string status, string message)
{
    Response.StatusCode = statusCode;
    bool success = (status == "success");
    string json = "{\"status\":\"" + status + "\",\"success\":" + success.ToString().ToLower() + ",\"message\":\"" + EscapeJson(message) + "\"}";
    Response.Write(json);
    HttpContext.Current.ApplicationInstance.CompleteRequest();
}

private string EscapeJson(string text)
{
    if (string.IsNullOrEmpty(text)) return "";
    return text.Replace("\\", "\\\\")
               .Replace("\"", "\\\"")
               .Replace("\r", "")
               .Replace("\n", " ");
}
</script>