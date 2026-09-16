<%@ Page Language="C#" ResponseEncoding="utf-8" EnableSessionState="True" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Text" %>

<script runat="server">
private string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
private const int MIN_PWD_LENGTH = 8;
private const int MAX_PWD_LENGTH = 128;

protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = new UTF8Encoding(false);
    Response.Clear();
    Response.Cache.SetNoStore();

    try
    {
        // ---- 1) AUTHENTIFICATION ----
        if (!AuthHelper.RequireApiAuth(Context, -1))
        {
            WriteResponse(false, "Session expirée. Veuillez vous reconnecter.");
            return;
        }
        if (Request.HttpMethod == "OPTIONS") { Response.StatusCode = 200; Response.End(); return; }
        if (Request.HttpMethod != "POST")
        {
            WriteResponse(false, "Méthode non autorisée");
            return;
        }

        // ---- 2) UTILISATEUR CONNECTÉ ----
        int userId = AuthHelper.GetUserId(Context);
        if (userId <= 0)
        {
            WriteResponse(false, "Utilisateur non identifié.");
            return;
        }

        // ---- 3) PARAMÈTRES ----
        string oldPwd     = (Request.Form["oldPwd"]     ?? Request["oldPwd"]     ?? "").Trim();
        string newPwd     = (Request.Form["newPwd"]     ?? Request["newPwd"]     ?? "").Trim();
        string confirmPwd = (Request.Form["confirmPwd"] ?? Request["confirmPwd"] ?? "").Trim();

        // ---- 4) VALIDATIONS ----
        if (string.IsNullOrEmpty(oldPwd) || string.IsNullOrEmpty(newPwd) || string.IsNullOrEmpty(confirmPwd))
        { WriteResponse(false, "Tous les champs sont obligatoires."); return; }
        if (newPwd.Length < MIN_PWD_LENGTH)
        { WriteResponse(false, "Le nouveau mot de passe doit contenir au moins " + MIN_PWD_LENGTH + " caractères."); return; }
        if (newPwd.Length > MAX_PWD_LENGTH || oldPwd.Length > MAX_PWD_LENGTH)
        { WriteResponse(false, "Mot de passe trop long (max " + MAX_PWD_LENGTH + " caractères)."); return; }
        if (!string.Equals(newPwd, confirmPwd, StringComparison.Ordinal))
        { WriteResponse(false, "Le nouveau mot de passe et sa confirmation ne correspondent pas."); return; }
        if (string.Equals(oldPwd, newPwd, StringComparison.Ordinal))
        { WriteResponse(false, "Le nouveau mot de passe doit être différent de l'ancien."); return; }

        // ---- 5) TRAITEMENT SQL ----
        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            // 5.1) Récupérer le hash stocké
            string storedPwd;
            using (SqlCommand cmd = new SqlCommand(
                "SELECT PWD FROM USERS WHERE IDUSER = @id AND DELETION_AT IS NULL", conn))
            {
                cmd.Parameters.AddWithValue("@id", userId);
                object o = cmd.ExecuteScalar();
                if (o == null || o == DBNull.Value)
                { WriteResponse(false, "Utilisateur introuvable."); return; }
                storedPwd = o.ToString();
            }

            // 5.2) Vérifier l'ancien mot de passe
            //      ✅ On délègue à PasswordHelper (même logique que Login.aspx).
            //      ⚠️ Ordre : (storedHash, password, out needsRehash)
            bool needsRehash;
            bool pwdOk = PasswordHelper.VerifyPassword(storedPwd, oldPwd, out needsRehash);

            if (!pwdOk)
            { WriteResponse(false, "L'ancien mot de passe est incorrect."); return; }

            // 5.3) Mettre à jour avec un hash PBKDF2 neuf (aligné sur PasswordHelper)
            string newHash = PasswordHelper.HashPassword(newPwd);
            using (SqlCommand cmd = new SqlCommand(
                "UPDATE USERS SET PWD = @pwd, UPDATED_AT = GETDATE(), UPDATED_BY = @by WHERE IDUSER = @id", conn))
            {
                cmd.Parameters.AddWithValue("@pwd", newHash);
                cmd.Parameters.AddWithValue("@by",  userId);
                cmd.Parameters.AddWithValue("@id",  userId);
                if (cmd.ExecuteNonQuery() <= 0)
                { WriteResponse(false, "Aucune ligne mise à jour."); return; }
            }
        }

        WriteResponse(true, "Mot de passe mis à jour avec succès.");
    }
    catch (SqlException)
    { WriteResponse(false, "Erreur base de données. Veuillez réessayer."); }
    catch (Exception)
    { WriteResponse(false, "Une erreur est survenue lors du traitement."); }
}

private void WriteResponse(bool success, string message)
{
    var serializer = new JavaScriptSerializer();
    var response = new Dictionary<string, object>();
    response["success"] = success;
    response["message"] = message;
    Response.Write(serializer.Serialize(response));
}
</script>
