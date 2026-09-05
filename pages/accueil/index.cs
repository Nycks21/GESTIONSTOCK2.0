using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.UI;

public partial class index : Page
{
    // ============================
    // PAGE_LOAD
    // ============================
    protected void Page_Load(object sender, EventArgs e)
    {
        // Cet appel unique exécute TOUTE la logique contenue dans le helper
        AuthHelper.VerifySession(this);
        
        // Multi language
        LocalizationHelper.HandleLanguage();

        // Initialiser le rôle utilisateur

        string action = Request.QueryString["action"];
        if (!string.IsNullOrEmpty(action))
        {
            Response.Clear();
            Response.ContentType = "application/json";

            switch (action)
            {
                case "kpi":
                    Response.Write("{\"totalEleves\":150,\"nouveauxRentree\":5,\"totalClasses\":12,\"tauxPresence\":95,\"fraisImpayes\":1200000,\"moyEleves\":25,\"variationPresence\":2,\"variationImpayes\":1000000,\"garcons\":80,\"filles\":70}");
                    break;
                case "presences":
                    Response.Write("{\"labels\":[\"Lun\",\"Mar\",\"Mer\"],\"presents\":[140,138,142],\"absents\":[10,12,8]}");
                    break;
                case "repartition":
                    Response.Write("{\"niveaux\":[\"6ème\",\"5ème\"],\"counts\":[40,35]}");
                    break;
                case "frais":
                    Response.Write("{\"labels\":[\"Jan\",\"Fév\"],\"payes\":[5000,6000],\"impayes\":[1000,500]}");
                    break;
                default:
                    Response.Write("[]"); // Renvoie un tableau vide par défaut au lieu de rien
                    break;
            }
            Response.End();
        }
    }
}