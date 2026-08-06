<%@ Page Language="C#" %>
<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    if (!AuthHelper.IsAuthenticated(Context))
    {
        Response.Redirect("~/auth/Login.aspx", true);
        return;
    }
    Response.Redirect("~/pages/accueil/dashboards/index.aspx", true);
}
</script>
