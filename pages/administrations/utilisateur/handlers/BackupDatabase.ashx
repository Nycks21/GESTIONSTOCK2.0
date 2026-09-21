<%@ WebHandler Language="C#" Class="BackupDatabaseHandler" %>
<%@ Assembly Name="System.Web.Extensions" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;

public class BackupDatabaseHandler : IHttpHandler
{
    public bool IsReusable { get { return false; } }

    // ============================================================
    // POINT D'ENTRÉE
    // ============================================================
    public void ProcessRequest(HttpContext context)
    {
        HttpResponse Response   = context.Response;

        Response.Clear();
        Response.ContentType    = "application/json";
        Response.ContentEncoding = new System.Text.UTF8Encoding(false);

        try
        {
            if (!AuthHelper.IsAuthenticated(context))
            {
                WriteError(Response, "Non authentifié");
                return;
            }

            int role = AuthHelper.GetUserRole(context);
            if (role != 0)
            {
                WriteError(Response, "Permissions insuffisantes (SuperAdmin requis)");
                return;
            }

            string action = context.Request.QueryString["action"];
            switch (action)
            {
                case "prepare": PrepareBackup(context);     break;
                case "execute": ExecuteBackup(context);     break;
                case "check":   CheckBackupStatus(context); break;
                default:        WriteError(Response, "Action non reconnue"); break;
            }
        }
        catch (Exception ex)
        {
            // On loggue la stack trace complète avant de renvoyer le message
            LogBackupAction("Erreur handler: " + ex.ToString());
            WriteError(Response, ex.Message);
        }
    }

    // ============================================================
    // PREPARE
    // ============================================================
    private void PrepareBackup(HttpContext context)
    {
        var Response = context.Response;
        var Request  = context.Request;
        var Session  = context.Session;

        string maintenanceTime = Request.QueryString["time"];
        if (string.IsNullOrEmpty(maintenanceTime))
            maintenanceTime = DateTime.Now.AddMinutes(5).ToString("HH:mm");

        string maintenanceMessage = string.Format(
            "⚠️ MAINTENANCE PROGRAMMÉE\n\n" +
            "La base de données sera sauvegardée à {0}.\n\n" +
            "Veuillez sauvegarder votre travail. Vous serez déconnecté dans 5 minutes.",
            maintenanceTime);

        Session["MaintenanceTime"]    = maintenanceTime;
        Session["MaintenanceStarted"] = DateTime.Now.ToString();

        LogBackupAction(string.Format("Préparation sauvegarde programmée à {0}", maintenanceTime));

        var result = new Dictionary<string, object>();
        result["success"]         = true;
        result["message"]         = maintenanceMessage;
        result["maintenanceTime"] = maintenanceTime;

        WriteJson(Response, result);
    }

