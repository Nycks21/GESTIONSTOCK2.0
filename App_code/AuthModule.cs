using System;
using System.Web;

public class AuthModule : IHttpModule
{
    public void Init(HttpApplication context)
    {
        context.AcquireRequestState += new EventHandler(OnAcquireRequestState);
    }

    private void OnAcquireRequestState(object sender, EventArgs e)
    {
        try
        {
            HttpApplication app = (HttpApplication)sender;
            HttpContext ctx = app.Context;

            string path = ctx.Request.Path.ToLower();

            // Exclure les fichiers statiques
            if (path.EndsWith(".css") || path.EndsWith(".js") || path.EndsWith(".png") ||
                path.EndsWith(".jpg") || path.EndsWith(".jpeg") || path.EndsWith(".gif") ||
                path.EndsWith(".woff") || path.EndsWith(".woff2") || path.EndsWith(".ttf") ||
                path.Contains("/plugins/") || path.Contains("/dist/") || path.Contains("/content/") ||
                path.Contains("/_assets/") || path.Contains("/favicon.ico"))
            {
                return;
            }

            // Pages d'authentification
            if (path.EndsWith("login.aspx") || path.EndsWith("logout.aspx"))
            {
                return;
            }

            // Handlers API : session + token obligatoires (rôles vérifiés dans chaque handler)
            if (path.EndsWith(".ashx"))
            {
                if (!AuthHelper.RequireApiAuth(ctx, -1))
                {
                    ctx.Response.StatusCode = 401;
                    ctx.Response.ContentType = "application/json; charset=utf-8";
                    ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                    ctx.Response.End();
                }
                return;
            }

            // ✅ Vérifier l'authentification
            if (!AuthHelper.IsAuthenticated(ctx))
            {
                // ✅ Redirection correcte vers /auth/Login.aspx
                ctx.Response.Redirect("~/auth/Login.aspx", true);
            }
        }
        catch (Exception ex)
        {
            // Log pour diagnostic
            try
            {
                string logFile = HttpContext.Current.Server.MapPath("~/App_Data/authmodule_error.log");
                System.IO.File.AppendAllText(logFile,
                    string.Format("[{0}] Erreur AuthModule: {1}\n{2}\n---\n",
                    DateTime.Now, ex.Message, ex.StackTrace));
            }
            catch { }
        }
    }

    public void Dispose() { }
}