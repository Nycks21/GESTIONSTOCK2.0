using System;
using System.Web;
using System.Web.UI;

public partial class EstablishSession : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        string token = Request.QueryString["t"];

        if (string.IsNullOrEmpty(token))
        {
            Response.Redirect("~/auth/Login.aspx?msg=session_error", false);
            Context.ApplicationInstance.CompleteRequest();
            return;
        }

        var authData = AuthHelper.RetrievePendingAuth(token);

        if (authData == null)
        {
            Response.Redirect("~/auth/Login.aspx?msg=session_error", false);
            Context.ApplicationInstance.CompleteRequest();
            return;
        }

        // Régénérer une session propre (SessionId déjà renouvelé par ASP.NET
        // car on a abandonné la session précédente dans Login.aspx.cs)
        Session.Clear();

        foreach (var kvp in authData)
        {
            Session[kvp.Key] = kvp.Value;
        }

        Response.Redirect("~/pages/accueil/index.aspx", false);
        Context.ApplicationInstance.CompleteRequest();
    }
}
