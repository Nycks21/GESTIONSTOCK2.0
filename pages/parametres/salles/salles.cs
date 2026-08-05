// salles.cs
using System;
using System.Web.UI;

public partial class salles : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        AuthHelper.VerifySession(this);

        if (!IsPostBack)
        {
            GenerateCsrfToken();
        }
    }

    private void GenerateCsrfToken()
    {
        try
        {
            string token = Guid.NewGuid().ToString("N") + "_" + DateTime.Now.Ticks.ToString();
            Session["CSRF_TOKEN"] = token;
            ViewState["CSRF_TOKEN"] = token;

            var cookie = new System.Web.HttpCookie("CSRF_TOKEN");
            cookie.Value = token;
            cookie.HttpOnly = false;
            cookie.Secure = false;
            cookie.SameSite = System.Web.SameSiteMode.Lax;
            cookie.Expires = DateTime.Now.AddMinutes(30);
            Response.Cookies.Add(cookie);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine("Erreur CSRF: " + ex.Message);
        }
    }

    public string GetCsrfToken()
    {
        string token = Session["CSRF_TOKEN"] as string;
        if (string.IsNullOrEmpty(token))
        {
            token = Guid.NewGuid().ToString("N") + "_" + DateTime.Now.Ticks.ToString();
            Session["CSRF_TOKEN"] = token;
        }
        return token;
    }
}