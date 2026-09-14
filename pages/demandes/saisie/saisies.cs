using System;

public partial class saisies : System.Web.UI.Page
{
  protected void Page_Load(object sender, EventArgs e)
  {
    AuthHelper.VerifySession(this);

    if (!IsPostBack)
    {
      // ✅ ROLEID (déjà présent si vous l'aviez ajouté)
      hfUserRole.Value = AuthHelper.GetUserRole(Context).ToString();

      // ✅ NOUVEAU : NOM complet de l'utilisateur connecté
      hfUserNom.Value = AuthHelper.GetUserFullName();
    }
  }
}
