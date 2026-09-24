using System;
using System.IO;
using System.Web;

public class AuthModule : IHttpModule
{
    // ════════════════════════════════════════════════════════════════
    // Chemins PUBLICS : accessibles sans session authentifiée.
    // ⚠️ Comparaison en minuscules, avec les DEUX formes :
    //    - "xxx.aspx"  → requête directe
    //    - "xxx"       → après la règle RedirectToCleanURL (301/302)
    // ════════════════════════════════════════════════════════════════
    private static readonly string[] PublicPathFragments = new[]
    {
        "/auth/login",                    // /auth/Login.aspx   + /auth/Login
        "/auth/logout",                   // /auth/Logout.aspx  + /auth/Logout
        "/pages/accueil/establishsession" // /pages/accueil/EstablishSession.aspx + version sans extension
    };

    // ════════════════════════════════════════════════════════════════
    // Extensions / dossiers de ressources STATIQUES : on laisse passer
    // sans aucun contrôle (le module ne doit JAMAIS toucher à ça).
    // ════════════════════════════════════════════════════════════════
    private static readonly string[] StaticExtensions = new[]
    {
        ".css", ".js", ".map",
        ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico",
        ".woff", ".woff2", ".ttf", ".eot", ".otf",
        ".mp4", ".webm", ".pdf"
    };

    private static readonly string[] StaticFolders = new[]
    {
        "/_assets/", "/plugins/", "/dist/", "/content/",
        "/img/", "/images/", "/fonts/", "/css/", "/js/"
    };

    public void Init(HttpApplication context)
    {
        context.AcquireRequestState += OnAcquireRequestState;
    }

    private void OnAcquireRequestState(object sender, EventArgs e)
    {
        try
        {
            HttpApplication app = (HttpApplication)sender;
            HttpContext ctx = app.Context;

            // Rien à faire sur les requêtes non-GET/HEAD qui ne sont pas .ashx
            // (postbacks ASP.NET, uploads, etc. passent par la page elle-même,
            //  c'est la page qui gère ses propres contrôles).

            string path = (ctx.Request.Path ?? "").ToLowerInvariant();

            // ────────────────────────────────────────────────────────
            // 1) Ressources statiques → laisser passer
            // ────────────────────────────────────────────────────────
            if (IsStaticResource(path))
                return;

            // ────────────────────────────────────────────────────────
            // 2) Pages publiques (Login / Logout / EstablishSession)
            //    → laisser passer sans contrôle d'authentification
            // ────────────────────────────────────────────────────────
            if (IsPublicPath(path))
                return;

            // ────────────────────────────────────────────────────────
            // 3) Handlers .ashx → vérification session + token
            //    (les rôles sont contrôlés dans chaque handler)
            // ────────────────────────────────────────────────────────
            if (path.EndsWith(".ashx"))
            {
                if (!AuthHelper.RequireApiAuth(ctx, -1))
                {
                    WriteJsonUnauthorized(ctx, "Non authentifié");
                }
                return;
            }

            // ────────────────────────────────────────────────────────
            // 4) Toutes les autres pages → authentification requise
            //    Redirection NON abortive : évite ThreadAbortException
            //    et le bruit dans App_Data/authmodule_error.log.
            // ────────────────────────────────────────────────────────
            if (!AuthHelper.IsAuthenticated(ctx))
            {
                RedirectToLogin(ctx);
            }
        }
        catch (Exception ex)
        {
            LogError(ex);
        }
    }

    // ════════════════════════════════════════════════════════════════
    // Helpers
    // ════════════════════════════════════════════════════════════════

    private static bool IsStaticResource(string path)
    {
        if (string.IsNullOrEmpty(path)) return false;

        // Extensions statiques
        foreach (var ext in StaticExtensions)
        {
            if (path.EndsWith(ext))
                return true;
        }

        // Dossiers statiques
        foreach (var folder in StaticFolders)
        {
            if (path.Contains(folder))
                return true;
        }

        // favicon
        if (path.EndsWith("/favicon.ico") || path == "/favicon.ico")
            return true;

        return false;
    }

    private static bool IsPublicPath(string path)
    {
        if (string.IsNullOrEmpty(path)) return false;

        foreach (var fragment in PublicPathFragments)
        {
            if (path.StartsWith(fragment))
                return true;
        }
        return false;
    }

    /// <summary>
    /// Redirige vers la page de connexion SANS interrompre brutalement la
    /// requête (pas de ThreadAbortException), et en ajoutant ?msg=session_expired
    /// pour que Login.aspx affiche un message à l'utilisateur.
    /// </summary>
    private static void RedirectToLogin(HttpContext ctx)
    {
        if (ctx.Response.IsRequestBeingRedirected) return; // sécurité anti-double redirect

        string target = VirtualPathUtility.ToAbsolute("~/auth/Login.aspx")
                        + "?msg=session_expired";

        ctx.Response.Redirect(target, false);
        ctx.ApplicationInstance.CompleteRequest();
    }

    private static void WriteJsonUnauthorized(HttpContext ctx, string message)
    {
        if (ctx.Response.IsRequestBeingRedirected) return;

        ctx.Response.StatusCode = 401;
        ctx.Response.ContentType = "application/json; charset=utf-8";
        ctx.Response.Write("{\"success\":false,\"message\":\"" + message + "\"}");
        ctx.ApplicationInstance.CompleteRequest();
    }

    private static void LogError(Exception ex)
    {
        // On ignore les ThreadAbortException (bruit classique d'ASP.NET,
        // plus censées arriver avec la redirection non abortive, mais on
        // garde le filtre par sécurité).
        if (ex is System.Threading.ThreadAbortException)
            return;

        try
        {
            string logFile = HttpContext.Current.Server.MapPath("~/App_Data/authmodule_error.log");
            string dir = Path.GetDirectoryName(logFile);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            File.AppendAllText(
                logFile,
                string.Format("[{0:yyyy-MM-dd HH:mm:ss}] {1}\n{2}\n---\n",
                              DateTime.Now, ex.Message, ex.StackTrace));
        }
        catch { /* le log ne doit JAMAIS casser la requête */ }
    }

    public void Dispose() { }
}
