using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.UI;

public partial class agenda : Page
{
    // ============================
    // PAGE_LOAD
    // ============================
    protected void Page_Load(object sender, EventArgs e)
    {
        // ✅ Définir la page active pour le menu
        HttpContext.Current.Items["CurrentPage"] = "agenda";
        
        // ✅ Vérification de session (redirige vers Login si non authentifié)
        AuthHelper.VerifySession(this);

        // ✅ Gestion du multi-langage (si disponible)
        try
        {
            LocalizationHelper.HandleLanguage();
        }
        catch { /* Ignorer si LocalizationHelper n'est pas disponible */ }

        // ✅ Vérifier que l'utilisateur a la permission "agenda"
        if (!AuthHelper.HasPermission("agenda"))
        {
            // Rediriger vers le dashboard si pas de permission
            Response.Redirect("~/pages/accueil/dashboards/index.aspx", true);
            return;
        }

        if (!IsPostBack)
        {
            // ✅ Initialisation des HiddenFields pour le JavaScript
            hfUserRole.Value = AuthHelper.GetUserRole(HttpContext.Current).ToString();
            hfUserName.Value = AuthHelper.GetUserName();
            hfProfesseurId.Value = AuthHelper.GetUserId(HttpContext.Current).ToString();

            // ✅ Classes et matières autorisées (pour les professeurs)
            string classesAutorisees = AuthHelper.GetClassesAutorisees();
            hfClassesAutorisees.Value = classesAutorisees;

            string matieresAutorisees = AuthHelper.GetMatieresAutorisees();
            hfMatieresAutorisees.Value = matieresAutorisees;
        }
    }
}