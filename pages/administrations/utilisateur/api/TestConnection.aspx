<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Configuration" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.Clear();
    Response.ContentType = "application/json";
    
    try
    {
        // ✅ Vérification d'authentification - SuperAdmin uniquement
        if (!AuthHelper.RequireApiAuth(Context, 0))
        {
            Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }
        
        // ✅ Utiliser la chaîne de connexion depuis Web.config
        string connectionString = ConfigurationManager.ConnectionStrings["MasterConnection"]?.ConnectionString;
        if (string.IsNullOrEmpty(connectionString))
        {
            Response.Write("{\"success\":false,\"message\":\"Erreur de configuration\"}");
            return;
        }
        
        using (SqlConnection conn = new SqlConnection(connectionString))
        {
            conn.Open();
            Response.Write("{\"success\":true,\"message\":\"Connexion réussie\"}");
        }
    }
    catch (Exception ex)
    {
        // ✅ Log sans exposer les détails
        LogError(ex);
        Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
    }
}

private void LogError(Exception ex)
{
    try
    {
        string logFile = Server.MapPath("~/App_Data/connection_errors.log");
        string entry = $"[{DateTime.Now}] {ex.Message}\n---\n";
        File.AppendAllText(logFile, entry);
    }
    catch { }
}
</script>