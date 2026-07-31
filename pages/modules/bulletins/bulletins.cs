using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.UI;

public partial class bulletins : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        // Vérification de session
        AuthHelper.VerifySession(this);

        if (!IsPostBack)
        {
            // Récupérer les informations de l'utilisateur connecté
            int role = AuthHelper.GetUserRole(HttpContext.Current);
            hfUserRole.Value = role.ToString();
            hfUserName.Value = AuthHelper.GetUserName();
            hfProfesseurId.Value = AuthHelper.GetUserId(HttpContext.Current).ToString();

            // Récupérer les classes autorisées pour cet utilisateur
            string classesAutorisees = AuthHelper.GetClassesAutorisees();
            hfClassesAutorisees.Value = classesAutorisees;

            // Récupérer les matières autorisées pour cet utilisateur
            string matieresAutorisees = AuthHelper.GetMatieresAutorisees();
            hfMatieresAutorisees.Value = matieresAutorisees;
        }
    }
}