<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.IO" %>

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
            if (method != "POST" || !AuthHelper.RequireCsrfSafePost(Context, 0))
            {
                Response.StatusCode = 403;
                Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
                return;
            }
            PrepareBackup();
        }
        else if (action == "execute")
        {
            if (method != "POST" || !AuthHelper.RequireCsrfSafePost(Context, 0))
            {
                Response.StatusCode = 403;
                Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
                return;
            }
            ExecuteBackup();
        }
        else if (action == "check")
        {
            // ✅ Lecture publique — appelée par toutes les pages pour afficher
            // la bannière de maintenance. Ne renvoie qu'un booléen + un timestamp.
            // Aucune donnée sensible → pas d'auth nécessaire.
            CheckBackup();
        }
        else if (action == "checkblock")
        {
            // ✅ Lecture publique — renvoie juste si l'utilisateur courant est bloqué.
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
        Response.StatusCode = 500;
        string safeMessage = ex.Message.Replace("\"", "'").Replace("\r", " ").Replace("\n", " ").Replace("\t", " ");
        Response.Write("{\"success\":false,\"message\":\"" + safeMessage + "\"}");
    }
}

private void PrepareBackup()
{
    try
    {
        string time = Request.Form["time"] ?? Request.QueryString["time"];
        if (string.IsNullOrEmpty(time))
            time = DateTime.Now.AddMinutes(5).ToString("HH:mm");

        string block = Request.Form["block"] ?? Request.QueryString["block"] ?? "true";
        bool blockUsers = block.ToLower() == "true";

        AddBlockedColumnIfNotExists();

        Application.Lock();
        Application["MaintenanceMode"] = true;
        Application["MaintenanceTime"] = time;
        Application["BlockUsers"] = blockUsers;
        Application.UnLock();

        Response.Write("{\"success\":true,\"message\":\"Sauvegarde programmée à " + time + "\"}");
    }
    catch (Exception ex)
    {
        string safeMessage = ex.Message.Replace("\"", "'").Replace("\r", " ").Replace("\n", " ").Replace("\t", " ");
        Response.Write("{\"success\":false,\"message\":\"" + safeMessage + "\"}");
    }
}

private void AddBlockedColumnIfNotExists()
{
    try
    {
        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();
            string checkColumn = @"
                IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                               WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'BLOCKED_UNTIL')
                BEGIN
                    ALTER TABLE USERS ADD BLOCKED_UNTIL DATETIME NULL
                END";
            using (SqlCommand cmd = new SqlCommand(checkColumn, conn)) { cmd.ExecuteNonQuery(); }
        }
    }
    catch (Exception ex)
    {
        System.Diagnostics.Debug.WriteLine("Erreur AddBlockedColumn: " + ex.Message);
    }
}

private void ExecuteBackup()
{
    try
    {
        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        if (string.IsNullOrEmpty(connStr))
        {
            Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée\"}");
            return;
        }

        BlockAllUsers(connStr);

        string backupFolder = GetBackupFolder();
        string fileName = "backup_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".bak";
        string filePath = Path.Combine(backupFolder, fileName);
        string dbName = "MONAPPECOLE2";

        string sql = "BACKUP DATABASE [" + dbName + "] TO DISK = N'" + filePath + "' WITH FORMAT, STATS = 10";

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.CommandTimeout = 300;
                cmd.ExecuteNonQuery();
            }
        }

        if (File.Exists(filePath))
        {
            Application.Lock();
            Application["MaintenanceMode"] = false;
            Application.Remove("MaintenanceTime");
            Application.UnLock();

            byte[] bytes = File.ReadAllBytes(filePath);

            Response.Clear();
            Response.ContentType = "application/octet-stream";
            Response.AppendHeader("Content-Disposition", "attachment; filename=" + fileName);
            Response.BinaryWrite(bytes);
        }
        else
        {
            Response.Write("{\"success\":false,\"message\":\"Le fichier de sauvegarde n'a pas été créé\"}");
        }
    }
    catch (Exception ex)
    {
        try
        {
            Application.Lock();
            Application["MaintenanceMode"] = false;
            Application.Remove("MaintenanceTime");
            Application.UnLock();
        }
        catch { }

        string safeMessage = ex.Message.Replace("\"", "'").Replace("\r", " ").Replace("\n", " ").Replace("\t", " ");
        Response.Write("{\"success\":false,\"message\":\"" + safeMessage + "\"}");
    }
}

