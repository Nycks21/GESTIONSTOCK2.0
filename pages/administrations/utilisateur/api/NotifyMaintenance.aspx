<%@ Page Language="C#" ContentType="application/json" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);

    try
    {
        // ✅ AUTH + CSRF + rôle Admin (1)
        if (!AuthHelper.RequireCsrfSafePost(Context, 1))
        {
            Response.StatusCode = 403;
            Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        // Lire le corps de la requête
        string body = new System.IO.StreamReader(Request.InputStream).ReadToEnd();
        var serializer = new JavaScriptSerializer();
        var data = serializer.Deserialize<Dictionary<string, object>>(body);

        string message = data.ContainsKey("message") ? data["message"].ToString() : "⚠️ Maintenance programmée";
        string maintenanceTime = data.ContainsKey("maintenanceTime") ? data["maintenanceTime"].ToString() : DateTime.Now.AddMinutes(5).ToString("HH:mm");

        // Stocker la notification dans Application (visible par tous)
        Application.Lock();
        Application["MaintenanceMessage"] = message;
        Application["MaintenanceTime"] = maintenanceTime;
        Application["MaintenanceActive"] = true;
        Application["MaintenanceStartTime"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        Application.UnLock();

        // Compter les utilisateurs actifs
        int activeUsersCount = 0;
        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();
            string sql = "SELECT COUNT(*) FROM USERS WHERE SESSION_TOKEN IS NOT NULL";
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                activeUsersCount = (int)cmd.ExecuteScalar();
            }
        }

        Response.Write("{\"success\":true,\"message\":\"Notification envoyée à " + activeUsersCount + " utilisateur(s) actif(s)\", \"activeUsers\":" + activeUsersCount + "}");
    }
    catch (Exception ex)
    {
        Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "'") + "\"}");
    }
}
</script>
