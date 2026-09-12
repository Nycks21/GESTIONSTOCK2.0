using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

public static class AuthHelper
{
    // ============================================================
    // CONSTANTES ET CHAMPS PRIVÉS
    // ============================================================
    private static readonly string connStr;
    private const string SK_AUTHENTICATED = "authenticated";
    private const string SK_USERNAME = "username";
    private const string SK_IDUSER = "IDUSER";
    private const string SK_USERROLE = "USERROLE";
    private const string SK_SESSION_TOKEN = "SESSION_TOKEN";
    private const string SK_USER_PERMISSIONS = "USER_PERMISSIONS";

    static AuthHelper()
    {
        try
        {
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
                if (connStr == null) connStr = "";
            }
            else
            {
                connStr = "";
            }
        }
        catch
        {
            connStr = "";
        }
    }

    public static string ConnectionString
    {
        get { return connStr; }
    }

    // ============================================================
    // VÉRIFICATION D'AUTHENTIFICATION
    // ============================================================
    public static bool IsAuthenticated(HttpContext context)
    {
        if (context == null || context.Session == null)
            return false;

        return context.Session[SK_AUTHENTICATED] != null &&
               (bool)context.Session[SK_AUTHENTICATED];
    }

    // ============================================================
    // GARDE-FOU UNIFIÉ POUR LES HANDLERS .ASHX
    // ============================================================
    public static bool RequireApiAuth(HttpContext context, int minRole = -1)
    {
        if (context == null || context.Session == null)
            return false;

        if (context.Session[SK_AUTHENTICATED] == null || !(bool)context.Session[SK_AUTHENTICATED])
            return false;

        if (!ValidateSessionToken(context))
            return false;

        if (minRole >= 0)
        {
            int userRole = GetUserRole(context);
            if (userRole == 0) return true;
            if (userRole > minRole) return false;
        }

        return true;
    }

    public static bool RequirePermission(HttpContext context, string permissionCode)
    {
        if (context == null || context.Session == null)
            return false;

        if (context.Session[SK_AUTHENTICATED] == null || !(bool)context.Session[SK_AUTHENTICATED])
            return false;

        if (!ValidateSessionToken(context))
            return false;

        return HasPermission(permissionCode);
    }

    public static bool CanManageEmploi(HttpContext context)
    {
        if (context == null || context.Session == null)
            return false;

        int userRole = GetUserRole(context);
        return userRole == 0 || userRole == 1;
    }

    // ============================================================
    // VÉRIFICATION DU TOKEN DE SESSION EN BASE
    // ============================================================
    private static bool ValidateSessionToken(HttpContext context)
    {
        try
        {
            int userId = GetUserId(context);
            string sessionToken = context.Session[SK_SESSION_TOKEN] as string;

            if (userId <= 0 || string.IsNullOrEmpty(sessionToken))
            {
                LogAuthError("ValidateSessionToken: userId ou token manquant (userId=" + userId + ")");
                return false;
            }

            if (string.IsNullOrEmpty(connStr))
            {
                LogAuthError("ValidateSessionToken: chaîne de connexion vide");
                return false;
            }

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = "SELECT COUNT(*) FROM USERS WHERE IDUSER = @userId AND SESSION_TOKEN = @token";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.Parameters.AddWithValue("@token", sessionToken);
                    int count = (int)cmd.ExecuteScalar();
                    if (count == 0)
                        LogAuthError("ValidateSessionToken: token invalide pour userId=" + userId);
                    return count > 0;
                }
            }
        }
        catch (Exception ex)
        {
            LogAuthError("ValidateSessionToken exception: " + ex.Message);
            return false;
        }
    }

    private static void LogAuthError(string message)
    {
        try
        {
            string logFile = HttpContext.Current.Server.MapPath("~/App_Data/auth_token.log");
            System.IO.File.AppendAllText(logFile,
                string.Format("[{0}] {1}\n", DateTime.Now, message));
        }
        catch { }
    }

    // ============================================================
    // STRUCTURE D'UN MENU
    // ============================================================
    public class MenuItem
    {
        public string Code { get; set; }
        public string Text { get; set; }
        public string Url { get; set; }
        public string Icon { get; set; }
        public string Section { get; set; }
        public int Order { get; set; }
        public List<MenuItem> Children { get; set; }

        public MenuItem()
        {
            Children = new List<MenuItem>();
        }
    }

    // ============================================================
    // DÉFINITION DES MENUS
    // ============================================================
    public static readonly List<MenuItem> AllMenus = new List<MenuItem>
    {
        new MenuItem { Code = "accueil", Text = "Accueil", Url = "/pages/accueil/index.aspx", Icon = "fas fa-chalkboard", Section = "Accueil", Order = 1 },
        new MenuItem { Code = "unites", Text = "Unité", Url = "/pages/parametres/unites/unites.aspx", Icon = "fas fa-ruler", Section = "Paramètres", Order = 2 },
        new MenuItem { Code = "categories", Text = "Catégories", Url = "/pages/parametres/categories/categories.aspx", Icon = "fas fa-tags", Section = "Paramètres", Order = 3 },
        new MenuItem { Code = "fournisseurs", Text = "Fournisseurs", Url = "/pages/parametres/fournisseurs/fournisseurs.aspx", Icon = "fas fa-truck", Section = "Paramètres", Order = 4 },
        new MenuItem { Code = "emplacements", Text = "Emplacements", Url = "/pages/parametres/emplacements/emplacements.aspx", Icon = "fas fa-map-marker-alt", Section = "Paramètres", Order = 5 },
        new MenuItem { Code = "articles", Text = "Articles", Url = "/pages/modules/articles/articles.aspx", Icon = "fas fa-boxes", Section = "Mouvements", Order = 6 },
        new MenuItem { Code = "entrees", Text = "Entrées", Url = "/pages/modules/entrees/entrees.aspx", Icon = "fas fa-arrow-down", Section = "Mouvements", Order = 7 },
        new MenuItem { Code = "sorties", Text = "Sorties", Url = "/pages/modules/sorties/sorties.aspx", Icon = "fas fa-arrow-up", Section = "Mouvements", Order = 8 },
        new MenuItem { Code = "stock", Text = "Stock", Url = "/pages/modules/stock/stock.aspx", Icon = "fas fa-warehouse", Section = "Mouvements", Order = 9 },
        new MenuItem { Code = "saisies", Text = "Saisies", Url = "/pages/demandes/saisie/saisies.aspx", Icon = "fas fa-file-alt", Section = "Demandes", Order = 10 },
        new MenuItem { Code = "accuses", Text = "Accusés de réception", Url = "/pages/demandes/accuse/accuses.aspx", Icon = "fas fa-check-circle", Section = "Demandes", Order = 11 },
        new MenuItem { Code = "inventaire", Text = "Inventaire", Url = "/pages/modules/inventaire/inventaire.aspx", Icon = "fas fa-clipboard-list", Section = "Rapports", Order = 13 },
        new MenuItem { Code = "exploitation", Text = "Exploitations", Url = "/pages/rapports/stock-disponible.aspx", Icon = "fas fa-chart-bar", Section = "Rapports", Order = 14 },
        new MenuItem { Code = "utilisateurs", Text = "Utilisateurs", Url = "/pages/administrations/utilisateur/utilisateur.aspx", Icon = "fas fa-user-cog", Section = "Administration", Order = 15 },
        new MenuItem { Code = "requetes", Text = "Requêtes SQL", Url = "/pages/administrations/requete/requetes.aspx", Icon = "fas fa-terminal", Section = "Administration", Order = 16 },
    };

    // ============================================================
    // GESTION DES PERMISSIONS
    // ============================================================
    public static List<string> GetUserPermissions()
    {
        var session = HttpContext.Current.Session;

        if (session != null && session[SK_USER_PERMISSIONS] != null)
        {
            return session[SK_USER_PERMISSIONS] as List<string>;
        }

        if (IsSuperAdmin())
        {
            var allPerms = new List<string>();
            foreach (var menu in AllMenus) allPerms.Add(menu.Code);
            if (session != null) session[SK_USER_PERMISSIONS] = allPerms;
            return allPerms;
        }

        if (IsAdmin())
        {
            var adminPerms = new List<string>();
            foreach (var menu in AllMenus)
            {
                if (menu.Code != "requetes") adminPerms.Add(menu.Code);
            }
            if (session != null) session[SK_USER_PERMISSIONS] = adminPerms;
            return adminPerms;
        }

        int? userId = GetCurrentUserId();
        if (userId.HasValue && userId.Value > 0)
        {
            var permissions = LoadPermissionsFromDatabase(userId.Value);
            if (session != null) session[SK_USER_PERMISSIONS] = permissions;
            return permissions;
        }

        return new List<string>();
    }

    private static List<string> LoadPermissionsFromDatabase(int userId)
    {
        var permissions = new List<string>();

        try
        {
            if (string.IsNullOrEmpty(connStr)) return permissions;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string checkColumnQuery = @"
                    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'MENU_PERMISSIONS'";

                using (SqlCommand checkCmd = new SqlCommand(checkColumnQuery, conn))
                {
                    int columnExists = (int)checkCmd.ExecuteScalar();

                    if (columnExists > 0)
                    {
                        string sql = "SELECT MENU_PERMISSIONS FROM USERS WHERE IDUSER = @id";
                        using (SqlCommand cmd = new SqlCommand(sql, conn))
                        {
                            cmd.Parameters.AddWithValue("@id", userId);
                            object result = cmd.ExecuteScalar();

                            if (result != null && result != DBNull.Value && !string.IsNullOrEmpty(result.ToString()))
                            {
                                try
                                {
                                    var serializer = new JavaScriptSerializer();
                                    permissions = serializer.Deserialize<List<string>>(result.ToString());
                                }
                                catch { }
                            }
                        }
                    }
                    else
                    {
                        string sql = "SELECT PERMISSION_NAME FROM USER_PERMISSIONS WHERE USER_ID = @id";
                        using (SqlCommand cmd = new SqlCommand(sql, conn))
                        {
                            cmd.Parameters.AddWithValue("@id", userId);
                            using (SqlDataReader reader = cmd.ExecuteReader())
                            {
                                while (reader.Read())
                                {
                                    permissions.Add(reader["PERMISSION_NAME"].ToString());
                                }
                            }
                        }
                    }
                }
            }
        }
        catch { }

        return permissions;
    }

    public static bool HasPermission(string permissionCode)
    {
        if (IsSuperAdmin()) return true;
        if (IsAdmin() && permissionCode != "requetes") return true;

        var permissions = GetUserPermissions();
        return permissions.Contains(permissionCode);
    }

    public static List<MenuItem> GetAuthorizedMenus()
    {
        var authorizedMenus = new List<MenuItem>();

        foreach (var menu in AllMenus)
        {
            if (HasPermission(menu.Code)) authorizedMenus.Add(menu);
        }

        return authorizedMenus.OrderBy(m => m.Order).ToList();
    }

    public static bool SaveUserPermissions(int userId, List<string> permissions)
    {
        try
        {
            if (string.IsNullOrEmpty(connStr)) return false;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string checkColumnQuery = @"
                    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'MENU_PERMISSIONS'";

                using (SqlCommand checkCmd = new SqlCommand(checkColumnQuery, conn))
                {
                    int columnExists = (int)checkCmd.ExecuteScalar();

                    if (columnExists > 0)
                    {
                        var serializer = new JavaScriptSerializer();
                        string permissionsJson = serializer.Serialize(permissions);

                        string sql = "UPDATE USERS SET MENU_PERMISSIONS = @permissions WHERE IDUSER = @id";
                        using (SqlCommand cmd = new SqlCommand(sql, conn))
                        {
                            cmd.Parameters.AddWithValue("@permissions", permissionsJson);
                            cmd.Parameters.AddWithValue("@id", userId);
                            cmd.ExecuteNonQuery();
                        }
                    }
                    else
                    {
                        string deleteSql = "DELETE FROM USER_PERMISSIONS WHERE USER_ID = @id";
                        using (SqlCommand deleteCmd = new SqlCommand(deleteSql, conn))
                        {
                            deleteCmd.Parameters.AddWithValue("@id", userId);
                            deleteCmd.ExecuteNonQuery();
                        }

                        foreach (string perm in permissions)
                        {
                            string insertSql = "INSERT INTO USER_PERMISSIONS (USER_ID, PERMISSION_NAME) VALUES (@id, @perm)";
                            using (SqlCommand insertCmd = new SqlCommand(insertSql, conn))
                            {
                                insertCmd.Parameters.AddWithValue("@id", userId);
                                insertCmd.Parameters.AddWithValue("@perm", perm);
                                insertCmd.ExecuteNonQuery();
                            }
                        }
                    }
                }

                var session = HttpContext.Current.Session;
                if (session != null && session[SK_IDUSER] != null && Convert.ToInt32(session[SK_IDUSER]) == userId)
                {
                    session[SK_USER_PERMISSIONS] = permissions;
                }

                return true;
            }
        }
        catch
        {
            return false;
        }
    }

    // ============================================================
    // MULTI-LANGAGE
    // ============================================================
    public static string T(string key) { return LocalizationHelper.GetString(key); }
    public static string T(string key, params object[] args) { return LocalizationHelper.GetString(key, args); }
    public static string RenderLanguageSelector() { return LocalizationHelper.RenderLanguageSelector(); }

    // ============================================================
    // ✅ GÉNÉRATION DU PROFIL UTILISATEUR (HTML) — MODERN
    // ============================================================
    public static string RenderUserProfileHTML()
    {
        try
        {
            string userName = GetUserName();
            string roleName = GetRoleName();

            if (string.IsNullOrEmpty(userName)) userName = T("User");

            var html = new StringBuilder();
            html.Append(@"
            <div class=""user-profile-nav"">
                <div class=""user-avatar"">
                    <i class=""fas fa-user-tie""></i>
                    <span class=""status-indicator""></span>
                </div>
                <div class=""user-info"">
                    <span id=""profilUsername"" class=""user-role"">");
            html.Append(HttpUtility.HtmlEncode(roleName));
            html.Append(@"</span>
                    <span id=""navbarUsername"" class=""user-name"">");
            html.Append(HttpUtility.HtmlEncode(userName));
            html.Append(@"</span>
                </div>
            </div>");

            return html.ToString();
        }
        catch (Exception ex)
        {
            return "<div style='color:red;padding:10px;'>Erreur profil: " + HttpUtility.HtmlEncode(ex.Message) + "</div>";
        }
    }

    // ============================================================
    // ✅ GÉNÉRATION DU MENU HTML — MODERN
    // ============================================================
    public static string RenderMenuHTML()
    {
        try
        {
            var menus = GetAuthorizedMenus();

            if (menus == null || menus.Count == 0)
            {
                return "<div class='nav-section-modern' style='padding:15px;text-align:center;'>" +
                       T("NoData") +
                       "<br><small>" + T("ContactAdmin") + "</small></div>";
            }

            string currentPage = "";
            try
            {
                if (HttpContext.Current != null && HttpContext.Current.Request != null && HttpContext.Current.Request.Url != null)
                {
                    currentPage = System.IO.Path.GetFileNameWithoutExtension(
                        HttpContext.Current.Request.Url.AbsolutePath).ToLower();
                }
            }
            catch { }

            var sections = new Dictionary<string, List<MenuItem>>();
            foreach (var menu in menus)
            {
                string sectionKey = menu.Section;
                if (!sections.ContainsKey(sectionKey))
                    sections[sectionKey] = new List<MenuItem>();
                sections[sectionKey].Add(menu);
            }

            var html = new StringBuilder();

            // Profil utilisateur
            html.Append(RenderUserProfileHTML());

            // Container modern
            html.Append(@"<div class=""sidebar-nav-modern"">");

            foreach (var section in sections)
            {
                string sectionName = T(section.Key);

                html.AppendFormat(@"
                <div class=""nav-section-modern"">
                    <span class=""nav-section-label"">{0}</span>
                </div>", HttpUtility.HtmlEncode(sectionName));

                html.Append(@"<ul class=""nav-list-modern"">");

                foreach (var menu in section.Value.OrderBy(m => m.Order))
                {
                    string menuText = T(menu.Text);

                    bool isActive = false;
                    if (!string.IsNullOrEmpty(currentPage) && !string.IsNullOrEmpty(menu.Url))
                    {
                        string menuFileName = System.IO.Path.GetFileNameWithoutExtension(menu.Url).ToLower();
                        isActive = currentPage == menuFileName;
                    }

                    string activeClass = isActive ? " active" : "";

                    html.AppendFormat(@"
                    <li class=""nav-item-modern"">
                        <a href=""{0}"" class=""nav-link-modern{1}"" data-menu=""{2}"">
                            <span class=""nav-icon-wrap"">
                                <i class=""{3}""></i>
                            </span>
                            <span class=""nav-link-text"">{4}</span>",
                        menu.Url, activeClass, menu.Code, menu.Icon, HttpUtility.HtmlEncode(menuText));

                    if (menu.Code == "sorties")
                    {
                        html.Append(@" <span id=""sortiePendingCount"" class=""nav-badge-pending"" style=""display:none;"" aria-label=""Bons de sortie non validés""></span>");
                    }

                    html.Append(@"</a></li>");
                }

                html.Append(@"</ul>");
            }

            html.Append(@"</div>");
            return html.ToString();
        }
        catch (Exception ex)
        {
            return "<div style='color:red;padding:10px;'>Erreur menu: " + HttpUtility.HtmlEncode(ex.Message) + "</div>";
        }
    }

        // ============================================================
    // ✅ GÉNÉRATION DE LA TOPBAR HTML — MODERN (badge projet centré)
    // ============================================================
    public static string RenderTopBarHTML()
    {
        try
        {
            var html = new StringBuilder();

            string currentPage = "";
            bool isUsersPage = false;

            try
            {
                if (HttpContext.Current != null && HttpContext.Current.Request != null && HttpContext.Current.Request.Url != null)
                {
                    currentPage = HttpContext.Current.Request.Url.AbsolutePath.ToLower();
                }
            }
            catch { }

            if (!string.IsNullOrEmpty(currentPage))
            {
                isUsersPage = currentPage.Contains("utilisateur.aspx") || currentPage.Contains("users.aspx");
            }

            // ============================================================
            // STRUCTURE EN 3 SECTIONS : gauche | centre | droite
            // ============================================================
            html.Append(@"
        <nav class=""main-header modern-topbar"">
            <ul class=""navbar-nav topbar-left"">
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""menuToggle"" role=""button"" title=""Menu"">
                        <i class=""fas fa-bars""></i>
                    </a>
                </li>
            </ul>");

            // ============================================================
            // SECTION CENTRALE : BADGE PROJET
            // ============================================================
            string projetCode = GetProjectCode(HttpContext.Current);
            html.AppendFormat(@"
            <div class=""topbar-center"">
                <span class=""project-badge-modern"" title=""{1}"">
                    <i class=""fas fa-project-diagram""></i>
                    <span class=""project-badge-label"">PROJET</span>
                    <span class=""project-badge-sep"">:</span>
                    <span class=""project-badge-code"">{0}</span>
                </span>
            </div>",
                HttpUtility.HtmlEncode(projetCode),
                HttpUtility.HtmlEncode(T("ProjetCourant")));

            // ============================================================
            // SECTION DROITE : langue, dark mode, notifications, etc.
            // ============================================================
            html.Append(@"<ul class=""navbar-nav topbar-right"">");

            // SÉLECTEUR DE LANGUE
            string currentCulture = LocalizationHelper.CurrentCultureCode;
            html.Append(@"
                <li class=""nav-item"">
                    <div class=""lang-selector-modern"">
                        <i class=""fas fa-globe lang-selector-icon""></i>
                        <select id=""langSelect"" class=""lang-select-modern"">");

            for (int i = 0; i < LocalizationHelper.SupportedCultures.Length; i++)
            {
                string code = LocalizationHelper.SupportedCultures[i];
                string name = LocalizationHelper.CultureNames[i];
                string selected = (code == currentCulture) ? " selected" : "";
                html.AppendFormat(@"<option value=""{0}""{1}>{2}</option>", code, selected, HttpUtility.HtmlEncode(name));
            }

            html.Append(@"</select>
                    </div>
                </li>");

            // DARK MODE
            html.Append(@"
                <li class=""nav-item"">
                    <label class=""switch switch-modern"" for=""toggleDarkMode"" title=""Mode sombre"">
                        <input type=""checkbox"" id=""toggleDarkMode"">
                        <span class=""slider-modern round""></span>
                    </label>
                </li>");

            // NOTIFICATIONS
            if (HasPermission("accueil"))
            {
                html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""notifToggle"" title=""" + T("Notifications") + @""">
                        <i class=""fas fa-bell""></i>
                        <span class=""topbar-badge"">3</span>
                    </a>
                    <div class=""dropdown-menu topbar-dropdown"" id=""notifDropdown"">
                        <div class=""topbar-dropdown-header"">
                            <i class=""fas fa-bell""></i>
                            <span>3 " + T("Notifications") + @"</span>
                        </div>
                        <div class=""topbar-dropdown-divider""></div>
                        <a href=""#"" class=""topbar-dropdown-item"">
                            <span class=""topbar-dropdown-icon icon-success""><i class=""fas fa-user-plus""></i></span>
                            <span class=""topbar-dropdown-text"">" + T("N") + @"</span>
                            <span class=""topbar-dropdown-time"">" + T("TimeAgo") + @" 23 min</span>
                        </a>
                        <a href=""#"" class=""topbar-dropdown-item"">
                            <span class=""topbar-dropdown-icon icon-danger""><i class=""fas fa-exclamation-circle""></i></span>
                            <span class=""topbar-dropdown-text"">" + T("A") + @"</span>
                            <span class=""topbar-dropdown-time"">" + T("TimeAgo") + @" 1h</span>
                        </a>
                        <a href=""#"" class=""topbar-dropdown-item"">
                            <span class=""topbar-dropdown-icon icon-warning""><i class=""fas fa-money-bill""></i></span>
                            <span class=""topbar-dropdown-text"">" + T("P") + @"</span>
                            <span class=""topbar-dropdown-time"">" + T("TimeAgo") + @" 2h</span>
                        </a>
                    </div>
                </li>");
            }

            // LOGOUT
            html.Append(@"
                <li class=""nav-item"">
                    <a href=""../../../auth/Logout.aspx"" class=""nav-link topbar-icon-btn topbar-logout"" title=""" + T("Logout") + @""">
                        <i class=""fas fa-sign-out-alt""></i>
                    </a>
                </li>");

            // FULLSCREEN
            html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""fullscreenToggle"" title=""" + T("Fullscreen") + @""">
                        <i class=""fas fa-expand-arrows-alt""></i>
                    </a>
                </li>");

            // SETTINGS
            if (isUsersPage && HasPermission("utilisateurs"))
            {
                html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""toggleSidebarBtn"" title=""" + T("Settings") + @""">
                        <i class=""fas fa-database""></i>
                    </a>
                </li>");
            }

            html.Append(@"
            </ul>
        </nav>");

            return html.ToString();
        }
        catch (Exception ex)
        {
            return "<div style='color:red;padding:10px;'>Erreur topbar: " + HttpUtility.HtmlEncode(ex.Message) + "</div>";
        }
    }

    // ============================================================
    // ✅ GÉNÉRATION DU CONTROL SIDEBAR HTML — MODERN
    // ============================================================
    public static string RenderControlSidebarHTML()
    {
        try
        {
            var html = new StringBuilder();

            html.Append(@"
            <aside class=""control-sidebar-modern"" id=""controlSidebar"">
                <div class=""control-sidebar-inner"">

                    <div class=""control-sidebar-header"">
                        <h5 class=""control-sidebar-title"">
                            <i class=""fas fa-database""></i>
                            <span>" + T("Settings") + @"</span>
                        </h5>
                        <button type=""button"" id=""closeSidebarBtn"" class=""control-sidebar-close"" title=""Fermer"">
                            <i class=""fas fa-times""></i>
                        </button>
                    </div>

                    <div class=""control-sidebar-info"">
                        <div class=""control-info-item"">
                            <i class=""fas fa-calendar-alt""></i>
                            <span>" + T("LicenceExpires") + @" :</span>
                            <strong id=""expirationDateStr"">" + GetExpirationDateString() + @"</strong>
                        </div>
                        <div class=""control-info-item"">
                            <i class=""fas fa-users""></i>
                            <span>" + T("MaxUsers") + @" :</span>
                            <strong id=""maxUsersCount"">" + GetMaxUsersString() + @"</strong>
                        </div>
                    </div>");

            if (IsSuperAdmin())
            {
                html.Append(@"
                    <div class=""control-sidebar-actions"">
                        <button type=""button"" id=""btnCheckUpdates"" class=""control-btn control-btn-primary"" onclick=""checkForUpdates()"">
                            <i class=""fas fa-sync-alt""></i>
                            <span>" + T("CheckUpdates") + @"</span>
                        </button>
                        <button type=""button"" id=""btnBackup"" class=""control-btn control-btn-success"" onclick=""backupDatabase()"">
                            <i class=""fas fa-database""></i>
                            <span>" + T("Backup") + @"</span>
                        </button>
                        <button type=""button"" id=""btnRestore"" class=""control-btn control-btn-warning"" onclick=""openRestoreModal()"">
                            <i class=""fas fa-undo-alt""></i>
                            <span>" + T("Restore") + @"</span>
                        </button>
                    </div>");
            }

            html.Append(@"
                </div>
            </aside>

            <div id=""sidebarOverlay"" class=""control-sidebar-overlay""></div>");

            return html.ToString();
        }
        catch (Exception ex)
        {
            return "<div style='color:red;padding:10px;'>Erreur control sidebar: " + HttpUtility.HtmlEncode(ex.Message) + "</div>";
        }
    }

    // ============================================================
    // MÉTHODES DE SESSION
    // ============================================================
    public static void VerifySession(Page page)
    {
        if (page.Session[SK_AUTHENTICATED] == null || !(bool)page.Session[SK_AUTHENTICATED])
        {
            page.Response.Redirect("~/auth/Login.aspx");
            return;
        }

        if (!IsTokenValid())
        {
            ForceLogout(page, true);
            return;
        }

        if (!page.IsPostBack)
        {
            SetUsername(page);
            SetRolename(page);
        }
    }

    private static bool IsTokenValid()
    {
        var session = HttpContext.Current.Session;
        if (session == null || session[SK_IDUSER] == null || session[SK_SESSION_TOKEN] == null)
            return false;

        try
        {
            int idUser = (int)session[SK_IDUSER];
            string tokenSession = session[SK_SESSION_TOKEN].ToString();

            if (string.IsNullOrEmpty(connStr)) return false;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand("SELECT SESSION_TOKEN FROM USERS WHERE IDUSER=@id", conn))
                {
                    cmd.Parameters.AddWithValue("@id", idUser);
                    conn.Open();
                    object tokenDb = cmd.ExecuteScalar();
                    return tokenDb != null && tokenDb.ToString() == tokenSession;
                }
            }
        }
        catch { return false; }
    }

    private static void SetUsername(Page page)
    {
        var session = HttpContext.Current.Session;
        if (session == null || session[SK_USERNAME] == null) return;
        string username = session[SK_USERNAME].ToString();
        string script = "var el=document.getElementById('navbarUsername'); if(el){el.textContent="
            + HttpUtility.JavaScriptStringEncode(username, true) + ";}";
        page.ClientScript.RegisterStartupScript(page.GetType(), "username", script, true);
    }

    private static void SetRolename(Page page)
    {
        string roleName = GetRoleName();
        string script = "var el=document.getElementById('profilUsername'); if(el){el.textContent="
            + HttpUtility.JavaScriptStringEncode(roleName, true) + ";}";
        page.ClientScript.RegisterStartupScript(page.GetType(), "rolename", script, true);
    }

    private static void ForceLogout(Page page, bool otherPc)
    {
        HttpContext.Current.Session.Clear();
        HttpContext.Current.Session.Abandon();
        string url = otherPc ? "~/auth/Login.aspx?msg=other_pc" : "~/auth/Login.aspx";
        page.Response.Redirect(url, true);
    }

    public static void Logout(HttpContext context)
    {
        if (context == null || context.Session == null) return;

        int userId = GetUserId(context);
        if (userId > 0)
        {
            try
            {
                using (SqlConnection conn = new SqlConnection(connStr))
                {
                    string sql = "UPDATE USERS SET SESSION_TOKEN = NULL WHERE IDUSER = @id";
                    using (SqlCommand cmd = new SqlCommand(sql, conn))
                    {
                        cmd.Parameters.AddWithValue("@id", userId);
                        conn.Open();
                        cmd.ExecuteNonQuery();
                    }
                }
            }
            catch { }
        }

        context.Session.Clear();
        context.Session.Abandon();

        if (context.Request.Cookies["ASP.NET_SessionId"] != null)
        {
            var cookie = new HttpCookie("ASP.NET_SessionId");
            cookie.Expires = DateTime.Now.AddDays(-1);
            context.Response.Cookies.Add(cookie);
        }

        try
        {
            System.Web.Security.FormsAuthentication.SignOut();
            string authCookieName = System.Web.Security.FormsAuthentication.FormsCookieName;
            if (context.Request.Cookies[authCookieName] != null)
            {
                var authCookie = new HttpCookie(authCookieName);
                authCookie.Expires = DateTime.Now.AddDays(-1);
                context.Response.Cookies.Add(authCookie);
            }
        }
        catch { }

        context.Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
        context.Response.Cache.SetNoStore();
        context.Response.Cache.SetExpires(DateTime.UtcNow.AddYears(-1));
        context.Response.AppendHeader("Pragma", "no-cache");
        context.Response.AppendHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        context.Response.AppendHeader("Expires", "0");
    }

    // ============================================================
    // GETTERS
    // ============================================================
    public static int GetUserId(HttpContext context)
    {
        if (context == null || context.Session == null) return 0;
        object val = context.Session[SK_IDUSER];
        return (val != null) ? Convert.ToInt32(val) : 0;
    }

    public static string GetUserName()
    {
        var session = HttpContext.Current.Session;
        if (session == null) return "Inconnu";
        return session[SK_USERNAME] as string ?? "Inconnu";
    }

    public static int GetUserRole(HttpContext context)
    {
        if (context == null || context.Session == null) return -1;
        object val = context.Session[SK_USERROLE];
        return (val != null) ? Convert.ToInt32(val) : -1;
    }

    public static string GetProjectCode(HttpContext ctx)
    {
        try
        {
            string code = ConfigurationManager.AppSettings["ProjectCode"];
            if (string.IsNullOrEmpty(code)) code = "TALIM";
            return code.Trim().ToUpperInvariant().Replace(" ", "");
        }
        catch { return "TALIM"; }
    }

    private static int? GetUserRoleId()
    {
        var session = HttpContext.Current.Session;
        if (session == null || session[SK_USERROLE] == null) return null;
        try { return Convert.ToInt32(session[SK_USERROLE]); }
        catch { return null; }
    }

    private static int? GetCurrentUserId()
    {
        var session = HttpContext.Current.Session;
        if (session == null || session[SK_IDUSER] == null) return null;
        try { return Convert.ToInt32(session[SK_IDUSER]); }
        catch { return null; }
    }

    // ============================================================
    // VÉRIFICATIONS DE RÔLES
    // ============================================================
    public static bool IsSuperAdmin() { var r = GetUserRoleId(); return r.HasValue && r.Value == 0; }
    public static bool IsAdmin()      { var r = GetUserRoleId(); return r.HasValue && r.Value == 1; }
    public static bool IsUser()       { var r = GetUserRoleId(); return r.HasValue && r.Value == 2; }
    public static bool IsLogisticien(){ var r = GetUserRoleId(); return r.HasValue && r.Value == 3; }
    public static bool IsComptable()  { var r = GetUserRoleId(); return r.HasValue && r.Value == 4; }

    public static string GetRoleName()
    {
        var roleId = GetUserRoleId();
        if (!roleId.HasValue) return T("Unknown");

        switch (roleId.Value)
        {
            case 0: return T("SuperAdmin");
            case 1: return T("Admin");
            case 2: return T("User");
            case 3: return T("Logisticien");
            case 4: return T("Comptable");
            default: return T("Unknown");
        }
    }

    public static string Version
    {
        get
        {
            var version = ConfigurationManager.AppSettings["Version"];
            return string.IsNullOrEmpty(version) ? "1.0.0" : version;
        }
    }

    // ============================================================
    // GESTION DE LA LICENCE
    // ============================================================
    private enum LicenceStatus { Valide, Manquante, Expiree, Invalide }

    private static readonly object _licenceLock = new object();
    private static DateTime _cachedExpirationDate = DateTime.MinValue;
    private static int _cachedMaxUsers = 0;
    private static DateTime _cacheTime = DateTime.MinValue;
    private static readonly TimeSpan _cacheDuration = TimeSpan.FromMinutes(5);

    public static string GetExpirationDateString()
    {
        DateTime expirationDate; int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);

        if (status == LicenceStatus.Valide || status == LicenceStatus.Expiree)
            return expirationDate.ToString("dd/MM/yyyy");
        else if (status == LicenceStatus.Manquante)
            return T("LicenceMissing");
        else
            return T("LicenceInvalid");
    }

    public static string GetMaxUsersString()
    {
        DateTime expirationDate; int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);

        if (status == LicenceStatus.Valide || status == LicenceStatus.Expiree)
            return maxUsers.ToString();
        else
            return "0";
    }

    public static bool IsMaxUsersReached()
    {
        DateTime expirationDate; int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);

        if (status != LicenceStatus.Valide) return true;

        try
        {
            if (string.IsNullOrEmpty(connStr)) return true;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand("SELECT COUNT(*) FROM USERS WHERE SESSION_TOKEN IS NOT NULL", conn))
                {
                    conn.Open();
                    int activeUsers = (int)cmd.ExecuteScalar();
                    return activeUsers >= maxUsers;
                }
            }
        }
        catch { return false; }
    }

    public static bool IsLicenceValid()
    {
        DateTime expirationDate; int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);
        return status == LicenceStatus.Valide;
    }

    public static SidebarInfo GetSidebarInfo()
    {
        DateTime expirationDate; int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);

        string expirationText; string maxUsersText;

        if (status == LicenceStatus.Valide || status == LicenceStatus.Expiree)
        {
            expirationText = expirationDate.ToString("dd/MM/yyyy");
            maxUsersText = maxUsers.ToString();
        }
        else if (status == LicenceStatus.Manquante)
        {
            expirationText = T("LicenceMissing");
            maxUsersText = "0";
        }
        else
        {
            expirationText = T("LicenceInvalid");
            maxUsersText = "0";
        }

        return new SidebarInfo
        {
            ExpirationDate = expirationText,
            MaxUsers = maxUsersText,
            IsValid = (status == LicenceStatus.Valide),
            IsExpired = (status == LicenceStatus.Expiree)
        };
    }

    private static LicenceStatus CheckLicence(out DateTime expirationDate, out int maxUsers)
    {
        expirationDate = DateTime.MinValue;
        maxUsers = 0;

        lock (_licenceLock)
        {
            if (_cacheTime > DateTime.Now.Subtract(_cacheDuration))
            {
                expirationDate = _cachedExpirationDate;
                maxUsers = _cachedMaxUsers;

                if (_cachedExpirationDate == DateTime.MinValue)
                    return LicenceStatus.Invalide;

                if (DateTime.Now.Date > _cachedExpirationDate.Date)
                    return LicenceStatus.Expiree;

                return LicenceStatus.Valide;
            }
        }

        if (HttpContext.Current == null)
            return LicenceStatus.Invalide;

        string path = HttpContext.Current.Server.MapPath("~/bin/licence.key");
        if (!File.Exists(path))
            return LicenceStatus.Manquante;

        string secret = ConfigurationManager.AppSettings["LicenceSecret"];
        if (string.IsNullOrEmpty(secret))
            return LicenceStatus.Invalide;

        try
        {
            string[] lines = File.ReadAllLines(path);

            string expClear = GetValueFromLines(lines, "EXPIRATIONS", false);
            string maxClear = GetValueFromLines(lines, "MAX_USERSS", false);

            string expHash = GetValueFromLines(lines, "EXPIRATION", true);
            string maxHash = GetValueFromLines(lines, "MAX_USERS", true);
            string sigHash = GetValueFromLines(lines, "SIGNATURE", true);

            if (!DateTime.TryParseExact(expClear, "yyyy-MM-dd",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out expirationDate))
                return LicenceStatus.Invalide;

            if (!int.TryParse(maxClear, out maxUsers) || maxUsers <= 0)
                return LicenceStatus.Invalide;

            string expCalc = ComputeHmacSha256(expClear, secret);
            string maxCalc = ComputeHmacSha256(maxUsers.ToString(), secret);
            string sigCalc = ComputeHmacSha256(expCalc + maxCalc, secret);

            if (expCalc != expHash || maxCalc != maxHash || sigCalc != sigHash)
                return LicenceStatus.Invalide;

            lock (_licenceLock)
            {
                _cachedExpirationDate = expirationDate;
                _cachedMaxUsers = maxUsers;
                _cacheTime = DateTime.Now;
            }

            if (DateTime.Now.Date > expirationDate.Date)
                return LicenceStatus.Expiree;

            return LicenceStatus.Valide;
        }
        catch
        {
            return LicenceStatus.Invalide;
        }
    }

    private static string GetValueFromLines(string[] lines, string key, bool first)
    {
        var values = new List<string>();
        foreach (var line in lines)
        {
            if (line.StartsWith(key + "="))
                values.Add(line.Substring(key.Length + 1).Trim());
        }

        if (values.Count == 0) return null;
        return first ? values[0] : values[values.Count - 1];
    }

    private static string ComputeHmacSha256(string data, string key)
    {
        using (var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(key)))
        {
            byte[] hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data));
            return BitConverter.ToString(hash).Replace("-", "").ToLower();
        }
    }

    // ============================================================
    // INFORMATIONS DE LICENCE
    // ============================================================
    public class LicenceInfo
    {
        public DateTime ExpirationDate { get; set; }
        public int MaxUsers { get; set; }
        public bool IsValid { get; set; }
        public bool IsExpired { get; set; }
        public int DaysLeft { get; set; }
    }

    public static LicenceInfo GetLicenceInfo()
    {
        DateTime exp; int max;
        var status = CheckLicence(out exp, out max);
        var info = new LicenceInfo
        {
            ExpirationDate = exp,
            MaxUsers = max,
            IsValid = (status == LicenceStatus.Valide),
            IsExpired = (status == LicenceStatus.Expiree)
        };
        info.DaysLeft = (exp.Date - DateTime.Now.Date).Days;
        return info;
    }

    public class SidebarInfo
    {
        public string ExpirationDate { get; set; }
        public string MaxUsers { get; set; }
        public bool IsValid { get; set; }
        public bool IsExpired { get; set; }
    }
}
