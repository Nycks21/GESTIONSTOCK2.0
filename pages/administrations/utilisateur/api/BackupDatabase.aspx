<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.Clear();
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);

    try
    {
        string action = Request.QueryString["action"];
        string method = Request.HttpMethod;

        if (action == "prepare")
        {
            // ✅ POST + CSRF + permission backup
            if (method != "POST" || !AuthHelper.RequireCsrfPermission(Context, "backup"))
            {
                Response.StatusCode = 403;
                Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
                return;
            }
            PrepareBackup();
        }
        else if (action == "execute")
        {
            // ✅ POST + CSRF + permission backup
            if (method != "POST" || !AuthHelper.RequireCsrfPermission(Context, "backup"))
            {
                Response.StatusCode = 403;
                Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
                return;
            }
            ExecuteBackup();
        }
        else if (action == "check")
        {
            // Lecture publique — renvoie juste l'état maintenance
            CheckBackup();
        }
        else if (action == "checkblock")
        {
            // Lecture publique — renvoie si l'utilisateur courant est bloqué
            CheckBlockStatus();
        }
        else
        {
            Response.StatusCode = 400;
            Response.Write("{\"success\":false,\"message\":\"Action non reconnue\"}");
        }
    }
    catch (Exception ex)
    {
        LogBackupError(ex, "Page_Load");
        Response.StatusCode = 500;
        Response.Write("{\"success\":false,\"message\":\"Erreur interne. Consultez l'administrateur.\"}");
    }
}

private void PrepareBackup()
{
    try
    {
        string time = Request.Form["time"];
        if (string.IsNullOrEmpty(time))
            time = DateTime.Now.AddMinutes(5).ToString("HH:mm");

        string block = Request.Form["block"] ?? "true";
        bool blockUsers = block.ToLower() == "true";

        // ✅ Vérifier qu'on peut déterminer la base courante AVANT de programmer
        string dbName = GetCurrentDatabaseName();
        if (string.IsNullOrEmpty(dbName))
        {
            Response.Write("{\"success\":false,\"message\":\"Impossible de déterminer la base de données active. Vérifiez la chaîne de connexion.\"}");
            return;
        }

        Application.Lock();
        Application["MaintenanceMode"] = true;
        Application["MaintenanceTime"] = time;
        Application["BlockUsers"] = blockUsers;
        Application["BackupDatabaseName"] = dbName;  // ← mémoriser pour l'étape execute
        Application.UnLock();

        Response.Write("{\"success\":true,\"message\":\"Sauvegarde programmée à " + Escape(time) + " sur la base [" + Escape(dbName) + "]\"}");
    }
    catch (Exception ex)
    {
        LogBackupError(ex, "PrepareBackup");
        Response.Write("{\"success\":false,\"message\":\"Erreur de programmation.\"}");
    }
}

