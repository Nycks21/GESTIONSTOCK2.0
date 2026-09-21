<%@ Page Language="C#" ContentType="application/json" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data.SqlClient" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);

    try
    {
        // ✅ AUTH + CSRF + rôle SuperAdmin
        if (!AuthHelper.RequireCsrfSafePost(Context, 0))
        {
            Response.StatusCode = 403;
            Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        int currentUserId = AuthHelper.GetUserId(Context);
        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            string sql = @"
                UPDATE USERS
                SET SESSION_TOKEN = NULL,
                    LAST_PC = NULL,
                    LAST_LOGIN = DATEADD(MINUTE, -5, GETDATE())
                WHERE IDUSER != @CurrentUserId
                AND ROLEID != 0";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@CurrentUserId", currentUserId);
                int affected = cmd.ExecuteNonQuery();

                Response.Write("{\"success\":true,\"message\":\"" + affected + " utilisateur(s) déconnecté(s)\", \"count\":" + affected + "}");
            }
        }
    }
    catch (Exception ex)
    {
        Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "'") + "\"}");
    }
}
</script>
