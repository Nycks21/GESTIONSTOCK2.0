<%@ Page Language="C#" ContentType="application/json" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = System.Text.Encoding.UTF8;
    Response.Cache.SetNoStore();
    Response.Cache.SetNoStore();

    if (!AuthHelper.RequireApiAuth(Context, 1))
    {
        Response.StatusCode = 401;
        Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
        return;
    }
    
    try
    {
        // Récupérer les infos depuis AuthHelper
        string maxUsersStr = AuthHelper.GetMaxUsersString();
        int maxUsers = int.Parse(maxUsersStr);
        
        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
        int currentUsers = 0;
        
        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();
            string query = "SELECT COUNT(*) FROM USERS WHERE ACTIVE = 1";
            using (SqlCommand cmd = new SqlCommand(query, conn))
            {
                currentUsers = (int)cmd.ExecuteScalar();
            }
        }
        
        var result = new { 
            success = true, 
            maxUsers = maxUsers, 
            currentUsers = currentUsers,
            canAdd = currentUsers < maxUsers
        };
        
        var serializer = new JavaScriptSerializer();
        Response.Write(serializer.Serialize(result));
    }
    catch (Exception ex)
    {
        var error = new { success = false, message = ex.Message };
        var serializer = new JavaScriptSerializer();
        Response.Write(serializer.Serialize(error));
    }
}
</script>