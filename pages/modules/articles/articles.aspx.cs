using System;
using System.Web.UI;

public partial class articles : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        AuthHelper.VerifySession(this);
    }
}