    // ============================================================
    // EXECUTE : déconnexion + sauvegarde + téléchargement
    // ============================================================
    private void ExecuteBackup(HttpContext context)
    {
        var Response = context.Response;

        string connStr = AuthHelper.ConnectionString;
        if (string.IsNullOrEmpty(connStr))
        {
            WriteError(Response, "Chaîne de connexion non trouvée");
            return;
        }

        string databaseName   = "MONAPPECOLE2";
        string backupFileName = string.Format("backup_{0}_{1}.bak",
                                              databaseName,
                                              DateTime.Now.ToString("yyyyMMdd_HHmmss"));
        string backupPath     = Path.Combine(Path.GetTempPath(), backupFileName);

        try
        {
            // ---------- 1) Déconnexion des utilisateurs ----------
            int currentUserId = AuthHelper.GetUserId(context);

            LogBackupAction("Déconnexion des utilisateurs...");
            DisconnectAllUsers(context, currentUserId);
            LogBackupAction("Utilisateurs déconnectés");

            // ---------- 2) Sauvegarde ----------
            LogBackupAction("Préparation de la sauvegarde...");
            LogBackupAction("Sauvegarde de la base de données...");

            string backupQuery = string.Format(
                "BACKUP DATABASE [{0}] TO DISK = N'{1}' " +
                "WITH FORMAT, NOUNLOAD, NAME = N'Full Backup', SKIP, STATS = 10, COMPRESSION",
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

            // ---------- 3) Livraison du fichier ----------
            if (!File.Exists(backupPath))
            {
                LogBackupAction("Erreur: fichier .bak non créé à " + backupPath);
                WriteError(Response, "Le fichier de sauvegarde n'a pas été créé");
                return;
            }

            byte[] fileBytes = File.ReadAllBytes(backupPath);
            LogBackupAction(string.Format("Sauvegarde réussie : {0} ({1} MB)",
                                          backupFileName,
                                          fileBytes.Length / 1024 / 1024));

            Response.Clear();
            Response.ContentType = "application/octet-stream";
            Response.AppendHeader("Content-Disposition",
                string.Format("attachment; filename={0}", backupFileName));
            Response.BinaryWrite(fileBytes);
            Response.Flush();

            try { File.Delete(backupPath); } catch { /* non bloquant */ }
        }
        catch (Exception ex)
        {
            LogBackupAction("Erreur sauvegarde: " + ex.ToString());
            WriteError(Response, "Erreur lors de la sauvegarde: " + ex.Message);
        }
        finally
        {
            // Nettoyage de session dans TOUS les cas (succès, échec, exception)
            try
            {
                context.Session.Remove("MaintenanceTime");
                context.Session.Remove("MaintenanceStarted");
            }
            catch { /* Session peut être indisponible : on ignore */ }
        }
    }

    // ============================================================
    // DÉCONNEXION
    // ============================================================
    private void DisconnectAllUsers(HttpContext context, int currentUserId)
    {
        string connStr = AuthHelper.ConnectionString;
        if (string.IsNullOrEmpty(connStr))
            throw new InvalidOperationException(
                "Chaîne de connexion absente pour la déconnexion des utilisateurs");

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            const string sql = @"
                UPDATE USERS
                   SET SESSION_TOKEN = NULL,
                       LAST_PC       = NULL
                 WHERE IDUSER <> @CurrentUserId";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@CurrentUserId", currentUserId);
                int affected = cmd.ExecuteNonQuery();
                LogBackupAction(string.Format(
                    "{0} utilisateur(s) déconnectés pour la maintenance", affected));
            }
        }
    }

    // ============================================================
    // CHECK
    // ============================================================
    private void CheckBackupStatus(HttpContext context)
    {
        var Response = context.Response;
        var Session  = context.Session;

        var result = new Dictionary<string, object>();
        result["success"]         = true;
        result["isMaintenance"]   = (Session["MaintenanceTime"] != null);
        result["maintenanceTime"] = Session["MaintenanceTime"] as string ?? "";

        WriteJson(Response, result);
    }

    // ============================================================
    // LOG
    // ============================================================
    private void LogBackupAction(string message)
    {
        try
        {
            string logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                                          "App_Data", "backup_log.txt");
            string logDir  = Path.GetDirectoryName(logPath);
            if (!Directory.Exists(logDir)) Directory.CreateDirectory(logDir);

            string logEntry = string.Format("{0} - {1}{2}",
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                message,
                Environment.NewLine);

            File.AppendAllText(logPath, logEntry);
        }
        catch { /* le log ne doit jamais casser la réponse */ }
    }

    // ============================================================
    // HELPERS JSON
    // ============================================================
    private void WriteJson(HttpResponse Response, object obj)
    {
        var serializer = new JavaScriptSerializer();
        serializer.MaxJsonLength = int.MaxValue;
        Response.Write(serializer.Serialize(obj));
    }

    private void WriteError(HttpResponse Response, string message)
    {
        WriteJson(Response, new { success = false, message = message });
    }
}
