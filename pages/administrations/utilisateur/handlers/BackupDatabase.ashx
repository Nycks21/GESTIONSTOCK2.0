<%@ Page Language="C#" ContentType="application/json" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Collections.Generic" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    // ✅ Vérification d'authentification et de rôle (SuperAdmin uniquement)
    if (!AuthHelper.IsAuthenticated(Context))
    {
        WriteError("Non authentifié");
        Response.End();
        return;
    }

    int role = AuthHelper.GetUserRole(Context);
    if (role != 0)
    {
        WriteError("Permissions insuffisantes (SuperAdmin requis)");
        Response.End();
        return;
    }

    Response.Clear();
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);

    try
    {
        string action = Request.QueryString["action"];

        if (action == "prepare")
        {
            PrepareBackup();
        }
        else if (action == "execute")
        {
            ExecuteBackup();
        }
        else if (action == "check")
        {
            CheckBackupStatus();
        }
        else
        {
            WriteError("Action non reconnue");
        }
    }
    catch (Exception ex)
    {
        WriteError(ex.Message.Replace("\"", "\\\""));
    }
    finally
    {
        Response.End();
    }
}

private void PrepareBackup()
{
    string maintenanceTime = Request.QueryString["time"];
    if (string.IsNullOrEmpty(maintenanceTime))
    {
        maintenanceTime = DateTime.Now.AddMinutes(5).ToString("HH:mm");
    }

    string maintenanceMessage = string.Format(
        "⚠️ MAINTENANCE PROGRAMMÉE\n\nLa base de données sera sauvegardée à {0}.\n\nVeuillez sauvegarder votre travail. Vous serez déconnecté dans 5 minutes.",
        maintenanceTime);

    // Enregistrer l'heure de maintenance en session
    Session["MaintenanceTime"] = maintenanceTime;
    Session["MaintenanceStarted"] = DateTime.Now.ToString();

    // Journaliser l'action
    LogBackupAction(string.Format("Préparation sauvegarde programmée à {0}", maintenanceTime));

    var result = new Dictionary<string, object>();
    result["success"] = true;
    result["message"] = maintenanceMessage;
    result["maintenanceTime"] = maintenanceTime;

    WriteJson(result);
}

private void ExecuteBackup()
{
    string connStr = AuthHelper.ConnectionString; // via AuthHelper
    if (string.IsNullOrEmpty(connStr))
    {
        WriteError("Chaîne de connexion non trouvée");
        return;
    }

    string databaseName = "MONAPPECOLE2";
    string backupFileName = string.Format("backup_{0}_{1}.bak", databaseName, DateTime.Now.ToString("yyyyMMdd_HHmmss"));
    string backupPath = Path.Combine(Path.GetTempPath(), backupFileName);

    try
    {
        // 1. Déconnecter tous les utilisateurs SAUF le SuperAdmin actuel
        int currentUserId = AuthHelper.GetUserId(Context);
        DisconnectAllUsers(currentUserId);

        // 2. Exécuter la sauvegarde
        string backupQuery = string.Format(
            "BACKUP DATABASE [{0}] TO DISK = N'{1}' WITH FORMAT, NOUNLOAD, NAME = N'Full Backup', SKIP, STATS = 10, COMPRESSION",
            databaseName, backupPath);

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();
            using (SqlCommand cmd = new SqlCommand(backupQuery, conn))
            {
                cmd.CommandTimeout = 300;
                cmd.ExecuteNonQuery();
            }
        }

        // 3. Vérifier que le fichier existe
        if (File.Exists(backupPath))
        {
            byte[] fileBytes = File.ReadAllBytes(backupPath);

            LogBackupAction(string.Format("Sauvegarde réussie : {0} ({1} MB)", backupFileName, fileBytes.Length / 1024 / 1024));

            Response.Clear();
            Response.ContentType = "application/octet-stream";
            Response.AppendHeader("Content-Disposition", string.Format("attachment; filename={0}", backupFileName));
            Response.BinaryWrite(fileBytes);
            Response.Flush();

            // Nettoyer
            try { File.Delete(backupPath); } catch { }

            // Nettoyer la session
            Session.Remove("MaintenanceTime");
            Session.Remove("MaintenanceStarted");
        }
        else
        {
            WriteError("Le fichier de sauvegarde n'a pas été créé");
        }
    }
    catch (Exception ex)
    {
        LogBackupAction(string.Format("Erreur sauvegarde: {0}", ex.Message));
        WriteError(string.Format("Erreur lors de la sauvegarde: {0}", ex.Message));
    }
}

private void DisconnectAllUsers(int currentUserId)
{
    string connStr = AuthHelper.ConnectionString;
    if (string.IsNullOrEmpty(connStr)) return;

    using (SqlConnection conn = new SqlConnection(connStr))
    {
        conn.Open();

        string sql = @"
            UPDATE USERS 
            SET SESSION_TOKEN = NULL, 
                LAST_PC = NULL 
            WHERE IDUSER != @CurrentUserId";

        using (SqlCommand cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@CurrentUserId", currentUserId);
            int affected = cmd.ExecuteNonQuery();
            LogBackupAction(string.Format("{0} utilisateur(s) déconnectés pour la maintenance", affected));
        }
    }
}

private void CheckBackupStatus()
{
    var result = new Dictionary<string, object>();
    result["success"] = true;
    result["isMaintenance"] = (Session["MaintenanceTime"] != null);
    result["maintenanceTime"] = Session["MaintenanceTime"] as string ?? "";

    WriteJson(result);
}

private void NotifyAllUsers(string maintenanceTime)
{
    try
    {
        // Stocker la maintenance dans Application (accessible à tous)
        System.Web.HttpContext.Current.Application.Lock();
        System.Web.HttpContext.Current.Application["MaintenanceMode"] = true;
        System.Web.HttpContext.Current.Application["MaintenanceTime"] = maintenanceTime;
        System.Web.HttpContext.Current.Application.Unlock();

        // Journaliser
        LogBackupAction(string.Format("Notification envoyée à tous les utilisateurs pour une maintenance à {0}", maintenanceTime));
    }
    catch (Exception ex)
    {
        LogBackupAction(string.Format("Erreur notification: {0}", ex.Message));
    }
}

private void LogBackupAction(string message)
{
    try
    {
        string logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "App_Data", "backup_log.txt");
        string logDir = Path.GetDirectoryName(logPath);
        if (!Directory.Exists(logDir)) Directory.CreateDirectory(logDir);

        string logEntry = string.Format("{0} - {1}{2}", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"), message, Environment.NewLine);
        File.AppendAllText(logPath, logEntry);
    }
    catch { }
}

private void WriteJson(object obj)
{
    var serializer = new JavaScriptSerializer();
    Response.Write(serializer.Serialize(obj));
}

private void WriteError(string message)
{
    WriteJson(new { success = false, message = message });
}
</script>