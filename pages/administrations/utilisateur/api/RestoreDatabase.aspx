<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Configuration" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.Clear();
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);
    
    try
    {
        // ✅ Vérification d'authentification - SuperAdmin uniquement
        if (!AuthHelper.RequireApiAuth(Context, 0))
        {
            Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        // ✅ Lire le corps de la requête
        string jsonBody = "";
        using (var reader = new StreamReader(Request.InputStream))
        {
            jsonBody = reader.ReadToEnd();
        }
        
        var serializer = new System.Web.Script.Serialization.JavaScriptSerializer();
        var data = serializer.Deserialize<Dictionary<string, object>>(jsonBody);
        
        string filePath = data.ContainsKey("filePath") ? data["filePath"].ToString() : "";
        string databaseName = data.ContainsKey("databaseName") ? data["databaseName"].ToString() : "MONAPPECOLE2";
        
        if (string.IsNullOrEmpty(filePath))
        {
            Response.Write("{\"success\":false,\"message\":\"Chemin du fichier manquant\"}");
            return;
        }
        
        // ✅ Vérifier que le chemin est sécurisé
        if (!IsSecurePath(filePath))
        {
            Response.Write("{\"success\":false,\"message\":\"Chemin de fichier invalide\"}");
            return;
        }
        
        string windowsPath = filePath.Replace("/", "\\");
        
        if (!File.Exists(windowsPath))
        {
            Response.Write("{\"success\":false,\"message\":\"Le fichier n'existe pas\"}");
            return;
        }
        
        // ✅ Utiliser la chaîne de connexion depuis Web.config
        string connectionString = ConfigurationManager.ConnectionStrings["MasterConnection"]?.ConnectionString;
        if (string.IsNullOrEmpty(connectionString))
        {
            Response.Write("{\"success\":false,\"message\":\"Erreur de configuration\"}");
            return;
        }
        
        using (SqlConnection conn = new SqlConnection(connectionString))
        {
            conn.Open();
            
            // Journalisation
            LogRestoreAction(conn, databaseName, windowsPath);
            
            // ÉTAPE 1: Forcer la déconnexion
            string killUsersSql = @"
                DECLARE @kill varchar(8000) = '';
                SELECT @kill = @kill + 'KILL ' + CONVERT(varchar(5), spid) + ';'
                FROM master..sysprocesses
                WHERE dbid = DB_ID('" + databaseName + @"')
                AND spid > 50
                AND spid != @@SPID;
                
                IF @kill != ''
                BEGIN
                    EXEC(@kill);
                END
            ";
            
            using (SqlCommand cmd = new SqlCommand(killUsersSql, conn))
            {
                cmd.ExecuteNonQuery();
            }
            
            // ÉTAPE 2: Mode SINGLE_USER
            string setSingleUserSql = @"
                ALTER DATABASE [" + databaseName + @"]
                SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
            ";
            
            using (SqlCommand cmd = new SqlCommand(setSingleUserSql, conn))
            {
                cmd.ExecuteNonQuery();
            }
            
            // ÉTAPE 3: Restaurer
            string restoreSql = @"
                RESTORE DATABASE [" + databaseName + @"]
                FROM DISK = N'" + windowsPath.Replace("'", "''") + @"'
                WITH REPLACE, STATS = 10;
            ";
            
            using (SqlCommand cmd = new SqlCommand(restoreSql, conn))
            {
                cmd.CommandTimeout = 3600;
                cmd.ExecuteNonQuery();
            }
            
            // ÉTAPE 4: Mode MULTI_USER
            string setMultiUserSql = @"
                ALTER DATABASE [" + databaseName + @"]
                SET MULTI_USER;
            ";
            
            using (SqlCommand cmd = new SqlCommand(setMultiUserSql, conn))
            {
                cmd.ExecuteNonQuery();
            }
            
            Response.Write("{\"success\":true,\"message\":\"Restauration réussie\"}");
        }
    }
    catch (Exception ex)
    {
        // ✅ Log sans exposer les détails
        LogError(ex);
        Response.Write("{\"success\":false,\"message\":\"Erreur lors de la restauration\"}");
    }
}

// ✅ Validation du chemin
private bool IsSecurePath(string path)
{
    if (string.IsNullOrEmpty(path)) return false;
    // Éviter les traversées de répertoires
    if (path.Contains("..")) return false;
    // Vérifier l'extension
    string ext = Path.GetExtension(path).ToLower();
    return ext == ".bak" || ext == ".backup";
}

// ✅ Journalisation
private void LogRestoreAction(SqlConnection conn, string databaseName, string filePath)
{
    try
    {
        string sql = @"INSERT INTO ADMIN_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                       VALUES (@UserId, 'RESTORE_DATABASE', @Details, @IP, GETDATE())";
        using (SqlCommand cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@UserId", AuthHelper.GetUserId(Context));
            cmd.Parameters.AddWithValue("@Details", $"Restauration de {databaseName} depuis {filePath}");
            cmd.Parameters.AddWithValue("@IP", Request.UserHostAddress);
            cmd.ExecuteNonQuery();
        }
    }
    catch { }
}

private void LogError(Exception ex)
{
    try
    {
        string logFile = Server.MapPath("~/App_Data/restore_errors.log");
        string entry = $"[{DateTime.Now}] {ex.Message}\n{ex.StackTrace}\n---\n";
        File.AppendAllText(logFile, entry);
    }
    catch { }
}
</script>