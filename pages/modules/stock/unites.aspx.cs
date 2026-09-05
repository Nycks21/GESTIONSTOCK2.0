using System;
using System.Web.UI;

public partial class unites : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        AuthHelper.VerifySession(this);
    }
}
