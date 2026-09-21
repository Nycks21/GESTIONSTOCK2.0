<%@ Page Language="C#" ContentType="application/json" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);
    Response.Cache.SetNoStore();

    try
    {
        if (Session["authenticated"] == null || !(bool)Session["authenticated"])
        {
            WriteJson(new { success = false, message = "Non authentifié" });
            return;
        }

        int currentUserId = Session["IDUSER"]   != null ? Convert.ToInt32(Session["IDUSER"])   : 0;
        int currentRole   = Session["USERROLE"] != null ? Convert.ToInt32(Session["USERROLE"]) : -1;

        if (currentRole != 0)
        {
            WriteJson(new { success = false, message = "Seul un SuperAdmin peut bloquer les connexions" });
            return;
        }

        // --- Lecture défensive du body ---
        int duration = 1;
        string body = new System.IO.StreamReader(Request.InputStream).ReadToEnd();

        if (!string.IsNullOrEmpty(body))
        {
            try
            {
                var serializer = new JavaScriptSerializer();
                var data = serializer.Deserialize<Dictionary<string, object>>(body);
                if (data != null && data.ContainsKey("duration") && data["duration"] != null)
                {
                    duration = Convert.ToInt32(data["duration"]);
                }
            }
            catch (Exception parseEx)
            {
                System.Diagnostics.Debug.WriteLine("BlockConnections: parsing body échoué - " + parseEx.Message);
            }
        }

        if (duration < 1)    duration = 1;
        if (duration > 1440) duration = 1440;

        DateTime blockUntil = DateTime.Now.AddMinutes(duration);
        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            string checkColumn = @"
                IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                               WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'BLOCKED_UNTIL')
                BEGIN
                    ALTER TABLE USERS ADD BLOCKED_UNTIL DATETIME NULL
                END";
            using (SqlCommand checkCmd = new SqlCommand(checkColumn, conn))
            {
                checkCmd.ExecuteNonQuery();
            }

            string sql = @"
                UPDATE USERS
                SET BLOCKED_UNTIL = @BlockUntil
                WHERE IDUSER != @CurrentUserId AND ROLEID != 0";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@BlockUntil", blockUntil);
                cmd.Parameters.AddWithValue("@CurrentUserId", currentUserId);
                int affected = cmd.ExecuteNonQuery();

                WriteJson(new
                {
                    success = true,
                    message = affected + " utilisateur(s) bloqué(s) pour " + duration + " minute(s)",
                    count   = affected
                });
            }
        }
    }
    catch (Exception ex)
    {
        WriteJson(new { success = false, message = ex.Message });
    }
}

private void WriteJson(object obj)
{
    var serializer = new JavaScriptSerializer();
    serializer.MaxJsonLength = int.MaxValue;
    Response.Write(serializer.Serialize(obj));
}
</script>
