<%@ Page Language="C#" AutoEventWireup="true" %>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        // ✅ Utilisation centralisée de AuthHelper.Logout
        AuthHelper.Logout(Context);

        // Redirection vers Login
        Response.Redirect("Login.aspx", true);
    }
</script>

<!DOCTYPE html>
<html>
<head runat="server">
    <title>Déconnexion...</title>
</head>
<body>
    <form id="form1" runat="server">
        <div>Déconnexion en cours...</div>
    </form>
</body>
</html>