private void BlockAllUsers(string connStr)
{
    try
    {
        int currentUserId = AuthHelper.GetUserId(Context);
        int currentRole = AuthHelper.GetUserRole(Context);

        if (currentRole != 0)
        {
            System.Diagnostics.Debug.WriteLine("Seul un SuperAdmin peut bloquer les utilisateurs");
            return;
        }

        DateTime blockUntil = DateTime.Now.AddMinutes(1);

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            string checkColumn = @"
                IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                               WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'BLOCKED_UNTIL')
                BEGIN
                    ALTER TABLE USERS ADD BLOCKED_UNTIL DATETIME NULL
                END";
            using (SqlCommand cmd = new SqlCommand(checkColumn, conn)) { cmd.ExecuteNonQuery(); }

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
        System.Diagnostics.Debug.WriteLine("Erreur blocage: " + ex.Message);
    }
}

private void CheckBlockStatus()
{
    try
    {
        bool isBlocked = false;
        string blockedUntil = "";
        int remainingSeconds = 0;

        // Lecture défensive : vérifier que la session existe
        if (Session == null || Session["authenticated"] == null || !(bool)Session["authenticated"])
        {
            Response.Write("{\"success\":true,\"isBlocked\":false,\"blockedUntil\":\"\",\"remainingSeconds\":0}");
            return;
        }

        int userId = Session["IDUSER"] != null ? Convert.ToInt32(Session["IDUSER"]) : 0;
        int userRole = Session["USERROLE"] != null ? Convert.ToInt32(Session["USERROLE"]) : -1;

        if (userRole != 0 && userId > 0)
        {
            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string checkColumn = @"
                    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'BLOCKED_UNTIL'";

                int columnExists = 0;
                using (SqlCommand checkCmd = new SqlCommand(checkColumn, conn))
                {
                    columnExists = (int)checkCmd.ExecuteScalar();
                }

                if (columnExists > 0)
                {
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
                                string clearSql = "UPDATE USERS SET BLOCKED_UNTIL = NULL WHERE IDUSER = @id";
                                using (SqlCommand clearCmd = new SqlCommand(clearSql, conn))
                                {
                                    clearCmd.Parameters.AddWithValue("@id", userId);
                                    clearCmd.ExecuteNonQuery();
                                }
                            }
                        }
                    }
                }
            }
        }

        Response.Write("{\"success\":true,\"isBlocked\":" + isBlocked.ToString().ToLower() + ",\"blockedUntil\":\"" + blockedUntil + "\",\"remainingSeconds\":" + remainingSeconds + "}");
    }
    catch (Exception ex)
    {
        string safeMessage = ex.Message.Replace("\"", "'").Replace("\r", " ").Replace("\n", " ").Replace("\t", " ");
        Response.Write("{\"success\":false,\"message\":\"" + safeMessage + "\"}");
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

        if (Application["MaintenanceMode"] != null)
            isMaintenance = (bool)Application["MaintenanceMode"];
        if (isMaintenance && Application["MaintenanceTime"] != null)
            time = Application["MaintenanceTime"].ToString();

        Response.Write("{\"success\":true,\"isMaintenance\":" + (isMaintenance ? "true" : "false") + ",\"maintenanceTime\":\"" + time + "\"}");
    }
    catch (Exception ex)
    {
        string safeMessage = ex.Message.Replace("\"", "'").Replace("\r", " ").Replace("\n", " ").Replace("\t", " ");
        Response.Write("{\"success\":false,\"message\":\"" + safeMessage + "\"}");
    }
}
</script>
