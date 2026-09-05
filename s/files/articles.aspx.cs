using System;

namespace GestionStock.Pages
{
    public partial class ArticlesPage : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            // Meme garde que sur les pages de MONAPPECOLE2 : redirection si non connecte
            if (Session["IDUser"] == null)
            {
                Response.Redirect("~/login.aspx");
                return;
            }

            // Optionnel : restreindre l'acces selon le role (ex. Logisticien / Admin / SuperAdmin)
            // int roleId = Convert.ToInt32(Session["RoleId"]);
            // if (roleId != 0 && roleId != 1 && roleId != 3)
            // {
            //     Response.Redirect("~/acces-refuse.aspx");
            // }
        }
    }
}
