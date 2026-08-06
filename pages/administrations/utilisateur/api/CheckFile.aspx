<%@ Page Language="C#" EnableSessionState="True" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.Clear();
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);
    Response.Cache.SetNoStore();

    if (!AuthHelper.RequireApiAuth(Context, 0))
    {
        Response.StatusCode = 401;
        Response.Write("{\"exists\":false,\"message\":\"Accès non autorisé\"}");
        return;
    }

    try
    {
        string path = Request.QueryString["path"];

        if (string.IsNullOrEmpty(path))
        {
            Response.Write("{\"exists\":false,\"message\":\"Chemin manquant\"}");
            return;
        }

        string allowedRoot = Path.GetFullPath(Server.MapPath("~/App_Data/Backups"));
        string fullPath = Path.GetFullPath(path.Replace('/', Path.DirectorySeparatorChar));

        if (!fullPath.StartsWith(allowedRoot, StringComparison.OrdinalIgnoreCase))
        {
            Response.StatusCode = 403;
            Response.Write("{\"exists\":false,\"message\":\"Chemin non autorisé\"}");
            return;
        }

        if (!fullPath.EndsWith(".bak", StringComparison.OrdinalIgnoreCase))
        {
            Response.StatusCode = 403;
            Response.Write("{\"exists\":false,\"message\":\"Type de fichier non autorisé\"}");
            return;
        }

        bool exists = File.Exists(fullPath);
        var serializer = new JavaScriptSerializer();
        Response.Write(serializer.Serialize(new
        {
            exists = exists,
            path = fullPath.Replace("\\", "/")
        }));
    }
    catch (Exception ex)
    {
        string safeMessage = ex.Message.Replace("\"", "'").Replace("\r", " ").Replace("\n", " ").Replace("\t", " ");
        Response.Write("{\"exists\":false,\"message\":\"" + safeMessage + "\"}");
    }
}
</script>