private void ExecuteBackup()
{
    // ✅ Verrou applicatif : empêche 2 backups simultanés
    Application.Lock();
    bool alreadyRunning = (Application["BackupRunning"] != null && (bool)Application["BackupRunning"]);
    if (!alreadyRunning) Application["BackupRunning"] = true;
    Application.UnLock();

    if (alreadyRunning)
    {
        Response.Write("{\"success\":false,\"message\":\"Une sauvegarde est déjà en cours.\"}");
        return;
    }

    try
    {
        string connStr = AuthHelper.ConnectionString;
        if (string.IsNullOrEmpty(connStr))
        {
            Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion introuvable.\"}");
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // ✅ DÉTERMINATION DE LA BASE CIBLE
        //    1. Utiliser celle mémorisée par PrepareBackup (préférable)
        //    2. Sinon, lire directement depuis la connexion active
        // ═══════════════════════════════════════════════════════════
        string dbName = null;
        if (Application["BackupDatabaseName"] != null)
            dbName = Application["BackupDatabaseName"].ToString();

        if (string.IsNullOrEmpty(dbName))
            dbName = GetCurrentDatabaseName();

        if (string.IsNullOrEmpty(dbName))
        {
            Response.Write("{\"success\":false,\"message\":\"Impossible de déterminer la base de données active.\"}");
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // ✅ VÉRIFICATION : la base existe bien sur le serveur SQL
        // ═══════════════════════════════════════════════════════════
        using (SqlConnection connCheck = new SqlConnection(connStr))
        {
            connCheck.Open();
            using (SqlCommand cmdCheck = new SqlCommand(
                "SELECT COUNT(*) FROM sys.databases WHERE name = @dbName", connCheck))
            {
                cmdCheck.Parameters.AddWithValue("@dbName", dbName);
                int exists = Convert.ToInt32(cmdCheck.ExecuteScalar());
                if (exists == 0)
                {
                    Response.Write("{\"success\":false,\"message\":\"La base de données [" + Escape(dbName) + "] est introuvable sur le serveur.\"}");
                    return;
                }
            }
        }

        // Blocage des autres utilisateurs (1 minute)
        BlockAllUsers(connStr);

        // ═══════════════════════════════════════════════════════════
        // BACKUP
        // ═══════════════════════════════════════════════════════════
        string backupFolder = GetBackupFolder();
        string fileName = "backup_" + dbName + "_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".bak";
        string filePath = Path.Combine(backupFolder, fileName);

        string sql = "BACKUP DATABASE [" + dbName.Replace("]", "]]") + "] " +
                     "TO DISK = N'" + filePath.Replace("'", "''") + "' " +
                     "WITH FORMAT, STATS = 10";

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 120;
                cmd.ExecuteNonQuery();
            }
        }

        // ✅ Sortir du mode maintenance
        Application.Lock();
        Application["MaintenanceMode"] = false;
        Application.Remove("MaintenanceTime");
        Application.Remove("BackupDatabaseName");
        Application.UnLock();

        if (!File.Exists(filePath))
        {
            Response.Write("{\"success\":false,\"message\":\"Le fichier de sauvegarde n'a pas été créé.\"}");
            return;
        }

        // Log de sécurité
        try
        {
            using (SqlConnection connLog = new SqlConnection(connStr))
            {
                connLog.Open();
                using (SqlCommand logCmd = new SqlCommand(
                    @"INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                      VALUES (@userId, 'BACKUP_EXECUTE', @details, @ip, GETDATE())", connLog))
                {
                    logCmd.Parameters.AddWithValue("@userId", AuthHelper.GetUserId(Context));
                    logCmd.Parameters.AddWithValue("@details", "Sauvegarde de [" + dbName + "] : " + fileName);
                    logCmd.Parameters.AddWithValue("@ip", Context.Request.UserHostAddress);
                    logCmd.ExecuteNonQuery();
                }
            }
        }
        catch { /* table absente → ignore */ }

        // ✅ Ne renvoie que le nom + la taille. Téléchargement via DownloadBackup.aspx
        long fileSize = new FileInfo(filePath).Length;
        Response.Write("{\"success\":true," +
                       "\"message\":\"Sauvegarde effectuée\"," +
                       "\"fileName\":\"" + Escape(fileName) + "\"," +
                       "\"fileSize\":" + fileSize + "," +
                       "\"database\":\"" + Escape(dbName) + "\"}");
    }
    catch (Exception ex)
    {
        // Sortir du mode maintenance en cas d'erreur
        try
        {
            Application.Lock();
            Application["MaintenanceMode"] = false;
            Application.Remove("MaintenanceTime");
            Application.Remove("BackupDatabaseName");
            Application.UnLock();
        }
        catch { }

        LogBackupError(ex, "ExecuteBackup");
        Response.Write("{\"success\":false,\"message\":\"Erreur lors de la sauvegarde. Consultez l'administrateur.\"}");
    }
    finally
    {
        Application.Lock();
        Application["BackupRunning"] = false;
        Application.UnLock();
    }
}

// ═══════════════════════════════════════════════════════════════
// ✅ DÉTERMINE LE NOM DE LA BASE COURANTE
// ------------------------------------------------------------
// Priorité :
//   1. Lecture de l'InitialCatalog de la chaîne "MaConnexion"
//   2. Fallback : exécution de SELECT DB_NAME() sur la connexion
//   3. Fallback AppSettings (compatibilité ascendante)
// ═══════════════════════════════════════════════════════════════
private string GetCurrentDatabaseName()
{
    // ─── 1) Lire depuis la chaîne de connexion "MaConnexion" ───
    try
    {
        var cs = ConfigurationManager.ConnectionStrings["MaConnexion"];
        if (cs != null && !string.IsNullOrEmpty(cs.ConnectionString))
        {
            var builder = new SqlConnectionStringBuilder(cs.ConnectionString);
            if (!string.IsNullOrEmpty(builder.InitialCatalog))
                return builder.InitialCatalog;
        }
    }
    catch { }

    // ─── 2) Fallback : interroger directement le serveur ───
    try
    {
        string connStr = AuthHelper.ConnectionString;
        if (!string.IsNullOrEmpty(connStr))
        {
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (SqlCommand cmd = new SqlCommand("SELECT DB_NAME()", conn))
                {
                    object result = cmd.ExecuteScalar();
                    if (result != null && result != DBNull.Value)
                        return result.ToString();
                }
            }
        }
    }
    catch { }

    // ─── 3) Fallback : AppSettings (ancien comportement) ───
    try
    {
        string appSettingDb = ConfigurationManager.AppSettings["DatabaseName"];
        if (!string.IsNullOrEmpty(appSettingDb))
            return appSettingDb;
    }
    catch { }

    return null;
}

