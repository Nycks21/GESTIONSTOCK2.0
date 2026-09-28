<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Threading" %>

<script runat="server">
// ⚠️ DRAPEAU : indique si les données du fichier ont déjà été écrites dans la réponse.
// Empêche le catch général de polluer la réponse si le transfert a déjà commencé.
private bool _fileTransferStarted = false;

protected void Page_Load(object sender, EventArgs e)
{
    Response.Cache.SetNoStore();

    try
    {
        // ═══════════════════════════════════════════════════════════
        // 1. Méthode POST uniquement
        // ═══════════════════════════════════════════════════════════
        if (Request.HttpMethod != "POST")
        {
            Response.StatusCode = 405;
            WriteError("Méthode non autorisée");
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // 2. Auth + CSRF + rôle SuperAdmin
        // ═══════════════════════════════════════════════════════════
        if (!AuthHelper.RequireCsrfSafePost(Context, 0))
        {
            Response.StatusCode = 403;
            WriteError("Accès non autorisé");
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // 3. Permission backup.download
        // ═══════════════════════════════════════════════════════════
        if (!AuthHelper.HasPermission("backup.download") &&
            !AuthHelper.HasPermission("backup"))
        {
            Response.StatusCode = 403;
            WriteError("Permission backup.download requise");
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // 4. Lecture du nom de fichier (form-urlencoded ou JSON)
        // ═══════════════════════════════════════════════════════════
        string fileName = Request.Form["fileName"];
        if (string.IsNullOrEmpty(fileName))
        {
            try
            {
                string body = new StreamReader(Request.InputStream).ReadToEnd();
                if (!string.IsNullOrEmpty(body) && body.TrimStart().StartsWith("{"))
                {
                    var serializer = new System.Web.Script.Serialization.JavaScriptSerializer();
                    var data = serializer.Deserialize<System.Collections.Generic.Dictionary<string, object>>(body);
                    if (data != null && data.ContainsKey("fileName") && data["fileName"] != null)
                        fileName = data["fileName"].ToString();
                }
            }
            catch { }
        }

        if (string.IsNullOrEmpty(fileName))
        {
            Response.StatusCode = 400;
            WriteError("Nom de fichier manquant");
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // 5. Anti path traversal
        // ═══════════════════════════════════════════════════════════
        string safeName = Path.GetFileName(fileName);
        if (string.IsNullOrEmpty(safeName) ||
            safeName != fileName ||
            !safeName.ToLower().EndsWith(".bak"))
        {
            LogSecurityViolation("Nom de fichier invalide : " + fileName);
            Response.StatusCode = 400;
            WriteError("Nom de fichier invalide");
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // 6. Chemin canonique sous ~/App_Data/Backups/
        // ═══════════════════════════════════════════════════════════
        string backupsRoot = Server.MapPath("~/App_Data/Backups/");
        string canonicalRoot = Path.GetFullPath(backupsRoot)
            .TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;

        string requestedPath = Path.Combine(backupsRoot, safeName);
        string canonicalFile = Path.GetFullPath(requestedPath);

        if (!canonicalFile.StartsWith(canonicalRoot, StringComparison.OrdinalIgnoreCase))
        {
            LogSecurityViolation("Path traversal détecté : " + fileName);
            Response.StatusCode = 400;
            WriteError("Chemin non autorisé");
            return;
        }

        if (!File.Exists(canonicalFile))
        {
            Response.StatusCode = 404;
            WriteError("Fichier introuvable");
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // 7. Audit
        // ═══════════════════════════════════════════════════════════
        long fileLength = new FileInfo(canonicalFile).Length;
        LogDownload(safeName, fileLength);

        // ═══════════════════════════════════════════════════════════
        // 8. Envoi du fichier en streaming
        //    ⚠️ IMPORTANT : on marque le début du transfert AVANT
        //    d'écrire quoi que ce soit, pour que le catch général
        //    n'ajoute PAS de JSON par-dessus les octets du fichier.
        // ═══════════════════════════════════════════════════════════
        _fileTransferStarted = true;

        Response.Clear();
        Response.ClearHeaders();
        Response.Buffer = false;
        Response.ContentType = "application/octet-stream";
        Response.AppendHeader("Content-Disposition",
            "attachment; filename=\"" + safeName.Replace("\"", "") + "\"");
        Response.AppendHeader("Content-Length", fileLength.ToString());
        Response.AppendHeader("X-Content-Type-Options", "nosniff");

        Response.TransmitFile(canonicalFile);
        Response.Flush();

        // ✅ Terminer proprement SANS Response.End()
        //    (évite ThreadAbortException qui serait capturée plus bas)
        HttpContext.Current.ApplicationInstance.CompleteRequest();
    }
    catch (ThreadAbortException)
    {
        // Exception normale déclenchée par certaines API ASP.NET — on l'ignore
        Thread.ResetAbort();
    }
    catch (Exception ex)
    {
        LogError(ex);

        // ⚠️ Ne JAMAIS écrire dans la réponse si le fichier a déjà commencé à être envoyé
        if (!_fileTransferStarted)
        {
            try
            {
                Response.StatusCode = 500;
                WriteError("Erreur interne");
            }
            catch { /* ignore */ }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════
private void WriteError(string message)
{
    if (_fileTransferStarted) return; // sécurité : ne jamais polluer une réponse déjà commencée

    Response.ContentType = "application/json";
    Response.Write("{\"success\":false,\"message\":\"" +
                   message.Replace("\"", "'") + "\"}");
}

private void LogDownload(string fileName, long size)
{
    try
    {
        string connStr = AuthHelper.ConnectionString;
        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();
            using (SqlCommand cmd = new SqlCommand(
                @"INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                  VALUES (@userId, 'BACKUP_DOWNLOAD', @details, @ip, GETDATE())", conn))
            {
                cmd.Parameters.AddWithValue("@userId", AuthHelper.GetUserId(Context));
                cmd.Parameters.AddWithValue("@details",
                    "Téléchargement de " + fileName + " (" + (size / 1024 / 1024) + " Mo)");
                cmd.Parameters.AddWithValue("@ip", Request.UserHostAddress);
                cmd.ExecuteNonQuery();
            }
        }
    }
    catch { /* table absente → ignore */ }

    try
    {
        string logFile = Server.MapPath("~/App_Data/backup_download.log");
        File.AppendAllText(logFile,
            "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] " +
            "USER=" + AuthHelper.GetUserId(Context) + " " +
            "FILE=" + fileName + " " +
            "SIZE=" + size + " " +
            "IP=" + Request.UserHostAddress + Environment.NewLine);
    }
    catch { }
}

private void LogSecurityViolation(string details)
{
    try
    {
        string logFile = Server.MapPath("~/App_Data/security.log");
        File.AppendAllText(logFile,
            "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] " +
            "⚠️ BACKUP_DOWNLOAD_VIOLATION USER=" + AuthHelper.GetUserId(Context) + " " +
            "DETAILS=" + details + " " +
            "IP=" + Request.UserHostAddress + Environment.NewLine);
    }
    catch { }
}

private void LogError(Exception ex)
{
    try
    {
        string logFile = Server.MapPath("~/App_Data/error_log.txt");
        File.AppendAllText(logFile,
            "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] " +
            "DownloadBackup ERROR: " + ex.Message + Environment.NewLine +
            "Stack: " + ex.StackTrace + Environment.NewLine +
            "---" + Environment.NewLine);
    }
    catch { }
}
</script>
