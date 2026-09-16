using System;
using System.Web;
using System.Web.UI;

/// <summary>
/// Page dédiée au changement de mot de passe de l'utilisateur connecté.
/// - Vérifie la session via AuthHelper.VerifySession (mécanisme existant).
/// - Expose au JS les URLs absolues (handler pwdUpdate.ashx + page d'accueil).
/// Aucun mot de passe n'est traité ici : tout passe par le handler (SQL paramétré).
/// </summary>
public partial class resetpwd : Page
{
    /// <summary>URL absolue du handler de mise à jour du mot de passe.</summary>
    public string PwdHandlerUrl { get; private set; }

    /// <summary>URL absolue de la page d'accueil (redirection après action).</summary>
    public string HomeUrl { get; private set; }

    protected void Page_Load(object sender, EventArgs e)
    {
        // 1) Contrôle d'authentification : redirige vers Login.aspx si non connecté
        //    ou force la déconnexion si le SESSION_TOKEN en base ne correspond plus.
        AuthHelper.VerifySession(this);

        // 2) Expose au JS les URLs absolues (indépendantes du dossier courant).
        //    Le handler reste à son emplacement actuel : utilisateur/handlers/pwdUpdate.ashx
        PwdHandlerUrl = VirtualPathUtility.ToAbsolute(
            "~/pages/administrations/reset/api/pwdUpdate");

        // 3) Page de redirection après succès ou annulation
        HomeUrl = VirtualPathUtility.ToAbsolute("~/pages/accueil/index.aspx");
    }
}
