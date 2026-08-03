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

    // ✅ Constructeur statique (initialisation de la chaîne de connexion)
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

    // ============================================================
    // EXPOSITION DE LA CHAÎNE DE CONNEXION
    // ============================================================
    public static string ConnectionString
    {
        get { return connStr; }
    }

    // ============================================================
    // VÉRIFICATION D'AUTHENTIFICATION (pour pages et handlers)
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
            // SuperAdmin (0) est toujours autorisé
            if (userRole == 0) return true;
            if (userRole < minRole) return false;
        }

        return true;
    }

    public static bool CanManageEmploi(HttpContext context)
    {
        if (context == null || context.Session == null)
            return false;

        int userRole = GetUserRole(context);
        return userRole == 0 || userRole == 1 || userRole == 4;
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
                return false;

            if (string.IsNullOrEmpty(connStr))
                return false;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = "SELECT COUNT(*) FROM USERS WHERE IDUSER = @userId AND SESSION_TOKEN = @token";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.Parameters.AddWithValue("@token", sessionToken);
                    int count = (int)cmd.ExecuteScalar();
                    return count > 0;
                }
            }
        }
        catch
        {
            return false;
        }
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
    // DÉFINITION DES MENUS (tous les menus possibles)
    // ============================================================
    public static readonly List<MenuItem> AllMenus = new List<MenuItem>
    {
        new MenuItem { Code = "dashboard", Text = "Dashboard", Url = "../../accueil/dashboards/index.aspx", Icon = "fas fa-chalkboard", Section = "Accueil", Order = 1 },
        new MenuItem { Code = "eleves", Text = "Students", Url = "../../modules/eleves/eleves.aspx", Icon = "fas fa-users", Section = "Modules", Order = 2 },
        new MenuItem { Code = "absences", Text = "Absences", Url = "../../modules/absences/absences.aspx", Icon = "fas fa-calendar-times", Section = "Modules", Order = 3 },
        new MenuItem { Code = "bulletins", Text = "Grades", Url = "../../modules/bulletins/bulletins.aspx", Icon = "fas fa-file-alt", Section = "Modules", Order = 4 },
        new MenuItem { Code = "agenda", Text = "Agenda", Url = "../../modules/agenda/agenda.aspx", Icon = "fas fa-calendar-alt", Section = "Modules", Order = 5 },
        new MenuItem { Code = "emplois", Text = "Schedule", Url = "../../modules/emplois/emplois.aspx", Icon = "fas fa-clock", Section = "Modules", Order = 6 },
        new MenuItem { Code = "frais", Text = "Fees", Url = "../../modules/frais/frais.aspx", Icon = "fas fa-money-bill-wave", Section = "Ecolage", Order = 7 },
        new MenuItem { Code = "niveaux", Text = "Levels", Url = "../../parametres/niveaux/niveaux.aspx", Icon = "fas fa-layer-group", Section = "Settings", Order = 8 },
        new MenuItem { Code = "salles", Text = "Rooms", Url = "../../parametres/salles/salles.aspx", Icon = "fas fa-door-open", Section = "Settings", Order = 9 },
        new MenuItem { Code = "classes", Text = "Classes", Url = "../../parametres/classes/classes.aspx", Icon = "fas fa-folder", Section = "Settings", Order = 10 },
        new MenuItem { Code = "matieres", Text = "Subjects", Url = "../../parametres/matieres/matieres.aspx", Icon = "fas fa-book", Section = "Settings", Order = 11 },
        new MenuItem { Code = "importation", Text = "ImportStudents", Url = "../../administrations/utilitaires/utilitaires.aspx", Icon = "fas fa-cogs", Section = "Utilities", Order = 12 },
        new MenuItem { Code = "annees", Text = "SchoolYears", Url = "../../administrations/annee/annee.aspx", Icon = "fas fa-calendar-alt", Section = "Administration", Order = 13 },
        new MenuItem { Code = "utilisateurs", Text = "Users", Url = "../../administrations/utilisateur/utilisateur.aspx", Icon = "fas fa-user", Section = "Administration", Order = 14 },
        new MenuItem { Code = "requetes", Text = "SQLQueries", Url = "../../administrations/requete/requetes.aspx", Icon = "fas fa-database", Section = "Administration", Order = 15 }
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
            foreach (var menu in AllMenus)
            {
                allPerms.Add(menu.Code);
            }
            if (session != null) session[SK_USER_PERMISSIONS] = allPerms;
            return allPerms;
        }

        if (IsAdmin())
        {
            var adminPerms = new List<string>();
            foreach (var menu in AllMenus)
            {
                if (menu.Code != "requetes")
                {
                    adminPerms.Add(menu.Code);
                }
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
                    SELECT COUNT(*) 
                    FROM INFORMATION_SCHEMA.COLUMNS 
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
            if (HasPermission(menu.Code))
            {
                authorizedMenus.Add(menu);
            }
        }

        return authorizedMenus;
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
                    SELECT COUNT(*) 
                    FROM INFORMATION_SCHEMA.COLUMNS 
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
    // MULTI-LANGAGE (délégation à LocalizationHelper)
    // ============================================================
    public static string T(string key)
    {
        return LocalizationHelper.GetString(key);
    }

    public static string T(string key, params object[] args)
    {
        return LocalizationHelper.GetString(key, args);
    }

    public static string RenderLanguageSelector()
    {
        return LocalizationHelper.RenderLanguageSelector();
    }

    // ============================================================
    // GÉNÉRATION DU PROFIL UTILISATEUR (HTML)
    // ============================================================
    public static string RenderUserProfileHTML()
    {
        try
        {
            string userName = GetUserName();
            string roleName = GetRoleName();

            if (string.IsNullOrEmpty(userName))
            {
                userName = T("User");
            }

            var html = new StringBuilder();
            html.Append(@"
            <div class=""user-profile-nav"">
                <div class=""user-avatar"">
                    <i class=""fas fa-user-tie""></i>
                    <span class=""status-indicator""></span>
                </div>
                <div class=""user-info"">
                    <span id=""profilUsername"" class=""user-role"">");
            html.Append(roleName);
            html.Append(@"</span>
                    <span id=""navbarUsername"" class=""user-name"">");
            html.Append(userName);
            html.Append(@"</span>
                </div>
            </div>");

            return html.ToString();
        }
        catch (Exception ex)
        {
            return "<div style='color:red;padding:10px;'>Erreur profil: " + ex.Message + "</div>";
        }
    }

    // ============================================================
    // GÉNÉRATION DU MENU HTML (avec navigation active)
    // ============================================================
    public static string RenderMenuHTML()
    {
        try
        {
            var menus = GetAuthorizedMenus();

            if (menus == null || menus.Count == 0)
            {
                return "<div class='nav-section' style='padding:15px;text-align:center;'>" +
                       T("NoData") +
                       "<br><small>" + T("ContactAdmin") + "</small></div>";
            }

            // ✅ Récupérer la page actuelle (nom du fichier sans extension)
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
                {
                    sections[sectionKey] = new List<MenuItem>();
                }
                sections[sectionKey].Add(menu);
            }

            var html = new StringBuilder();
            html.Append(RenderUserProfileHTML());
            html.Append(@"<ul class=""nav-pills"">");

            foreach (var section in sections)
            {
                string sectionName = T(section.Key);
                html.AppendFormat(@"
                <li class=""nav-item"">
                    <div class=""nav-section"">{0}</div>", sectionName);

                foreach (var menu in section.Value)
                {
                    string menuText = T(menu.Text);

                    // ✅ Détection de la page active
                    bool isActive = false;
                    if (!string.IsNullOrEmpty(currentPage) && !string.IsNullOrEmpty(menu.Url))
                    {
                        string menuFileName = System.IO.Path.GetFileNameWithoutExtension(menu.Url).ToLower();
                        isActive = currentPage == menuFileName;
                    }

                    string activeClass = isActive ? " active" : "";

                    html.AppendFormat(@"
                    <a href=""{0}"" class=""nav-link{1}"" data-menu=""{2}"">
                        <div style=""width:30px; text-align:center; margin-right:10px;"">
                            <i class=""{3}""></i>
                        </div>
                        <span>{4}</span>
                    </a>", menu.Url, activeClass, menu.Code, menu.Icon, menuText);
                }

                html.Append(@"</li>");
            }

            html.Append(@"</ul>");
            return html.ToString();
        }
        catch (Exception ex)
        {
            return "<div style='color:red;padding:10px;'>Erreur: " + ex.Message + "</div>";
        }
    }

    // ============================================================
    // GÉNÉRATION DE LA TOPBAR HTML
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

            html.Append(@"
            <nav class=""main-header"">
                <ul class=""navbar-nav"">
                    <li class=""nav-item"">
                        <a class=""nav-link"" id=""menuToggle"" role=""button"">
                            <i class=""fas fa-bars""></i>
                        </a>
                    </li>
                </ul>
                <ul class=""navbar-nav"">");

            string langSelector = RenderLanguageSelector();
            if (!string.IsNullOrEmpty(langSelector))
            {
                html.Append(@"
                <li class=""nav-item language-selector-wrapper"" style=""display:flex;align-items:center;margin:0 5px;""><span><i class=""fas fa-globe""></i></span>");
                html.Append(langSelector);
                html.Append(@"</li>");
            }

            html.Append(@"
                <li class=""nav-item"">
                    <span style=""display:flex;align-items:center;gap:6px;font-size:13px;"">
                        <i class=""fas fa-moon""></i>
                        <span style=""font-size:12px;"">" + T("DarkMode") + @"</span>
                    </span>
                    <label class=""switch"">
                        <input type=""checkbox"" id=""toggleDarkMode"">
                        <span class=""slider round""></span>
                    </label>
                </li>");

            if (HasPermission("dashboard"))
            {
                html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link"" id=""notifToggle"" title=""" + T("Notifications") + @""" style=""position:relative;"">
                        <i class=""fas fa-bell""></i>
                        <span class=""badge-notif"" id=""badgeNotif"">3</span>
                    </a>
                    <div class=""dropdown-menu"" id=""notifDropdown"">
                        <span class=""dropdown-header"">3 " + T("Notifications") + @"</span>
                        <div class=""dropdown-divider""></div>
                        <a href=""#"" class=""dropdown-item"">
                            <i class=""fas fa-user-plus text-success mr-2""></i> " + T("NewStudent") + @"
                            <span style=""float: right; color: #6c757d; font-size: 11px;"">" + T("TimeAgo") + @" 23 min</span>
                        </a>
                        <a href=""#"" class=""dropdown-item"">
                            <i class=""fas fa-exclamation-circle text-danger mr-2""></i> " + T("AbsenceReported") + @"
                            <span style=""float: right; color: #6c757d; font-size: 11px;"">" + T("TimeAgo") + @" 1h</span>
                        </a>
                        <a href=""#"" class=""dropdown-item"">
                            <i class=""fas fa-money-bill text-warning mr-2""></i> " + T("PaymentReceived") + @"
                            <span style=""float: right; color: #6c757d; font-size: 11px;"">" + T("TimeAgo") + @" 2h</span>
                        </a>
                    </div>
                </li>");
            }

            html.Append(@"
                <li class=""nav-item"">
                    <a href=""../../../auth/Logout.aspx"" class=""nav-link"" title=""" + T("Logout") + @""">
                        <i class=""fas fa-sign-out-alt""></i>
                    </a>
                </li>");

            html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link"" id=""fullscreenToggle"" title=""" + T("Fullscreen") + @""">
                        <i class=""fas fa-expand-arrows-alt""></i>
                    </a>
                </li>");

            if (isUsersPage && HasPermission("utilisateurs"))
            {
                html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link"" id=""toggleSidebarBtn"" title=""" + T("Settings") + @""" style=""cursor: pointer;"">
                        <i class=""fas fa-cog""></i>
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
            return "<div style='color:red;padding:10px;'>Erreur topbar: " + ex.Message + "</div>";
        }
    }

    // ============================================================
    // GÉNÉRATION DU CONTROL SIDEBAR HTML (paramètres)
    // ============================================================
    public static string RenderControlSidebarHTML()
    {
        try
        {
            var html = new StringBuilder();

            html.Append(@"
            <aside class=""control-sidebar control-sidebar-dark"" id=""controlSidebar""
                style=""position: fixed;top: 0;right: -300px;width: 300px;padding: 20px;height: 100%;background: #343a40;color: #fff;transition: right 0.3s ease-in-out;z-index: 1050;box-shadow: -2px 0 5px rgba(0,0,0,0.2);overflow-y: auto;"">
                <div class=""p-3"">
                    <div style=""display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #4a5259; padding-bottom: 10px; margin-bottom: 15px;"">
                        <h5 style=""margin: 0; color: #fff;"">
                            <i class=""fas fa-cog""></i> " + T("Settings") + @"
                        </h5>
                        <button type=""button"" id=""closeSidebarBtn""
                            style=""background: none; border: none; color: #fff; font-size: 20px; cursor: pointer;"">
                            <i class=""fas fa-times""></i>
                        </button>
                    </div>

                    <div id=""licenceExpirationInfo"" class=""mb-3"" style=""color: #adb5bd; font-size: 0.85em;"">
                        <i class=""fas fa-calendar-alt""></i> " + T("LicenceExpires") + @" :
                        <strong id=""expirationDateStr"">" + GetExpirationDateString() + @"</strong>
                    </div>

                    <div class=""mb-3"" style=""color: #adb5bd; font-size: 0.85em;"">
                        <i class=""fas fa-users""></i> " + T("MaxUsers") + @" :
                        <strong id=""maxUsersCount"">" + GetMaxUsersString() + @"</strong>
                    </div>

                    <hr style=""border-color: #4a5259;"">");

            if (IsSuperAdmin())
            {
                html.Append(@"
                    <div style=""display: flex; flex-direction: column; gap: 10px; padding: 10px;"">
                        <div style=""width: 100%;"">
                            <button type=""button"" id=""btnCheckUpdates"" class=""btn btn-primary""
                                style=""width: 100%; padding: 10px 15px; text-align: center;""
                                onclick=""checkForUpdates()"">
                                <i class=""fas fa-sync-alt""></i> " + T("CheckUpdates") + @"
                            </button>
                        </div>
                        <div style=""width: 100%;"">
                            <button type=""button"" id=""btnBackup"" class=""btn btn-success""
                                style=""width: 100%; padding: 10px 15px; text-align: center;""
                                onclick=""backupDatabase()"">
                                <i class=""fas fa-database""></i> " + T("Backup") + @"
                            </button>
                        </div>
                        <div style=""width: 100%;"">
                            <button type=""button"" id=""btnRestore"" class=""btn btn-warning""
                                style=""width: 100%; padding: 10px 15px; text-align: center;""
                                onclick=""openRestoreModal()"">
                                <i class=""fas fa-undo-alt""></i> " + T("Restore") + @"
                            </button>
                        </div>
                    </div>

                    <hr style=""border-color: #4a5259;"">");
            }

            html.Append(@"
                </div>
            </aside>

            <div id=""sidebarOverlay""
                style=""position: fixed;top: 0;left: 0;width: 100%;height: 100%;background: rgba(0,0,0,0.5);z-index: 1040;display: none;cursor: pointer;"">
            </div>");

            return html.ToString();
        }
        catch (Exception ex)
        {
            return "<div style='color:red;padding:10px;'>Erreur control sidebar: " + ex.Message + "</div>";
        }
    }

    // ============================================================
    // MÉTHODES DE SESSION ET UTILISATEUR
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

    public static int GetUserRole(HttpContext context)
    {
        if (context == null || context.Session == null) return -1;
        object val = context.Session[SK_USERROLE];
        return (val != null) ? Convert.ToInt32(val) : -1;
    }

    public static string GetUsername(HttpContext context)
    {
        if (context == null || context.Session == null) return "Inconnu";
        return context.Session[SK_USERNAME] as string ?? "Inconnu";
    }

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

    public static bool IsSuperAdmin()
    {
        var role = GetUserRoleId();
        return role.HasValue && role.Value == 0;
    }

    public static bool IsAdmin()
    {
        var role = GetUserRoleId();
        return role.HasValue && (role.Value == 0 || role.Value == 1);
    }

    public static bool IsProfessor()
    {
        var role = GetUserRoleId();
        return role.HasValue && role.Value == 3;
    }

    public static bool IsSecretaire()
    {
        var role = GetUserRoleId();
        return role.HasValue && role.Value == 4;
    }

    public static bool IsComptable()
    {
        var role = GetUserRoleId();
        return role.HasValue && role.Value == 5;
    }

    public static string GetRoleName()
    {
        var roleId = GetUserRoleId();
        if (!roleId.HasValue) return "Inconnu";

        switch (roleId.Value)
        {
            case 0: return T("SuperAdmin");
            case 1: return T("Admin");
            case 3: return T("Teacher");
            case 4: return T("Secretary");
            case 5: return T("Accountant");
            default: return T("User");
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
        catch
        {
            return false;
        }
    }

    private static void SetUsername(Page page)
    {
        var session = HttpContext.Current.Session;
        if (session == null || session[SK_USERNAME] == null) return;
        string username = session[SK_USERNAME].ToString().Replace("'", "\\'");
        string script = "var el=document.getElementById('navbarUsername'); if(el){el.innerText='" + username + "';}";
        page.ClientScript.RegisterStartupScript(page.GetType(), "username", script, true);
    }

    private static void SetRolename(Page page)
    {
        string roleName = GetRoleName();
        string script = "var el=document.getElementById('profilUsername'); if(el){el.innerText='" + roleName + "';}";
        page.ClientScript.RegisterStartupScript(page.GetType(), "rolename", script, true);
    }

    private static void ForceLogout(Page page, bool otherPc)
    {
        HttpContext.Current.Session.Clear();
        HttpContext.Current.Session.Abandon();
        string url = otherPc ? "~/auth/Login.aspx?msg=other_pc" : "~/auth/Login.aspx";
        page.Response.Redirect(url, true);
    }

    public static string Version
    {
        get
        {
            var version = ConfigurationManager.AppSettings["Version"];
            return string.IsNullOrEmpty(version) ? "1.0.0" : version;
        }
    }

    public static int GetCurrentAnneeId()
    {
        var session = HttpContext.Current.Session;
        if (session != null && session["ID_ANNEE_ACTIVE"] != null)
        {
            return Convert.ToInt32(session["ID_ANNEE_ACTIVE"]);
        }

        try
        {
            if (string.IsNullOrEmpty(connStr)) return 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                string sql = "SELECT TOP 1 ID FROM RANNEE WHERE CLOTURE = 0 ORDER BY DATE_DEBUT DESC";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    conn.Open();
                    object result = cmd.ExecuteScalar();
                    return result != null ? (int)result : 0;
                }
            }
        }
        catch
        {
            return 0;
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
        DateTime expirationDate;
        int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);

        if (status == LicenceStatus.Valide || status == LicenceStatus.Expiree)
        {
            return expirationDate.ToString("dd/MM/yyyy");
        }
        else if (status == LicenceStatus.Manquante)
        {
            return T("LicenceMissing");
        }
        else
        {
            return T("LicenceInvalid");
        }
    }

    public static string GetMaxUsersString()
    {
        DateTime expirationDate;
        int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);

        if (status == LicenceStatus.Valide || status == LicenceStatus.Expiree)
        {
            return maxUsers.ToString();
        }
        else
        {
            return "0";
        }
    }

    public static bool IsMaxUsersReached()
    {
        DateTime expirationDate;
        int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);

        if (status != LicenceStatus.Valide)
        {
            return true;
        }

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
        catch
        {
            return false;
        }
    }

    public static bool IsLicenceValid()
    {
        DateTime expirationDate;
        int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);
        return status == LicenceStatus.Valide;
    }

    public static SidebarInfo GetSidebarInfo()
    {
        DateTime expirationDate;
        int maxUsers;
        LicenceStatus status = CheckLicence(out expirationDate, out maxUsers);

        string expirationText;
        string maxUsersText;

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
            {
                values.Add(line.Substring(key.Length + 1).Trim());
            }
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
    // INFORMATIONS DE LICENCE (objet complet)
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
        DateTime exp;
        int max;
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

    // ============================================================
    // DÉCONNEXION UNIFIÉE
    // ============================================================
    public static void Logout(HttpContext context)
    {
        if (context == null || context.Session == null) return;

        // Supprimer le token en base si l'utilisateur est connecté
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
            catch { /* ignorer */ }
        }

        // Nettoyer la session
        context.Session.Clear();
        context.Session.Abandon();

        // Supprimer les cookies de session et d'authentification
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

        // En-têtes anti-cache
        context.Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
        context.Response.Cache.SetNoStore();
        context.Response.Cache.SetExpires(DateTime.UtcNow.AddYears(-1));
        context.Response.AppendHeader("Pragma", "no-cache");
        context.Response.AppendHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        context.Response.AppendHeader("Expires", "0");
    }

    // ============================================================
    // MÉTHODES POUR LES CLASSES ET MATIÈRES AUTORISÉES
    // ============================================================

    public static string GetClassesAutorisees()
    {
        var session = HttpContext.Current.Session;
        if (session != null && session["ClassesAutorisees"] != null)
        {
            return session["ClassesAutorisees"].ToString();
        }

        // Si l'utilisateur est SuperAdmin ou Admin, retourner "all"
        if (IsSuperAdmin() || IsAdmin())
        {
            return "all";
        }

        // Pour les professeurs, charger depuis la base
        int? userId = GetCurrentUserId();
        if (userId.HasValue && userId.Value > 0)
        {
            var classes = LoadClassesForProfessor(userId.Value);
            var serializer = new JavaScriptSerializer();
            string json = serializer.Serialize(classes);
            if (session != null) session["ClassesAutorisees"] = json;
            return json;
        }

        return "[]";
    }

    public static string GetMatieresAutorisees()
    {
        var session = HttpContext.Current.Session;
        if (session != null && session["MatieresAutorisees"] != null)
        {
            return session["MatieresAutorisees"].ToString();
        }

        // Si l'utilisateur est SuperAdmin ou Admin, retourner "all"
        if (IsSuperAdmin() || IsAdmin())
        {
            return "all";
        }

        // Pour les professeurs, charger depuis la base
        int? userId = GetCurrentUserId();
        if (userId.HasValue && userId.Value > 0)
        {
            var matieres = LoadMatieresForProfessor(userId.Value);
            var serializer = new JavaScriptSerializer();
            string json = serializer.Serialize(matieres);
            if (session != null) session["MatieresAutorisees"] = json;
            return json;
        }

        return "[]";
    }

    private static List<object> LoadClassesForProfessor(int professeurId)
    {
        var classes = new List<object>();
        try
        {
            if (string.IsNullOrEmpty(connStr)) return classes;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                string sql = @"SELECT DISTINCT c.ID, c.NOM 
                        FROM CLASSES c
                        INNER JOIN MATIERES m ON m.CLASSE_ID = c.ID
                        WHERE m.ENSEIGNANT = @professeurId
                        ORDER BY c.NOM";
                SqlCommand cmd = new SqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@professeurId", professeurId);
                conn.Open();
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        classes.Add(new
                        {
                            ID = reader["ID"].ToString(),
                            NOM = reader["NOM"].ToString()
                        });
                    }
                }
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine("Erreur LoadClassesForProfessor: " + ex.Message);
        }
        return classes;
    }

    private static List<object> LoadMatieresForProfessor(int professeurId)
    {
        var matieres = new List<object>();
        try
        {
            if (string.IsNullOrEmpty(connStr)) return matieres;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                string sql = @"SELECT m.ID, m.NOM, m.COEFFICIENT, m.CLASSE_ID, c.NOM AS CLASSE_NOM
                        FROM MATIERES m
                        INNER JOIN CLASSES c ON m.CLASSE_ID = c.ID
                        WHERE m.ENSEIGNANT = @professeurId
                        ORDER BY c.NOM, m.NOM";
                SqlCommand cmd = new SqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@professeurId", professeurId);
                conn.Open();
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        matieres.Add(new
                        {
                            ID = reader["ID"].ToString(),
                            NOM = reader["NOM"].ToString(),
                            COEFFICIENT = reader["COEFFICIENT"] != DBNull.Value ? Convert.ToDecimal(reader["COEFFICIENT"]) : 1,
                            CLASSE_ID = reader["CLASSE_ID"] != DBNull.Value ? Convert.ToInt32(reader["CLASSE_ID"]) : 0,
                            CLASSE_NOM = reader["CLASSE_NOM"] != DBNull.Value ? reader["CLASSE_NOM"].ToString() : ""
                        });
                    }
                }
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine("Erreur LoadMatieresForProfessor: " + ex.Message);
        }
        return matieres;
    }

    // ============================================================
    // CLASSES PUBLIQUES
    // ============================================================
    public class SidebarInfo
    {
        public string ExpirationDate { get; set; }
        public string MaxUsers { get; set; }
        public bool IsValid { get; set; }
        public bool IsExpired { get; set; }
    }
}