private void BlockAllUsers(string connStr)
{
    try
    {
        int currentUserId = AuthHelper.GetUserId(Context);
        int currentRole = AuthHelper.GetUserRole(Context);

        if (currentRole != 0)
        {
            LogBackupError(new Exception("Tentative de blocage par rôle " + currentRole), "BlockAllUsers");
            return;
        }

        DateTime blockUntil = DateTime.Now.AddMinutes(1);

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            string sql = @"
                UPDATE USERS
                SET BLOCKED_UNTIL = @BlockUntil,
                    SESSION_TOKEN = NULL,
                    LAST_PC = NULL,
                    LAST_LOGIN = DATEADD(MINUTE, -1, GETDATE())
                WHERE IDUSER != @CurrentUserId AND ROLEID != 0";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@BlockUntil", blockUntil);
                cmd.Parameters.AddWithValue("@CurrentUserId", currentUserId);
                cmd.ExecuteNonQuery();
            }
        }
    }
    catch (Exception ex)
    {
        LogBackupError(ex, "BlockAllUsers");
    }
}

private void CheckBlockStatus()
{
    try
    {
        bool isBlocked = false;
        string blockedUntil = "";
        int remainingSeconds = 0;

        if (Session == null || Session["authenticated"] == null || !(bool)Session["authenticated"])
        {
            Response.Write("{\"success\":true,\"isBlocked\":false,\"blockedUntil\":\"\",\"remainingSeconds\":0}");
            return;
        }

        int userId = Session["IDUSER"] != null ? Convert.ToInt32(Session["IDUSER"]) : 0;
        int userRole = Session["USERROLE"] != null ? Convert.ToInt32(Session["USERROLE"]) : -1;

        if (userRole != 0 && userId > 0)
        {
            string connStr = AuthHelper.ConnectionString;
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string sql = "SELECT BLOCKED_UNTIL FROM USERS WHERE IDUSER = @id";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", userId);
                    object result = cmd.ExecuteScalar();
                    if (result != null && result != DBNull.Value)
                    {
                        DateTime until = Convert.ToDateTime(result);
                        if (until > DateTime.Now)
                        {
                            isBlocked = true;
                            remainingSeconds = (int)Math.Ceiling((until - DateTime.Now).TotalSeconds);
                            blockedUntil = until.ToString("HH:mm:ss");
                        }
                        else
                        {
                            using (SqlCommand clearCmd = new SqlCommand(
                                "UPDATE USERS SET BLOCKED_UNTIL = NULL WHERE IDUSER = @id", conn))
                            {
                                clearCmd.Parameters.AddWithValue("@id", userId);
                                clearCmd.ExecuteNonQuery();
                            }
                        }
                    }
                }
            }
        }

        Response.Write("{\"success\":true,\"isBlocked\":" + isBlocked.ToString().ToLower() +
                       ",\"blockedUntil\":\"" + blockedUntil +
                       "\",\"remainingSeconds\":" + remainingSeconds + "}");
    }
    catch (Exception ex)
    {
        LogBackupError(ex, "CheckBlockStatus");
        Response.Write("{\"success\":false,\"message\":\"Erreur interne\"}");
    }
}

private string GetBackupFolder()
{
    try
    {
        string folder = Server.MapPath("~/App_Data/Backups");
        if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);
        return folder;
    }
    catch
    {
        return Path.GetTempPath();
    }
}

private void CheckBackup()
{
    try
    {
        bool isMaintenance = false;
        string time = "";
        string dbName = "";

        if (Application["MaintenanceMode"] != null)
            isMaintenance = (bool)Application["MaintenanceMode"];
        if (isMaintenance && Application["MaintenanceTime"] != null)
            time = Application["MaintenanceTime"].ToString();
        if (Application["BackupDatabaseName"] != null)
            dbName = Application["BackupDatabaseName"].ToString();

        Response.Write("{\"success\":true,\"isMaintenance\":" +
                       (isMaintenance ? "true" : "false") +
                       ",\"maintenanceTime\":\"" + Escape(time) + "\"" +
                       ",\"database\":\"" + Escape(dbName) + "\"}");
    }
    catch (Exception ex)
    {
        LogBackupError(ex, "CheckBackup");
        Response.Write("{\"success\":false,\"message\":\"Erreur interne\"}");
    }
}

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════
private static string Escape(string s)
{
    if (s == null) return "";
    return s.Replace("\\", "\\\\").Replace("\"", "\\\"")
            .Replace("\r", "").Replace("\n", "").Replace("\t", " ");
}

private void LogBackupError(Exception ex, string context)
{
    try
    {
        string logFile = Server.MapPath("~/App_Data/backup_log.txt");
        string entry = "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] " +
                       context + " - " + ex.Message + Environment.NewLine +
                       "Stack: " + ex.StackTrace + Environment.NewLine +
                       "User: " + AuthHelper.GetUserId(Context) + Environment.NewLine +
                       "IP: " + Context.Request.UserHostAddress + Environment.NewLine +
                       "---" + Environment.NewLine;
        File.AppendAllText(logFile, entry);
    }
    catch { }
}
</script>
