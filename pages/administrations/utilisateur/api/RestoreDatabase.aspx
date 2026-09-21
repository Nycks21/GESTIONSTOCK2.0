<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections.Generic" %>
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
        // ============================================================
        // ACTION SPÉCIALE : dbname → GET, lecture seule
        // ============================================================
        string requestedAction = Request.QueryString["action"];
        if (requestedAction == "dbname")
        {
            if (!AuthHelper.RequireApiAuth(Context, 0))
            {
                Response.StatusCode = 403;
                Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
                return;
            }

            string dbName = GetApplicationDatabaseName();
            if (string.IsNullOrEmpty(dbName))
                Response.Write("{\"success\":false,\"message\":\"Base de données introuvable\"}");
            else
            {
                var ser = new System.Web.Script.Serialization.JavaScriptSerializer();
                Response.Write(ser.Serialize(new { success = true, database = dbName }));
            }
            return;
        }

        // ============================================================
        // RESTAURATION : POST + CSRF + SuperAdmin
        // ============================================================
        if (!AuthHelper.RequireCsrfSafePost(Context, 0))
        {
            Response.StatusCode = 403;
            Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        // Lire le corps de la requête
        string jsonBody = "";
        using (var reader = new StreamReader(Request.InputStream))
        {
            jsonBody = reader.ReadToEnd();
        }

        var serializer = new System.Web.Script.Serialization.JavaScriptSerializer();
        var data = serializer.Deserialize<Dictionary<string, object>>(jsonBody);

        string filePath = data.ContainsKey("filePath") ? data["filePath"].ToString() : "";

        if (string.IsNullOrEmpty(filePath))
        {
            Response.Write("{\"success\":false,\"message\":\"Chemin du fichier manquant\"}");
            return;
        }

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

        // 1) Nom de la base
        string databaseName = GetApplicationDatabaseName();
        if (string.IsNullOrEmpty(databaseName))
        {
            Response.Write("{\"success\":false,\"message\":\"Impossible de déterminer le nom de la base de données\"}");
            return;
        }

        // 2) Chaîne master
        string masterConnStr = null;
        var masterCs = ConfigurationManager.ConnectionStrings["MasterConnection"];
        if (masterCs != null) masterConnStr = masterCs.ConnectionString;

        if (string.IsNullOrEmpty(masterConnStr))
        {
            var appCs = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (appCs == null)
            {
                Response.Write("{\"success\":false,\"message\":\"Erreur de configuration (MaConnexion absente)\"}");
                return;
            }
            masterConnStr = ReplaceDatabaseInConnectionString(appCs.ConnectionString, "master");
        }

        using (SqlConnection conn = new SqlConnection(masterConnStr))
        {
            conn.Open();

            LogRestoreAction(conn, databaseName, windowsPath);

            // ÉTAPE 1 : tuer les connexions
            string killUsersSql = @"
                DECLARE @kill varchar(8000) = '';
                SELECT @kill = @kill + 'KILL ' + CONVERT(varchar(5), spid) + ';'
                FROM master..sysprocesses
                WHERE dbid = DB_ID('" + databaseName.Replace("'", "''") + @"')
                AND spid > 50
                AND spid != @@SPID;
                IF @kill != ''
                BEGIN
                    EXEC(@kill);
                END
            ";
            using (SqlCommand cmd = new SqlCommand(killUsersSql, conn)) { cmd.ExecuteNonQuery(); }

            // ÉTAPE 2 : SINGLE_USER
            using (SqlCommand cmd = new SqlCommand(
                "ALTER DATABASE [" + databaseName + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;", conn))
            { cmd.ExecuteNonQuery(); }

            try
            {
                string restoreSql = "RESTORE DATABASE [" + databaseName + "] " +
                                    "FROM DISK = N'" + windowsPath.Replace("'", "''") + "' " +
                                    "WITH REPLACE, STATS = 10;";
                using (SqlCommand cmd = new SqlCommand(restoreSql, conn))
                {
                    cmd.CommandTimeout = 3600;
                    cmd.ExecuteNonQuery();
                }
            }
            finally
            {
                try
                {
                    using (SqlCommand cmd = new SqlCommand(
                        "ALTER DATABASE [" + databaseName + "] SET MULTI_USER;", conn))
                    { cmd.ExecuteNonQuery(); }
                }
                catch { }
            }

            var ser = new System.Web.Script.Serialization.JavaScriptSerializer();
            Response.Write(ser.Serialize(new
            {
                success = true,
                message = "Restauration réussie",
                database = databaseName
            }));
        }
    }
    catch (Exception ex)
    {
        LogError(ex);
        Response.Write("{\"success\":false,\"message\":\"Erreur lors de la restauration\"}");
    }
}

private string GetApplicationDatabaseName()
{
    var cs = ConfigurationManager.ConnectionStrings["MaConnexion"];
    if (cs != null && !string.IsNullOrEmpty(cs.ConnectionString))
    {
        string name = ExtractDatabaseFromConnectionString(cs.ConnectionString);
        if (!string.IsNullOrEmpty(name)) return name;
    }

    try
    {
        if (cs != null && !string.IsNullOrEmpty(cs.ConnectionString))
        {
            using (SqlConnection conn = new SqlConnection(cs.ConnectionString))
            {
                conn.Open();
                using (SqlCommand cmd = new SqlCommand("SELECT DB_NAME()", conn))
                {
                    object result = cmd.ExecuteScalar();
                    if (result != null && result != DBNull.Value) return result.ToString();
                }
            }
        }
    }
    catch { }

    return null;
}

private string ExtractDatabaseFromConnectionString(string connStr)
{
    if (string.IsNullOrEmpty(connStr)) return null;
    try
    {
        var builder = new SqlConnectionStringBuilder(connStr);
        if (!string.IsNullOrEmpty(builder.InitialCatalog)) return builder.InitialCatalog;
    }
    catch { }
    return null;
}

private string ReplaceDatabaseInConnectionString(string connStr, string newDatabase)
{
    try
    {
        var builder = new SqlConnectionStringBuilder(connStr);
        builder.InitialCatalog = newDatabase;
        return builder.ConnectionString;
    }
    catch { return connStr; }
}

private bool IsSecurePath(string path)
{
    if (string.IsNullOrEmpty(path)) return false;
    if (path.Contains("..")) return false;
    string ext = Path.GetExtension(path).ToLower();
    return ext == ".bak" || ext == ".backup";
}

private void LogRestoreAction(SqlConnection conn, string databaseName, string filePath)
{
    try
    {
        string sql = @"INSERT INTO ADMIN_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                       VALUES (@UserId, 'RESTORE_DATABASE', @Details, @IP, GETDATE())";
        using (SqlCommand cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@UserId", AuthHelper.GetUserId(Context));
            cmd.Parameters.AddWithValue("@Details",
                string.Format("Restauration de {0} depuis {1}", databaseName, filePath));
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
        string entry = string.Format("[{0}] {1}{2}{3}{2}---{2}",
            DateTime.Now, ex.Message, Environment.NewLine, ex.StackTrace);
        File.AppendAllText(logFile, entry);
    }
    catch { }
}
</script>
