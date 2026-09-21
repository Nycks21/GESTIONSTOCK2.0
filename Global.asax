<%@ Application Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.IO" %>

<script runat="server">

    // ============================================================
    // ACQUIRE REQUEST STATE : langue (Session disponible)
    // ============================================================
    protected void Application_AcquireRequestState(object sender, EventArgs e)
    {
        try
        {
            LocalizationHelper.HandleLanguage();
        }
        catch (Exception ex)
        {
            // Ne JAMAIS laisser remonter : une exception ici casse toutes les requêtes
            System.Diagnostics.Debug.WriteLine("HandleLanguage: " + ex.Message);
        }
    }

    // ============================================================
    // BEGIN REQUEST : headers, cache, mixed-content
    // ============================================================
    protected void Application_BeginRequest(object sender, EventArgs e)
    {
        HttpContext ctx = HttpContext.Current;
        if (ctx == null) return;

        string path = ctx.Request.Path ?? "";

        // Mixed content derrière ngrok / proxy HTTPS
        string forwardedProto = ctx.Request.Headers["X-Forwarded-Proto"];
        if (!string.IsNullOrEmpty(forwardedProto) &&
            forwardedProto.Equals("https", StringComparison.OrdinalIgnoreCase) &&
            !ctx.Request.IsSecureConnection)
        {
            ctx.Request.ServerVariables.Set("HTTPS", "on");
            ctx.Request.ServerVariables.Set("SERVER_PORT_SECURE", "1");
        }

        string lower = path.ToLower();
        if (lower.EndsWith(".css") || lower.EndsWith(".js") || lower.EndsWith(".png") ||
            lower.EndsWith(".jpg") || lower.EndsWith(".jpeg") || lower.EndsWith(".gif") ||
            lower.EndsWith(".woff") || lower.EndsWith(".woff2") || lower.EndsWith(".ttf") ||
            lower.Contains("/plugins/") || lower.Contains("/dist/") ||
            lower.Contains("/content/") || lower.Contains("/_assets/"))
        {
            return;
        }

        ctx.Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
        ctx.Response.Cache.SetNoStore();
        ctx.Response.Cache.SetExpires(DateTime.UtcNow.AddYears(-1));
        ctx.Response.AppendHeader("Pragma", "no-cache");
        ctx.Response.AppendHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        ctx.Response.AppendHeader("Expires", "0");

        if (ctx.Request.IsSecureConnection)
        {
            ctx.Response.AppendHeader("Content-Security-Policy", "upgrade-insecure-requests");
        }
    }

    // ============================================================
    // START
    // ============================================================
    protected void Application_Start(object sender, EventArgs e)
    {
        var serializer = new JavaScriptSerializer();
        serializer.MaxJsonLength = int.MaxValue;
    }

    // ============================================================
    // ERROR : log + JSON pour les endpoints API
    // ============================================================
    protected void Application_Error(object sender, EventArgs e)
    {
        Exception ex = Server.GetLastError();
        if (ex == null) return;

        HttpContext ctx = HttpContext.Current;
        if (ctx == null) return;

        string path  = (ctx.Request.Path ?? "");
        string lower = path.ToLower();

        // --- 1) Toujours logguer l'erreur réelle AVANT toute transformation ---
        try
        {
            string logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                                          "App_Data", "error_log.txt");
            Directory.CreateDirectory(Path.GetDirectoryName(logPath));
            string entry = string.Format(
                "[{0}] PATH={1}{2}{3}{2}{2}",
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                path,
                Environment.NewLine,
                ex.ToString());
            File.AppendAllText(logPath, entry);
        }
        catch { /* le log ne doit jamais casser le pipeline */ }

        // --- 2) Uniquement transformer en JSON les endpoints API ---
        bool isApi =
               lower.EndsWith(".ashx")
            || lower.EndsWith("backupdatabase.aspx")
            || lower.EndsWith("blockusers.aspx")
            || lower.EndsWith("blockconnections.aspx")
            || lower.EndsWith("checkfile.aspx")
            || lower.EndsWith("checkmaintenance.aspx");

        if (!isApi) return;

        Server.ClearError();
        ctx.Response.Clear();
        ctx.Response.StatusCode = 500;
        ctx.Response.ContentType = "application/json";
        ctx.Response.ContentEncoding = System.Text.Encoding.UTF8;

        string msg;
        if (ex is HttpCompileException || ex is HttpParseException)
            msg = "Erreur de compilation serveur: " + ex.Message;
        else
            msg = ex.Message;

        var serializer = new JavaScriptSerializer();
        serializer.MaxJsonLength = int.MaxValue;
        ctx.Response.Write(serializer.Serialize(new
        {
            success = false,
            message = msg,
            type    = ex.GetType().Name
        }));
        ctx.Response.End();
    }

</script>
