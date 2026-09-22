<%@ Page Language="C#" AutoEventWireup="true" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Collections.Generic" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = System.Text.Encoding.UTF8;
    Response.Clear();
    Response.AddHeader("Cache-Control", "no-cache, no-store");
    Response.Cache.SetNoStore();

    try
    {
        // ✅ Vérification d'authentification : Admin ou SuperAdmin
        if (!AuthHelper.RequireApiAuth(Context, 1))
        {
            Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            // ✅ Filtres stricts :
            //    - DELETION_AT IS NULL  → jamais supprimé logiquement
            //    - DELETION_BY IS NULL  → aucune trace de suppression
            //    - ROLEID != 99         → exclure les comptes techniques/masqués
            // ✅ Ne pas exposer les mots de passe
            string query = @"
                SELECT IDUSER, USERNAME, NOM,
                       ISNULL(EMAIL, '') AS EMAIL,
                       ISNULL(TELEPHONE, '') AS TELEPHONE,
                       ROLEID, CREATED_AT,
                       CAST(ISNULL(ACTIVE, 0) AS BIT) AS ACTIVE
                FROM USERS
                WHERE DELETION_AT IS NULL
                  AND DELETION_BY IS NULL
                  AND ROLEID != 99
                ORDER BY NOM ASC";

            using (SqlCommand cmd = new SqlCommand(query, conn))
            using (SqlDataReader reader = cmd.ExecuteReader())
            {
                var users = new List<Dictionary<string, object>>();
                var serializer = new JavaScriptSerializer();

                while (reader.Read())
                {
                    var user = new Dictionary<string, object>();
                    user["IDUSER"]     = reader["IDUSER"];
                    user["USERNAME"]   = reader["USERNAME"];
                    user["NOM"]        = reader["NOM"];
                    user["EMAIL"]      = reader["EMAIL"];
                    user["TELEPHONE"]  = reader["TELEPHONE"];
                    user["ROLEID"]     = reader["ROLEID"];
                    user["CREATED_AT"] = Convert.ToDateTime(reader["CREATED_AT"]);
                    user["ACTIVE"]     = reader["ACTIVE"];

                    users.Add(user);
                }

                Response.Write(serializer.Serialize(users));
            }
        }
    }
    catch (Exception ex)
    {
        // ✅ Log sans exposer les détails
        Response.Write("{\"success\":false,\"error\":\"Erreur lors de la récupération des utilisateurs\"}");
    }
    finally
    {
        Response.End();
    }
}
</script>
