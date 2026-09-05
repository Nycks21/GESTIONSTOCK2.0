using System;
using System.Globalization;
using System.Threading;
using System.Web;
using System.Web.UI;
using System.Web.SessionState;
using System.Text;
using System.Collections.Generic;

public static class LocalizationHelper
{
    // Langues supportées
    public static readonly string[] SupportedCultures = { "fr", "en", "mg" };

    // Noms des langues
    public static readonly string[] CultureNames = { "FR", "EN", "MG" };

    // Drapeaux d'usage général (fallback visuel)
    public static readonly string[] CultureFlags = { "🇫🇷", "EN", "🇲🇬" };

    // Chemins réels vers les fichiers de drapeaux dans /img
    public static readonly string[] CultureFlagPaths = {
        "/img/Flag_FR.svg",
        "/img/Flag_US.svg",
        "/img/Flag_MG.svg"
    };

    // Noms courts
    public static readonly string[] CultureShortNames = { "FR", "EN", "MG" };

    // Dictionnaire de traductions par défaut (fallback si les ressources .resx ne sont pas disponibles)
    private static readonly Dictionary<string, Dictionary<string, string>> DefaultTranslations = new Dictionary<string, Dictionary<string, string>>();

    static LocalizationHelper()
    {
        // Initialiser les traductions par défaut
        var fr = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "Dashboard", "Tableau de bord" },
            { "Students", "Élèves" },
            { "Absences", "Absences" },
            { "Grades", "Bulletins" },
            { "Agenda", "Agenda" },
            { "Schedule", "Emplois du temps" },
            { "Fees", "Frais" },
            { "Levels", "Niveaux" },
            { "Rooms", "Salles" },
            { "Classes", "Classes" },
            { "Subjects", "Matières" },
            { "ImportStudents", "Importation élèves" },
            { "SchoolYears", "Années scolaires" },
            { "Users", "Utilisateurs" },
            { "SQLQueries", "Requêtes SQL" },
            { "SuperAdmin", "Super Administrateur" },
            { "Admin", "Administrateur" },
            { "Teacher", "Professeur" },
            { "Secretary", "Secrétaire" },
            { "Accountant", "Comptable" },
            { "User", "Utilisateur" },
            { "Logout", "Déconnexion" },
            { "Notifications", "Notifications" },
            { "NewStudent", "Nouvel élève" },
            { "AbsenceReported", "Absence signalée" },
            { "PaymentReceived", "Paiement reçu" },
            { "TimeAgo", "Il y a" },
            { "DarkMode", "Mode sombre" },
            { "Fullscreen", "Plein écran" },
            { "Settings", "Paramètres" },
            { "CheckUpdates", "Vérifier les mises à jour" },
            { "Backup", "Sauvegarder" },
            { "Restore", "Restaurer" },
            { "LicenceExpires", "Licence expire le" },
            { "MaxUsers", "Utilisateurs max" },
            { "LicenceMissing", "Licence manquante" },
            { "LicenceInvalid", "Licence invalide" },
            { "NoData", "Aucune donnée" },
            { "ContactAdmin", "Contactez l'administrateur" },
            { "Accueil", "Accueil" },
            { "Modules", "Modules" },
            { "Ecolage", "Écolage" },
            { "Utilities", "Utilitaires" },
            { "Administration", "Administration" },
            { "Welcome", "Bienvenue" },
            { "Login", "Connexion" },
            { "Password", "Mot de passe" },
            { "RememberMe", "Se souvenir de moi" },
            { "ForgotPassword", "Mot de passe oublié" },
            { "Register", "S'inscrire" },
            { "Profile", "Profil" },
            { "TotalStudents", "Total élèves" },
            { "TotalClasses", "Total classes" },
            { "AverageStudents", "Moyenne élèves" },
            { "NewStudents", "Nouveaux élèves" },
            { "AttendanceRate", "Taux de présence" },
            { "UnpaidFees", "Frais impayés" },
            { "PaymentRate", "Taux de paiement" },
            { "SuccessRate", "Taux de réussite" },
            { "Boys", "Garçons" },
            { "Girls", "Filles" },
            { "Gender", "Genre" },
            { "Male", "Masculin" },
            { "Female", "Féminin" },
            { "StudentName", "Nom de l'élève" },
            { "Class", "Classe" },
            { "AbsencesCount", "Nombre d'absences" },
            { "RetardsCount", "Nombre de retards" },
            { "Status", "Statut" },
            { "Critical", "Critique" },
            { "Monitor", "Surveiller" },
            { "Normal", "Normal" },
            { "Export", "Exporter" },
            { "Import", "Importer" },
            { "Add", "Ajouter" },
            { "Edit", "Modifier" },
            { "Delete", "Supprimer" },
            { "Save", "Enregistrer" },
            { "Cancel", "Annuler" },
            { "Close", "Fermer" },
            { "Confirm", "Confirmer" },
            { "Yes", "Oui" },
            { "No", "Non" },
            { "Today", "Aujourd'hui" },
            { "Yesterday", "Hier" },
            { "Tomorrow", "Demain" },
            { "January", "Janvier" },
            { "February", "Février" },
            { "March", "Mars" },
            { "April", "Avril" },
            { "May", "Mai" },
            { "June", "Juin" },
            { "July", "Juillet" },
            { "August", "Août" },
            { "September", "Septembre" },
            { "October", "Octobre" },
            { "November", "Novembre" },
            { "December", "Décembre" }
        };

        var en = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "Dashboard", "Dashboard" },
            { "Students", "Students" },
            { "Absences", "Absences" },
            { "Grades", "Grades" },
            { "Agenda", "Agenda" },
            { "Schedule", "Schedule" },
            { "Fees", "Fees" },
            { "Levels", "Levels" },
            { "Rooms", "Rooms" },
            { "Classes", "Classes" },
            { "Subjects", "Subjects" },
            { "ImportStudents", "Import students" },
            { "SchoolYears", "School years" },
            { "Users", "Users" },
            { "SQLQueries", "SQL queries" },
            { "SuperAdmin", "Super Admin" },
            { "Admin", "Administrator" },
            { "Teacher", "Teacher" },
            { "Secretary", "Secretary" },
            { "Accountant", "Accountant" },
            { "User", "User" },
            { "Logout", "Logout" },
            { "Notifications", "Notifications" },
            { "NewStudent", "New student" },
            { "AbsenceReported", "Absence reported" },
            { "PaymentReceived", "Payment received" },
            { "TimeAgo", "ago" },
            { "DarkMode", "Dark mode" },
            { "Fullscreen", "Fullscreen" },
            { "Settings", "Settings" },
            { "CheckUpdates", "Check updates" },
            { "Backup", "Backup" },
            { "Restore", "Restore" },
            { "LicenceExpires", "Licence expires on" },
            { "MaxUsers", "Max users" },
            { "LicenceMissing", "Licence missing" },
            { "LicenceInvalid", "Invalid licence" },
            { "NoData", "No data" },
            { "ContactAdmin", "Contact the administrator" },
            { "Accueil", "Home" },
            { "Modules", "Modules" },
            { "Ecolage", "Tuition" },
            { "Utilities", "Utilities" },
            { "Administration", "Administration" },
            { "Welcome", "Welcome" },
            { "Login", "Login" },
            { "Password", "Password" },
            { "RememberMe", "Remember me" },
            { "ForgotPassword", "Forgot password" },
            { "Register", "Register" },
            { "Profile", "Profile" },
            { "TotalStudents", "Total students" },
            { "TotalClasses", "Total classes" },
            { "AverageStudents", "Average students" },
            { "NewStudents", "New students" },
            { "AttendanceRate", "Attendance rate" },
            { "UnpaidFees", "Unpaid fees" },
            { "PaymentRate", "Payment rate" },
            { "SuccessRate", "Success rate" },
            { "Boys", "Boys" },
            { "Girls", "Girls" },
            { "Gender", "Gender" },
            { "Male", "Male" },
            { "Female", "Female" },
            { "StudentName", "Student name" },
            { "Class", "Class" },
            { "AbsencesCount", "Absences count" },
            { "RetardsCount", "Lates count" },
            { "Status", "Status" },
            { "Critical", "Critical" },
            { "Monitor", "Monitor" },
            { "Normal", "Normal" },
            { "Export", "Export" },
            { "Import", "Import" },
            { "Add", "Add" },
            { "Edit", "Edit" },
            { "Delete", "Delete" },
            { "Save", "Save" },
            { "Cancel", "Cancel" },
            { "Close", "Close" },
            { "Confirm", "Confirm" },
            { "Yes", "Yes" },
            { "No", "No" },
            { "Today", "Today" },
            { "Yesterday", "Yesterday" },
            { "Tomorrow", "Tomorrow" },
            { "January", "January" },
            { "February", "February" },
            { "March", "March" },
            { "April", "April" },
            { "May", "May" },
            { "June", "June" },
            { "July", "July" },
            { "August", "August" },
            { "September", "September" },
            { "October", "October" },
            { "November", "November" },
            { "December", "December" }
        };

        var mg = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "Dashboard", "Takodidirana" },
            { "Students", "Mpianatra" },
            { "Absences", "Tsy fisiana" },
            { "Grades", "Naoty" },
            { "Agenda", "Agenda" },
            { "Schedule", "Fandaharam-potoana" },
            { "Fees", "Saram-pianarana" },
            { "Levels", "Ambaratonga" },
            { "Rooms", "Efitrano" },
            { "Classes", "Kilasy" },
            { "Subjects", "Taranja" },
            { "ImportStudents", "Ampidiro mpianatra" },
            { "SchoolYears", "Taom-pianarana" },
            { "Users", "Mpampiasa" },
            { "SQLQueries", "Fanontaniana SQL" },
            { "SuperAdmin", "Super Admin" },
            { "Admin", "Administrateur" },
            { "Teacher", "Mpampianatra" },
            { "Secretary", "Mpitandrina" },
            { "Accountant", "Kaonty" },
            { "User", "Mpampiasa" },
            { "Logout", "Mivoaha" },
            { "Notifications", "Fampandrenesana" },
            { "NewStudent", "Mpianatra vaovao" },
            { "AbsenceReported", "Tsy fisiana voalaza" },
            { "PaymentReceived", "Fandoavam-bola voaray" },
            { "TimeAgo", "taloha" },
            { "DarkMode", "Maizina" },
            { "Fullscreen", "Efijery feno" },
            { "Settings", "Firafitra" },
            { "CheckUpdates", "Hamarino ny fanavaozana" },
            { "Backup", "Tehirizo" },
            { "Restore", "Avereno" },
            { "LicenceExpires", "Lisansy lany daty" },
            { "MaxUsers", "Mpampiasa farany" },
            { "LicenceMissing", "Tsy misy lisansy" },
            { "LicenceInvalid", "Lisansy tsy mety" },
            { "NoData", "Tsy misy angona" },
            { "ContactAdmin", "Mifandraisa amin'ny admin" },
            { "Accueil", "Fandraisana" },
            { "Modules", "Module" },
            { "Ecolage", "Saram-pianarana" },
            { "Utilities", "Fitaovana" },
            { "Administration", "Fitandremana" },
            { "Welcome", "Tongasoa" },
            { "Login", "Midira" }
        };

        DefaultTranslations["fr"] = fr;
        DefaultTranslations["en"] = en;
        DefaultTranslations["mg"] = mg;
    }

    /// <summary>
    /// Normalise et valide un code de langue supporté.
    /// Accepte par exemple : fr, fr-FR, en-US, mg-MG.
    /// </summary>
    public static string NormalizeCultureCode(string cultureCode)
    {
        if (string.IsNullOrWhiteSpace(cultureCode))
            return "fr";

        string normalized = cultureCode.Trim();
        if (string.IsNullOrEmpty(normalized))
            return "fr";

        normalized = normalized.Replace("_", "-");

        // Cas direct: fr, en, mg
        if (Array.Exists(SupportedCultures, c => string.Equals(c, normalized, StringComparison.OrdinalIgnoreCase)))
            return normalized.ToLowerInvariant();

        // Cas standard avec région: fr-FR => fr ; en-US => en ; mg-MG => mg
        string baseCode = normalized.Split('-')[0];
        if (Array.Exists(SupportedCultures, c => string.Equals(c, baseCode, StringComparison.OrdinalIgnoreCase)))
            return baseCode.ToLowerInvariant();

        return "fr";
    }

    /// <summary>
    /// Obtient la culture actuelle
    /// </summary>
    public static CultureInfo CurrentCulture
    {
        get
        {
            try
            {
                if (HttpContext.Current != null && HttpContext.Current.Session != null)
                {
                    string culture = HttpContext.Current.Session["CurrentCulture"] as string;
                    if (!string.IsNullOrEmpty(culture))
                    {
                        string normalized = NormalizeCultureCode(culture);
                        return new CultureInfo(normalized);
                    }
                }
            }
            catch { }

            return new CultureInfo("fr");
        }
    }

    /// <summary>
    /// Code de la langue actuelle
    /// </summary>
    public static string CurrentCultureCode
    {
        get { return CurrentCulture.Name; }
    }

    /// <summary>
    /// Applique la culture de manière robuste à la session, au thread et à la page.
    /// </summary>
    public static void ApplyCulture(string cultureCode)
    {
        string normalized = NormalizeCultureCode(cultureCode);
        var culture = new CultureInfo(normalized);

        try
        {
            Thread.CurrentThread.CurrentCulture = culture;
            Thread.CurrentThread.CurrentUICulture = culture;

            if (HttpContext.Current != null)
            {
                if (HttpContext.Current.Session != null)
                {
                    HttpContext.Current.Session["CurrentCulture"] = normalized;
                }

                if (HttpContext.Current.CurrentHandler is Page)
                {
                    Page page = (Page)HttpContext.Current.CurrentHandler;
                    page.UICulture = normalized;
                    page.Culture = normalized;
                }

                SetCultureCookie(normalized);
            }
        }
        catch { }
    }

    /// <summary>
    /// Définit la culture pour la session en cours
    /// </summary>
    public static void SetCulture(string cultureCode)
    {
        ApplyCulture(cultureCode);
    }

    private static void SetCultureCookie(string cultureCode)
    {
        try
        {
            if (HttpContext.Current == null || HttpContext.Current.Response == null) return;

            var cookie = new HttpCookie("UserLanguage")
            {
                Value = cultureCode,
                Expires = DateTime.UtcNow.AddYears(1),
                HttpOnly = true,
                Secure = HttpContext.Current.Request != null && HttpContext.Current.Request.IsSecureConnection,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Set(cookie);
        }
        catch { }
    }

    private static string GetCultureFromCookie()
    {
        try
        {
            if (HttpContext.Current == null || HttpContext.Current.Request == null) return null;
            var cookie = HttpContext.Current.Request.Cookies["UserLanguage"];
            return cookie != null ? NormalizeCultureCode(cookie.Value) : null;
        }
        catch { return null; }
    }

    private static string BuildCleanUrlForLanguage(HttpRequest request)
    {
        if (request == null || request.Url == null)
            return "/";

        var urlBuilder = new StringBuilder();
        urlBuilder.Append(request.Url.AbsolutePath);

        bool firstParam = true;
        foreach (string key in request.QueryString.Keys)
        {
            if (string.IsNullOrEmpty(key) || key.Equals("lang", StringComparison.OrdinalIgnoreCase))
                continue;

            if (firstParam)
            {
                urlBuilder.Append("?");
                firstParam = false;
            }
            else
            {
                urlBuilder.Append("&");
            }

            string value = request.QueryString[key];
            urlBuilder.Append(HttpUtility.UrlEncode(key));
            urlBuilder.Append("=");
            urlBuilder.Append(HttpUtility.UrlEncode(value));
        }

        return urlBuilder.ToString();
    }

    /// <summary>
    /// Obtient une traduction depuis les ressources ou le dictionnaire par défaut
    /// </summary>
    public static string GetString(string key)
    {
        try
        {
            // Essayer d'abord via les ressources .resx
            try
            {
                var resource = HttpContext.GetGlobalResourceObject("AppResources", key);
                if (resource != null)
                    return resource.ToString();
            }
            catch { }

            // Fallback vers le dictionnaire par défaut
            string culture = CurrentCultureCode;
            if (DefaultTranslations.ContainsKey(culture) && DefaultTranslations[culture].ContainsKey(key))
            {
                return DefaultTranslations[culture][key];
            }

            // Essayer en français si non trouvé dans la langue actuelle
            if (culture != "fr" && DefaultTranslations.ContainsKey("fr") && DefaultTranslations["fr"].ContainsKey(key))
            {
                return DefaultTranslations["fr"][key];
            }

            // Rechercher dans toutes les langues
            foreach (var lang in DefaultTranslations.Keys)
            {
                if (DefaultTranslations[lang].ContainsKey(key))
                {
                    return DefaultTranslations[lang][key];
                }
            }

            return key;
        }
        catch
        {
            return key;
        }
    }

    /// <summary>
    /// Obtient une traduction avec formatage
    /// </summary>
    public static string GetString(string key, params object[] args)
    {
        try
        {
            string value = GetString(key);
            return string.Format(value, args);
        }
        catch
        {
            return key;
        }
    }

    /// <summary>
    /// Rendu HTML du sélecteur de langue
    /// </summary>
    public static string RenderLanguageSelector()
    {
        try
        {
            var html = new StringBuilder();
            string currentCulture = CurrentCultureCode;

            html.Append(@"<div class=""language-selector"" style=""display:inline-block;position:relative;"">");
            html.Append(@"<button class=""btn btn-sm btn-outline-secondary dropdown-toggle"" type=""button"" aria-label=""Changer de langue"" style=""background:rgba(17,24,39,0.55);border:1px solid rgba(255,255,255,0.18);color:#fff;padding:6px 12px;border-radius:6px;cursor:pointer;display:flex;align-items:center;gap:7px;font-size:13px;line-height:1.4;"">");

            int currentIndex = Array.IndexOf(SupportedCultures, currentCulture);
            if (currentIndex >= 0)
            {
                html.AppendFormat(@"<img src=""{0}"" alt=""{1}"" style=""width:18px;height:12px;object-fit:cover;border-radius:2px;vertical-align:middle;"" />", CultureFlagPaths[currentIndex], CultureNames[currentIndex]);
                html.AppendFormat(@"<span style=""font-size:13px;font-weight:600;white-space:nowrap;"">{0}</span>", CultureNames[currentIndex]);
            }
            else
            {
                html.Append(@"<img src=""/img/Flag_FR.svg"" alt=""Français"" style=""width:18px;height:12px;object-fit:cover;border-radius:2px;vertical-align:middle;"" />");
                html.Append(@"<span style=""font-size:13px;font-weight:600;white-space:nowrap;"">Langue</span>");
            }

            html.Append(@" <span style=""font-size:10px;opacity:0.7;"">▼</span>");
            html.Append(@"</button>");

            html.Append(@"<div class=""dropdown-menu"" style=""position:absolute;top:100%;right:0;left:auto;min-width:170px;padding:6px 0;margin-top:4px;background:#2d3436;border:1px solid rgba(255,255,255,0.1);border-radius:8px;box-shadow:0 8px 32px rgba(0,0,0,0.4);display:none;z-index:99999;"">");
            html.Append(@"<div style=""padding:6px 14px;font-size:11px;color:rgba(255,255,255,0.4);text-transform:uppercase;letter-spacing:0.5px;border-bottom:1px solid rgba(255,255,255,0.05);"">🌐 Langue</div>");

            for (int i = 0; i < SupportedCultures.Length; i++)
            {
                bool isActive = (SupportedCultures[i] == currentCulture);
                string activeBg = isActive ? "background:rgba(79,125,243,0.15);" : "";
                string activeColor = isActive ? "color:#5b8def;" : "";
                string checkMark = isActive ? @" <i class=""fas fa-check"" style=""color:#34ce57;margin-left:auto;""></i>" : "";

                html.AppendFormat(@"<a class=""dropdown-item"" href=""#"" onclick=""setLanguage('{0}'); return false;"" style=""display:flex;align-items:center;gap:10px;padding:7px 14px;font-size:13px;color:#e8edf5;text-decoration:none;cursor:pointer;transition:background 0.2s;{1}{2}"">",
                    SupportedCultures[i], activeBg, activeColor);
                html.AppendFormat(@"<img src=""{0}"" alt=""{1}"" style=""width:18px;height:12px;object-fit:cover;border-radius:2px;vertical-align:middle;"" />", CultureFlagPaths[i], CultureNames[i]);
                html.Append(checkMark);
                html.Append(@"</a>");
            }

            html.Append(@"</div></div>");

            // Script pour gérer le toggle du dropdown et le changement de langue
            html.Append(@"
            <script>
                (function() {
                    // Gérer le toggle du dropdown
                    var selectors = document.querySelectorAll('.language-selector');
                    for (var i = 0; i < selectors.length; i++) {
                        var selector = selectors[i];
                        var btn = selector.querySelector('button');
                        var dropdown = selector.querySelector('.dropdown-menu');

                        if (btn && dropdown) {
                            btn.addEventListener('click', function(e) {
                                e.preventDefault();
                                e.stopPropagation();
                                var d = this.parentNode.querySelector('.dropdown-menu');
                                if (d) {
                                    d.classList.toggle('show');
                                    if (d.classList.contains('show')) {
                                        d.style.display = 'block';
                                    } else {
                                        d.style.display = 'none';
                                    }
                                }
                            });
                        }
                    }

                    // Fermer le dropdown si on clique ailleurs
                    document.addEventListener('click', function(e) {
                        var allSelectors = document.querySelectorAll('.language-selector');
                        for (var i = 0; i < allSelectors.length; i++) {
                            var selector = allSelectors[i];
                            var dropdown = selector.querySelector('.dropdown-menu');
                            if (dropdown && !selector.contains(e.target)) {
                                dropdown.classList.remove('show');
                                dropdown.style.display = 'none';
                            }
                        }
                    });

                    // Fonction pour changer la langue
                    window.setLanguage = function(culture) {
                        var currentUrl = window.location.href;
                        var separator = currentUrl.indexOf('?') > -1 ? '&' : '?';
                        var newUrl = currentUrl + separator + 'lang=' + culture;
                        // Nettoyer les doublons
                        newUrl = newUrl.replace(/([?&])lang=[^&]*&/g, '$1');
                        newUrl = newUrl.replace(/([?&])lang=[^&]*$/, '');
                        if (newUrl.indexOf('?') > -1) {
                            newUrl = newUrl + '&lang=' + culture;
                        } else {
                            newUrl = newUrl + '?lang=' + culture;
                        }
                        window.location.href = newUrl;
                    };
                })();
            </script>");

            return html.ToString();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine("Erreur RenderLanguageSelector: " + ex.Message);
            return "<span style='color:red;'>⚠️ Erreur langue</span>";
        }
    }

    /// <summary>
    /// Gère la langue depuis l'URL, la session, le cookie ou le navigateur.
    /// Logique robuste : normalisation, persistance, pas de redirection inutile, pas de boucle.
    /// </summary>
    public static void HandleLanguage()
    {
        try
        {
            if (HttpContext.Current == null) return;

            HttpRequest request = HttpContext.Current.Request;
            HttpResponse response = HttpContext.Current.Response;
            HttpSessionState session = HttpContext.Current.Session;

            string requestedCulture = NormalizeCultureCode(request.QueryString["lang"]);
            string currentCulture = session != null ? NormalizeCultureCode(session["CurrentCulture"] as string) : "fr";

            if (!string.IsNullOrEmpty(request.QueryString["lang"]))
            {
                string normalizedRequested = NormalizeCultureCode(request.QueryString["lang"]);

                if (!string.Equals(normalizedRequested, currentCulture, StringComparison.OrdinalIgnoreCase))
                {
                    ApplyCulture(normalizedRequested);
                }

                string cleanUrl = BuildCleanUrlForLanguage(request);
                if (!string.Equals(request.RawUrl, cleanUrl, StringComparison.OrdinalIgnoreCase))
                {
                    response.Redirect(cleanUrl, false);
                    HttpContext.Current.ApplicationInstance.CompleteRequest();
                    return;
                }

                return;
            }

            if (session != null)
            {
                string sessionCulture = session["CurrentCulture"] as string;
                if (!string.IsNullOrEmpty(sessionCulture))
                {
                    ApplyCulture(sessionCulture);
                    return;
                }
            }

            string cookieCulture = GetCultureFromCookie();
            if (!string.IsNullOrEmpty(cookieCulture))
            {
                ApplyCulture(cookieCulture);
                return;
            }

            string browserCulture = "fr";
            if (request.UserLanguages != null && request.UserLanguages.Length > 0)
            {
                string firstLanguage = request.UserLanguages[0];
                if (!string.IsNullOrEmpty(firstLanguage))
                {
                    browserCulture = NormalizeCultureCode(firstLanguage);
                }
            }

            ApplyCulture(browserCulture);
        }
        catch { }
    }

    /// <summary>
    /// Vérifie si une clé de ressource existe dans les traductions par défaut
    /// </summary>
    public static bool ResourceExists(string key)
    {
        try
        {
            // Essayer via les ressources .resx
            try
            {
                var resource = HttpContext.GetGlobalResourceObject("AppResources", key);
                if (resource != null)
                    return true;
            }
            catch { }

            // Vérifier dans le dictionnaire par défaut
            string culture = CurrentCultureCode;
            if (DefaultTranslations.ContainsKey(culture) && DefaultTranslations[culture].ContainsKey(key))
                return true;

            return false;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Obtient la liste des langues supportées
    /// </summary>
    public static string[] GetSupportedCultures()
    {
        return (string[])SupportedCultures.Clone();
    }

    /// <summary>
    /// Obtient le nom d'affichage d'une culture
    /// </summary>
    public static string GetCultureDisplayName(string cultureCode)
    {
        int index = Array.IndexOf(SupportedCultures, cultureCode);
        if (index >= 0 && index < CultureNames.Length)
            return CultureNames[index];
        return cultureCode;
    }

    /// <summary>
    /// Obtient le drapeau d'une culture.
    /// Utilise les fichiers SVG réels du dossier /img.
    /// </summary>
    public static string GetCultureFlag(string cultureCode)
    {
        string normalized = NormalizeCultureCode(cultureCode);
        int index = Array.IndexOf(SupportedCultures, normalized);
        if (index >= 0 && index < CultureFlagPaths.Length)
            return CultureFlagPaths[index];
        return "/img/Flag_FR.svg";
    }

    public static string GetCultureFlagHtml(string cultureCode)
    {
        string normalized = NormalizeCultureCode(cultureCode);
        int index = Array.IndexOf(SupportedCultures, normalized);
        if (index < 0 || index >= CultureFlagPaths.Length)
            return "<img src=\"/img/Flag_FR.svg\" alt=\"Français\" style=\"width:18px;height:12px;object-fit:cover;border-radius:2px;vertical-align:middle;\" />";

        return string.Format("<img src=\"{0}\" alt=\"{1}\" style=\"width:18px;height:12px;object-fit:cover;border-radius:2px;vertical-align:middle;\" />",
            CultureFlagPaths[index], CultureNames[index]);
    }

    /// <summary>
    /// Obtient le nom court d'une culture
    /// </summary>
    public static string GetCultureShortName(string cultureCode)
    {
        int index = Array.IndexOf(SupportedCultures, cultureCode);
        if (index >= 0 && index < CultureShortNames.Length)
            return CultureShortNames[index];
        return cultureCode.ToUpperInvariant();
    }
}
