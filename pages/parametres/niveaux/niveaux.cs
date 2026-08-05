// niveaux.cs
using System;
using System.Web.UI;

public partial class niveaux : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        AuthHelper.VerifySession(this);

        if (!IsPostBack)
        {
            // ✅ FORCER un nouveau token à chaque chargement
            string token = Guid.NewGuid().ToString("N");
            Session["CSRF_TOKEN"] = token;
            ViewState["CSRF_TOKEN"] = token;

            // ✅ Cookie avec expiration 30 min
            var cookie = new System.Web.HttpCookie("CSRF_TOKEN");
            cookie.Value = token;
            cookie.HttpOnly = false;
            cookie.Secure = false;
            cookie.SameSite = System.Web.SameSiteMode.Lax;
            cookie.Expires = DateTime.Now.AddMinutes(30);
            Response.Cookies.Add(cookie);
        }
    }

    public string GetCsrfToken()
    {
        string token = Session["CSRF_TOKEN"] as string;
        if (string.IsNullOrEmpty(token))
        {
            token = Guid.NewGuid().ToString("N");
            Session["CSRF_TOKEN"] = token;
        }
        return token;
    }
}