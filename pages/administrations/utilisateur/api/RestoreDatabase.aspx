<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.Clear();
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);

    var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };

    try
    {
        // ═══════════════════════════════════════════════════════════
        // ACTION dbname : GET, lecture seule
        // ═══════════════════════════════════════════════════════════
        string requestedAction = Request.QueryString["action"];
        if (requestedAction == "dbname")
        {
            if (!AuthHelper.RequireApiAuth(Context, 0))
            {
                Response.StatusCode = 403;
                Response.Write(serializer.Serialize(new { success = false, message = "Accès non autorisé" }));
                return;
            }

            string dbNameInfo = GetApplicationDatabaseName();
            if (string.IsNullOrEmpty(dbNameInfo))
                Response.Write(serializer.Serialize(new { success = false, message = "Base de données introuvable" }));
            else
                Response.Write(serializer.Serialize(new { success = true, database = dbNameInfo }));
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // RESTAURATION : POST + CSRF + SuperAdmin
        // ═══════════════════════════════════════════════════════════
        if (!AuthHelper.RequireCsrfSafePost(Context, 0))
        {
            Response.StatusCode = 403;
            Response.Write(serializer.Serialize(new { success = false, message = "Accès non autorisé" }));
            return;
        }

        string jsonBody;
        using (var reader = new StreamReader(Request.InputStream))
            jsonBody = reader.ReadToEnd();

        var data = serializer.Deserialize<Dictionary<string, object>>(jsonBody);
        string filePath = data.ContainsKey("filePath") ? data["filePath"].ToString() : "";

        if (string.IsNullOrEmpty(filePath))
        {
            Response.Write(serializer.Serialize(new { success = false, message = "Chemin du fichier manquant" }));
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // VALIDATION STRICTE DU CHEMIN (anti path traversal)
        // Le fichier DOIT être sous ~/App_Data/Backups/
        // ═══════════════════════════════════════════════════════════
        string backupsRoot = Server.MapPath("~/App_Data/Backups/");
        string canonicalRoot = Path.GetFullPath(backupsRoot)
            .TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;

        string normalizedPath = filePath.Replace("/", Path.DirectorySeparatorChar.ToString())
                                        .Replace("\\", Path.DirectorySeparatorChar.ToString());

        string fullRequestedPath = Path.IsPathRooted(normalizedPath)
            ? normalizedPath
            : Path.Combine(backupsRoot, normalizedPath);

        string canonicalFile = Path.GetFullPath(fullRequestedPath);

        if (!canonicalFile.StartsWith(canonicalRoot, StringComparison.OrdinalIgnoreCase))
        {
            LogSecurityViolation("Path traversal détecté : " + filePath);
            Response.Write(serializer.Serialize(new { success = false, message = "Chemin de fichier non autorisé" }));
            return;
        }

        if (!canonicalFile.ToLower().EndsWith(".bak") && !canonicalFile.ToLower().EndsWith(".backup"))
        {
            Response.Write(serializer.Serialize(new { success = false, message = "Extension invalide (.bak requis)" }));
            return;
        }

        if (!File.Exists(canonicalFile))
        {
            Response.Write(serializer.Serialize(new { success = false, message = "Le fichier n'existe pas" }));
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // Nom de la base
        // ═══════════════════════════════════════════════════════════
        string databaseName = GetApplicationDatabaseName();
        if (string.IsNullOrEmpty(databaseName))
        {
            Response.Write(serializer.Serialize(new { success = false, message = "Impossible de déterminer le nom de la base" }));
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // Chaîne master (Pooling désactivé)
        // ═══════════════════════════════════════════════════════════
        string masterConnStr = BuildMasterConnectionString();
        if (string.IsNullOrEmpty(masterConnStr))
        {
            Response.Write(serializer.Serialize(new { success = false, message = "Impossible de construire la connexion master" }));
            return;
        }

        // ═══════════════════════════════════════════════════════════
        // ✅ Marquer la restauration en cours (utilisé par AuthHelper
        //    pour rediriger avec ?msg=restore au lieu de ?msg=other_pc)
        // ═══════════════════════════════════════════════════════════
        Application.Lock();
        Application["RestoreInProgress"] = true;
        Application["RestoreStartedAt"] = DateTime.Now;
        Application.Remove("RestoreCompletedAt");
        Application.UnLock();

        try
        {
            // ═══════════════════════════════════════════════════════
            // EXÉCUTION DE LA RESTAURATION
            // ═══════════════════════════════════════════════════════
            var restoreResult = ExecuteRestore(databaseName, canonicalFile, masterConnStr);

            if (restoreResult.Success)
            {
                // ═══════════════════════════════════════════════════
                // ✅ Marquer la restauration comme TERMINÉE
                //    → le flag reste true pendant 60s pour que les
                //      utilisateurs déjà déconnectés voient le bon message
                // ═══════════════════════════════════════════════════
                Application.Lock();
                Application["RestoreInProgress"] = true;              // encore actif
                Application["RestoreCompletedAt"] = DateTime.Now;     // horodatage fin
                Application.UnLock();

                LogRestoreSuccess(databaseName, canonicalFile);

                // Vider les pools de connexions ADO.NET
                // (évite que la prochaine requête réutilise une connexion vers l'ancienne base)
                try { SqlConnection.ClearAllPools(); } catch { }

                Response.Write(serializer.Serialize(new
                {
                    success = true,
                    message = "Restauration réussie",
                    database = databaseName
                }));
            }
            else
            {
                // En cas d'échec : on retire le flag immédiatement
                Application.Lock();
                Application["RestoreInProgress"] = false;
                Application.Remove("RestoreStartedAt");
                Application.Remove("RestoreCompletedAt");
                Application.UnLock();

                LogError(new Exception(restoreResult.ErrorMessage));
                Response.Write(serializer.Serialize(new
                {
                    success = false,
                    message = restoreResult.ErrorMessage
                }));
            }
        }
        catch
        {
            // Sécurité : toujours retirer le flag en cas d'exception imprévue
            Application.Lock();
            Application["RestoreInProgress"] = false;
            Application.Remove("RestoreStartedAt");
            Application.Remove("RestoreCompletedAt");
            Application.UnLock();
            throw;
        }
    }
    catch (Exception ex)
    {
        LogError(ex);
        Response.Write(serializer.Serialize(new
        {
            success = false,
            message = "Erreur lors de la restauration : " + ex.Message
        }));
    }
}

// ═══════════════════════════════════════════════════════════════
// MOTEUR DE RESTAURATION — DROP + RESTORE WITH MOVE
// ─────────────────────────────────────────────────────────────
// Étapes :
//   1. Lire chemins physiques actuels (sys.master_files)
//   2. Lire noms logiques du .bak (RESTORE FILELISTONLY)
//   3. SINGLE_USER WITH ROLLBACK IMMEDIATE
//   4. DROP DATABASE                 ← libère les .mdf / .ldf
//   5. RESTORE ... WITH MOVE         ← recrée aux mêmes chemins
//   6. MULTI_USER
// ═══════════════════════════════════════════════════════════════
private RestoreResult ExecuteRestore(string databaseName, string backupFilePath, string masterConnStr)
{
    var result = new RestoreResult { Success = false };

    using (var conn = new SqlConnection(masterConnStr))
    {
        conn.Open();

        // ─── Étape 0 : Vérifier que la connexion ne pointe PAS vers la base cible ───
        string currentDb;
        using (var cmd = new SqlCommand("SELECT DB_NAME()", conn))
            currentDb = Convert.ToString(cmd.ExecuteScalar());

        if (string.Equals(currentDb, databaseName, StringComparison.OrdinalIgnoreCase))
        {
            result.ErrorMessage = "Erreur de configuration : la connexion pointe vers la base cible '" + currentDb
                                + "'. Vérifiez MasterConnection dans Web.config.";
            return result;
        }

        // ─── Étape 1 : Récupérer les chemins physiques ACTUELS ───
        string dataFilePath = null;
        string logFilePath  = null;

        using (var cmd = new SqlCommand(@"
            SELECT type_desc, physical_name
            FROM sys.master_files
            WHERE database_id = DB_ID(@dbName)", conn))
        {
            cmd.Parameters.AddWithValue("@dbName", databaseName);
            using (var rdr = cmd.ExecuteReader())
            {
                while (rdr.Read())
                {
                    string typeDesc = rdr.GetString(0);
                    string physical = rdr.GetString(1);
                    if (typeDesc == "ROWS")       dataFilePath = physical;
                    else if (typeDesc == "LOG")   logFilePath  = physical;
                }
            }
        }

        // Si la base n'existe plus (première restauration ou drop antérieur),
        // on utilise les chemins par défaut du serveur SQL
        if (string.IsNullOrEmpty(dataFilePath) || string.IsNullOrEmpty(logFilePath))
        {
            string defaultDataDir = GetDefaultDataDirectory(conn);
            string defaultLogDir = defaultDataDir;

            if (string.IsNullOrEmpty(defaultDataDir))
            {
                result.ErrorMessage = "Impossible de déterminer les chemins physiques de la base '" + databaseName
                                    + "' et aucun répertoire par défaut n'est disponible.";
                return result;
            }

            dataFilePath = Path.Combine(defaultDataDir, databaseName + ".mdf");
            logFilePath  = Path.Combine(defaultLogDir,  databaseName + "_log.ldf");
        }

        // ─── Étape 2 : Récupérer les NOMS LOGIQUES du backup ───
        string logicalDataName = null;
        string logicalLogName  = null;

        try
        {
            using (var cmd = new SqlCommand("RESTORE FILELISTONLY FROM DISK = @path", conn))
            {
                cmd.Parameters.AddWithValue("@path", backupFilePath);
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        string logicalName = rdr.GetString(0);     // LogicalName
                        string type        = rdr.GetString(2);     // Type : 'D' (data) ou 'L' (log)
                        if (type == "D" && logicalDataName == null)      logicalDataName = logicalName;
                        else if (type == "L" && logicalLogName == null)  logicalLogName  = logicalName;
                    }
                }
            }
        }
        catch (Exception exFileList)
        {
            result.ErrorMessage = "Impossible de lire les noms logiques du backup : " + exFileList.Message;
            return result;
        }

        if (string.IsNullOrEmpty(logicalDataName) || string.IsNullOrEmpty(logicalLogName))
        {
            result.ErrorMessage = "Le backup ne contient pas de fichiers de données ou de log valides.";
            return result;
        }

        // ─── Étape 3 : Audit ───
        LogRestoreAction(conn, databaseName, backupFilePath);

        // ─── Étape 4 : Vérifier les dossiers cibles ───
        string dataDir = Path.GetDirectoryName(dataFilePath);
        string logDir  = Path.GetDirectoryName(logFilePath);
        if (!Directory.Exists(dataDir) || !Directory.Exists(logDir))
        {
            result.ErrorMessage = "Les dossiers de destination des fichiers .mdf/.ldf n'existent pas : "
                                + dataDir + " ou " + logDir;
            return result;
        }

        // ─── Étape 5 : Construction du script SQL ───
        string safeDbName      = databaseName.Replace("]", "]]").Replace("'", "''");
        string safeBackupPath  = backupFilePath.Replace("'", "''");
        string safeLogicalData = logicalDataName.Replace("'", "''");
        string safeLogicalLog  = logicalLogName.Replace("'", "''");
        string safeDataPath    = dataFilePath.Replace("'", "''");
        string safeLogPath     = logFilePath.Replace("'", "''");

        string batchSql = @"
            SET NOCOUNT ON;

            -- ═══════════════════════════════════════════════════════════
            -- A) Forcer SINGLE_USER + rollback immédiat
            -- ═══════════════════════════════════════════════════════════
            IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'" + safeDbName + @"')
            BEGIN
                ALTER DATABASE [" + safeDbName + @"] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
            END

            -- ═══════════════════════════════════════════════════════════
            -- B) DROP DATABASE
            --    → LIBÈRE les handles fichiers .mdf et .ldf
            --    → C'est l'étape cruciale qui manquait avant !
            -- ═══════════════════════════════════════════════════════════
            IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'" + safeDbName + @"')
            BEGIN
                DROP DATABASE [" + safeDbName + @"];
            END

            -- ═══════════════════════════════════════════════════════════
            -- C) RESTORE avec MOVE
            --    → Recrée la base aux MÊMES chemins physiques
            --    → REPLACE au cas où des fichiers résiduels existent
            -- ═══════════════════════════════════════════════════════════
            RESTORE DATABASE [" + safeDbName + @"]
            FROM DISK = N'" + safeBackupPath + @"'
            WITH
                MOVE N'" + safeLogicalData + @"' TO N'" + safeDataPath + @"',
                MOVE N'" + safeLogicalLog  + @"' TO N'" + safeLogPath  + @"',
                REPLACE,
                STATS = 10;

            -- ═══════════════════════════════════════════════════════════
            -- D) Remettre MULTI_USER
            -- ═══════════════════════════════════════════════════════════
            ALTER DATABASE [" + safeDbName + @"] SET MULTI_USER;
        ";

        try
        {
            using (var cmd = new SqlCommand(batchSql, conn))
            {
                cmd.CommandTimeout = 3600;
                cmd.ExecuteNonQuery();
            }

            result.Success = true;
            return result;
        }
        catch (SqlException sqlEx)
        {
            result.ErrorMessage = "Erreur SQL lors de la restauration : " + sqlEx.Message;
            return result;
        }
        catch (Exception ex)
        {
            result.ErrorMessage = "Erreur lors de la restauration : " + ex.Message;
            return result;
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// Récupère le répertoire de données par défaut de SQL Server
// (utile si la base cible n'existe plus)
// ═══════════════════════════════════════════════════════════════
private string GetDefaultDataDirectory(SqlConnection conn)
{
    try
    {
        // Instance par défaut
        using (var cmd = new SqlCommand(
            "SELECT SERVERPROPERTY('InstanceDefaultDataPath')", conn))
        {
            object result = cmd.ExecuteScalar();
            if (result != null && result != DBNull.Value)
            {
                string path = result.ToString();
                if (!string.IsNullOrEmpty(path) && Directory.Exists(path))
                    return path.TrimEnd('\\', '/');
            }
        }

        // Fallback : chercher via master_files
        using (var cmd = new SqlCommand(@"
            SELECT TOP 1 LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)))
            FROM sys.master_files
            WHERE database_id = 1", conn))
        {
            object result = cmd.ExecuteScalar();
            if (result != null && result != DBNull.Value)
            {
                string path = result.ToString();
                if (!string.IsNullOrEmpty(path) && Directory.Exists(path))
                    return path.TrimEnd('\\', '/');
            }
        }
    }
    catch { }

    return null;
}

