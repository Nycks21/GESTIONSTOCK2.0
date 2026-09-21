﻿<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Configuration" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = System.Text.Encoding.UTF8;
    Response.Clear();
    Response.Cache.SetNoStore();

    // Gestion OPTIONS (CORS preflight)
    if (Request.HttpMethod == "OPTIONS")
    {
        Response.StatusCode = 200;
        Response.End();
        return;
    }

    if (Request.HttpMethod != "POST")
    {
        Response.StatusCode = 405;
        WriteResponse("error", "Méthode non autorisée");
        return;
    }

    // ✅ AUTH + CSRF + rôle SuperAdmin
    if (!AuthHelper.RequireCsrfSafePost(Context, 0))
    {
        Response.StatusCode = 403;
        WriteResponse("error", "Accès non autorisé");
        return;
    }

    string id = Request.Form["id"];
    if (string.IsNullOrEmpty(id))
    {
        Response.StatusCode = 400;
        WriteResponse("error", "ID manquant");
        return;
    }

    int userId;
    if (!int.TryParse(id, out userId))
    {
        Response.StatusCode = 400;
        WriteResponse("error", "ID utilisateur invalide");
        return;
    }

    try
    {
        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            // Vérifier si l'utilisateur existe
            using (SqlCommand checkCmd = new SqlCommand("SELECT COUNT(*) FROM USERS WHERE IDUSER = @Id", conn))
            {
                checkCmd.Parameters.AddWithValue("@Id", userId);
                int exists = (int)checkCmd.ExecuteScalar();
                if (exists == 0)
                {
                    WriteResponse("error", "Aucun utilisateur trouvé avec cet ID");
                    return;
                }
            }

            using (SqlCommand cmd = new SqlCommand("DELETE FROM USERS WHERE IDUSER = @Id", conn))
            {
                cmd.Parameters.AddWithValue("@Id", userId);
                int rows = cmd.ExecuteNonQuery();

                if (rows > 0)
                    WriteResponse("success", "Utilisateur supprimé avec succès");
                else
                    WriteResponse("error", "Erreur lors de la suppression");
            }
        }
    }
    catch (Exception ex)
    {
        Response.StatusCode = 500;
        WriteResponse("error", ex.Message.Replace("\"", "'"));
    }
}

private void WriteResponse(string status, string message)
{
    string success = (status == "success") ? "true" : "false";
    string safeMessage = message.Replace("\"", "\\\"").Replace("\r", "").Replace("\n", "");
    string json = "{\"status\":\"" + status + "\",\"success\":" + success + ",\"message\":\"" + safeMessage + "\"}";
    Response.Write(json);
}
</script>