// ═══════════════════════════════════════════════════════════════
// CONSTRUCTION CHAÎNE MASTER (robuste)
// ═══════════════════════════════════════════════════════════════
private string BuildMasterConnectionString()
{
    var masterCs = ConfigurationManager.ConnectionStrings["MasterConnection"];
    if (masterCs != null && !string.IsNullOrEmpty(masterCs.ConnectionString))
        return ForceMasterOnConnectionString(masterCs.ConnectionString);

    var appCs = ConfigurationManager.ConnectionStrings["MaConnexion"];
    if (appCs == null || string.IsNullOrEmpty(appCs.ConnectionString))
        return null;

    return ForceMasterOnConnectionString(appCs.ConnectionString);
}

private string ForceMasterOnConnectionString(string connStr)
{
    string result = null;

    // Tentative 1 : SqlConnectionStringBuilder
    try
    {
        var builder = new SqlConnectionStringBuilder(connStr);
        builder.InitialCatalog = "master";
        builder.Pooling = false;   // ⚠️ CRUCIAL : évite la réutilisation d'une connexion poolée
        result = builder.ConnectionString;
    }
    catch { }

    // Tentative 2 : regex
    if (string.IsNullOrEmpty(result))
    {
        try
        {
            string s = connStr;

            s = Regex.Replace(s, @"(Initial\s*Catalog|Database)\s*=\s*[^;]*",
                "InitialCatalog=master", RegexOptions.IgnoreCase);
            if (s.IndexOf("InitialCatalog=master", StringComparison.OrdinalIgnoreCase) < 0)
                s = s.TrimEnd(';') + ";InitialCatalog=master;";

            s = Regex.Replace(s, @"Pooling\s*=\s*[^;]*",
                "Pooling=false", RegexOptions.IgnoreCase);
            if (s.IndexOf("Pooling=false", StringComparison.OrdinalIgnoreCase) < 0)
                s = s.TrimEnd(';') + ";Pooling=false;";

            result = s;
        }
        catch { }
    }

    // Contrôle final : ne doit PAS contenir le nom de la base cible
    if (!string.IsNullOrEmpty(result))
    {
        string appDb = GetApplicationDatabaseName();
        if (!string.IsNullOrEmpty(appDb))
        {
            string pattern = @"(Initial\s*Catalog|Database)\s*=\s*" + Regex.Escape(appDb);
            if (Regex.IsMatch(result, pattern, RegexOptions.IgnoreCase))
                return null;
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════
// UTILITAIRES
// ═══════════════════════════════════════════════════════════════
private string GetApplicationDatabaseName()
{
    var cs = ConfigurationManager.ConnectionStrings["MaConnexion"];
    if (cs != null && !string.IsNullOrEmpty(cs.ConnectionString))
    {
        string name = ExtractDatabaseFromConnectionString(cs.ConnectionString);
        if (!string.IsNullOrEmpty(name)) return name;
    }
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

// ═══════════════════════════════════════════════════════════════
// LOGS / AUDIT
// ═══════════════════════════════════════════════════════════════
private void LogRestoreAction(SqlConnection conn, string databaseName, string filePath)
{
    try
    {
        string sql = @"INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
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
    catch { /* table absente ou erreur → ignore */ }
}

private void LogRestoreSuccess(string databaseName, string filePath)
{
    try
    {
        string logFile = Server.MapPath("~/App_Data/restore_log.txt");
        File.AppendAllText(logFile,
            "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] " +
            "SUCCESS USER=" + AuthHelper.GetUserId(Context) + " " +
            "DB=" + databaseName + " " +
            "FILE=" + filePath + " " +
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
            "⚠️ RESTORE_VIOLATION USER=" + AuthHelper.GetUserId(Context) + " " +
            "DETAILS=" + details + " IP=" + Request.UserHostAddress + Environment.NewLine);
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

// ═══════════════════════════════════════════════════════════════
// CLASSE INTERNE
// ═══════════════════════════════════════════════════════════════
private class RestoreResult
{
    public bool Success { get; set; }
    public string ErrorMessage { get; set; }
}
</script>
