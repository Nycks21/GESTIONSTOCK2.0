﻿using System;
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

    // ============================================================
    // ✅ CSRF — Constantes
    // ============================================================
    private const string SK_CSRF_TOKEN = "CSRF_TOKEN";
    private const string CSRF_HEADER_NAME = "X-CSRF-Token";

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
    // ✅ CSRF PROTECTION — Token, validation, meta tag
    // ============================================================

    /// <summary>
    /// Retourne le token CSRF de la session courante, en le créant si absent.
    /// Le token = 32 octets aléatoires (RNG cryptographique) en Base64 URL-safe.
    /// Durée de vie = celle de la session (pas de rotation).
    /// </summary>
    public static string GetOrCreateCsrfToken()
    {
        var session = HttpContext.Current != null ? HttpContext.Current.Session : null;
        if (session == null) return "";

        if (session[SK_CSRF_TOKEN] == null)
        {
            session[SK_CSRF_TOKEN] = GenerateCsrfToken();
        }
        return session[SK_CSRF_TOKEN].ToString();
    }

    /// <summary>
    /// Génère un token aléatoire cryptographiquement sûr.
    /// </summary>
    private static string GenerateCsrfToken()
    {
        byte[] buffer = new byte[32];
        using (var rng = new RNGCryptoServiceProvider())
        {
            rng.GetBytes(buffer);
        }
        // Base64 URL-safe (évite + / = qui gênent dans les headers)
        return Convert.ToBase64String(buffer)
            .Replace("+", "-")
            .Replace("/", "_")
            .Replace("=", "");
    }

    /// <summary>
    /// Vérifie que le header X-CSRF-Token correspond au token stocké en session.
    /// Retourne false si absent ou invalide.
    /// </summary>
    public static bool ValidateCsrfToken(HttpContext context)
    {
        if (context == null || context.Session == null) return false;

        string sessionToken = context.Session[SK_CSRF_TOKEN] as string;
        if (string.IsNullOrEmpty(sessionToken))
        {
            LogAuthError("ValidateCsrfToken: aucun token en session");
            return false;
        }

        // Le header peut arriver en "X-CSRF-Token" ou "HTTP_X_CSRF_TOKEN"
        string headerToken = context.Request.Headers[CSRF_HEADER_NAME];
        if (string.IsNullOrEmpty(headerToken))
            headerToken = context.Request.Headers["HTTP_X_CSRF_TOKEN"];

        if (string.IsNullOrEmpty(headerToken))
        {
            LogAuthError("ValidateCsrfToken: aucun header X-CSRF-Token");
            return false;
        }

        // Comparaison à temps constant (anti timing-attack)
        return FixedTimeEquals(sessionToken, headerToken);
    }

    /// <summary>
    /// Comparaison de chaînes à temps constant.
    /// Évite les attaques par mesure de temps (timing attacks).
    /// </summary>
    private static bool FixedTimeEquals(string a, string b)
    {
        if (a == null || b == null) return false;
        if (a.Length != b.Length) return false;

        int diff = 0;
        for (int i = 0; i < a.Length; i++)
        {
            diff |= a[i] ^ b[i];
        }
        return diff == 0;
    }

    /// <summary>
    /// Vérifie que la requête provient d'une origine de confiance
    /// (Origin ou Referer doit pointer vers le host courant).
    /// Défense en profondeur complémentaire au token.
    /// </summary>
    public static bool ValidateOrigin(HttpContext context)
    {
        if (context == null || context.Request == null) return false;

        string host = context.Request.Url != null ? context.Request.Url.Host : null;
        if (string.IsNullOrEmpty(host)) return false;

        string origin = context.Request.Headers["Origin"];
        if (!string.IsNullOrEmpty(origin))
        {
            try
            {
                var uri = new Uri(origin);
                return string.Equals(uri.Host, host, StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        string referer = context.Request.Headers["Referer"];
        if (!string.IsNullOrEmpty(referer))
        {
            try
            {
                var uri = new Uri(referer);
                return string.Equals(uri.Host, host, StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        // Ni Origin ni Referer : suspect en POST
        LogAuthError("ValidateOrigin: ni Origin ni Referer");
        return false;
    }

    /// <summary>
    /// Garde-fou unifié pour les handlers mutateurs :
    ///   1. Session valide (RequireApiAuth)
    ///   2. Token CSRF valide
    ///   3. Origin / Referer de confiance
    /// À utiliser à la place de RequireApiAuth dans TOUS les handlers
    /// qui font des actions mutantes (POST/DELETE/PUT).
    /// </summary>
    public static bool RequireCsrfSafePost(HttpContext context, int minRole = -1)
    {
        if (!RequireApiAuth(context, minRole)) return false;
        if (!ValidateCsrfToken(context)) return false;
        if (!ValidateOrigin(context)) return false;
        return true;
    }

    /// <summary>
    /// Injecte le token CSRF dans le HTML sous forme de meta tag.
    /// À appeler dans le &lt;head&gt; de chaque page .aspx :
    ///   &lt;%= AuthHelper.RenderCsrfMetaTag() %&gt;
    /// </summary>
    public static string RenderCsrfMetaTag()
    {
        try
        {
            string token = GetOrCreateCsrfToken();
            return "<meta name=\"csrf-token\" content=\"" +
                   HttpUtility.HtmlAttributeEncode(token) + "\">";
        }
        catch (Exception ex)
        {
            LogAuthError("RenderCsrfMetaTag: " + ex.Message);
            return "";
        }
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
    // (Text et Section = clés i18n, résolues par LocalizationHelper)
    // ============================================================
    public static readonly List<MenuItem> AllMenus = new List<MenuItem>
    {
        new MenuItem { Code = "accueil",      Text = "menu.accueil",      Url = "/pages/accueil/index.aspx",                                 Icon = "fas fa-chalkboard",     Section = "section.accueil",        Order = 1  },
        new MenuItem { Code = "unites",       Text = "menu.unites",       Url = "/pages/parametres/unites/unites.aspx",                      Icon = "fas fa-ruler",          Section = "section.parametres",     Order = 2  },
        new MenuItem { Code = "categories",   Text = "menu.categories",   Url = "/pages/parametres/categories/categories.aspx",              Icon = "fas fa-tags",           Section = "section.parametres",     Order = 3  },
        new MenuItem { Code = "fournisseurs", Text = "menu.fournisseurs", Url = "/pages/parametres/fournisseurs/fournisseurs.aspx",          Icon = "fas fa-truck",          Section = "section.parametres",     Order = 4  },
        new MenuItem { Code = "emplacements", Text = "menu.emplacements", Url = "/pages/parametres/emplacements/emplacements.aspx",          Icon = "fas fa-map-marker-alt", Section = "section.parametres",     Order = 5  },
        new MenuItem { Code = "articles",     Text = "menu.articles",     Url = "/pages/modules/articles/articles.aspx",                     Icon = "fas fa-boxes",          Section = "section.mouvements",     Order = 6  },
        new MenuItem { Code = "entrees",      Text = "menu.entrees",      Url = "/pages/modules/entrees/entrees.aspx",                       Icon = "fas fa-arrow-down",     Section = "section.mouvements",     Order = 7  },
        new MenuItem { Code = "sorties",      Text = "menu.sorties",      Url = "/pages/modules/sorties/sorties.aspx",                       Icon = "fas fa-arrow-up",       Section = "section.mouvements",     Order = 8  },
        new MenuItem { Code = "stock",        Text = "menu.stock",        Url = "/pages/modules/stock/stock.aspx",                           Icon = "fas fa-warehouse",      Section = "section.mouvements",     Order = 9  },
        new MenuItem { Code = "saisies",      Text = "menu.saisies",      Url = "/pages/demandes/saisie/saisies.aspx",                       Icon = "fas fa-file-alt",       Section = "section.demandes",       Order = 10 },
        new MenuItem { Code = "accuses",      Text = "menu.accuses",      Url = "/pages/demandes/accuse/accuses.aspx",                       Icon = "fas fa-check-circle",   Section = "section.demandes",       Order = 11 },
        new MenuItem { Code = "exploitation", Text = "menu.exploitation", Url = "/pages/exploitations/exp/exploitations.aspx",               Icon = "fas fa-chart-bar",      Section = "section.rapports",       Order = 12 },
        new MenuItem { Code = "resetpwd",     Text = "menu.resetpwd",     Url = "/pages/administrations/reset/resetpwd.aspx",                Icon = "fas fa-key",            Section = "section.administration", Order = 13 },
        new MenuItem { Code = "utilisateurs", Text = "menu.utilisateurs", Url = "/pages/administrations/utilisateur/utilisateur.aspx",       Icon = "fas fa-user-cog",       Section = "section.administration", Order = 14 },
        new MenuItem { Code = "requetes",     Text = "menu.requetes",     Url = "/pages/administrations/requete/requetes.aspx",              Icon = "fas fa-terminal",       Section = "section.administration", Order = 15 },
    };

    // ============================================================
    // MAPPINGS UI POUR LA GÉNÉRATION DYNAMIQUE DES PERMISSIONS
    // ============================================================

    /// <summary>
    /// Mapping Code MenuItem → id HTML de la checkbox.
    /// Doit rester synchronisé avec CHECKBOX_ID_MAP dans config.js.
    /// </summary>
    public static readonly Dictionary<string, string> CheckboxIdByCode = new Dictionary<string, string>
    {
        { "accueil",      "permDashboard"    },
        { "unites",       "permUnites"       },
        { "categories",   "permCategories"   },
        { "fournisseurs", "permFournisseurs" },
        { "emplacements", "permEmplacements" },
        { "articles",     "permArticles"     },
        { "entrees",      "permEntrees"      },
        { "sorties",      "permSorties"      },
        { "stock",        "permStock"        },
        { "saisies",      "permSaisies"      },
        { "accuses",      "permAccuses"      },
        { "exploitation", "permExploitation" },
        { "resetpwd",     "permResetpwd"     },
        { "utilisateurs", "permUser"         },
        { "requetes",     "permRequetes"     }
    };

    /// <summary>
    /// Mapping Section i18n → icône FontAwesome (en-tête de bloc).
    /// </summary>
    private static readonly Dictionary<string, string> SectionIcons = new Dictionary<string, string>
    {
        { "section.accueil",        "fas fa-chalkboard"   },
        { "section.parametres",     "fas fa-sliders-h"    },
        { "section.mouvements",     "fas fa-exchange-alt" },
        { "section.demandes",       "fas fa-inbox"        },
        { "section.rapports",       "fas fa-chart-bar"    },
        { "section.administration", "fas fa-shield-alt"   }
    };

    /// <summary>
    /// Mapping Code MenuItem → emoji cosmétique (affiché avant le libellé).
    /// </summary>
    private static readonly Dictionary<string, string> EmojiByCode = new Dictionary<string, string>
    {
        { "accueil",      "📊" }, { "unites",       "📏" },
        { "categories",   "📅" }, { "fournisseurs", "📄" },
        { "emplacements", "📦" }, { "articles",     "👥" },
        { "entrees",      "📆" }, { "sorties",      "⏰" },
        { "stock",        "🛒" }, { "saisies",      "✏️" },
        { "accuses",      "🎵" }, { "exploitation", "🚪" },
        { "resetpwd",     "🔑" }, { "utilisateurs", "📖" },
        { "requetes",     "💻" }
    };

    /// <summary>
    /// Retourne l'id HTML d'une checkbox à partir du Code MenuItem.
    /// Fallback : "perm_" + code.
    /// </summary>
    public static string GetCheckboxId(string menuCode)
    {
        if (string.IsNullOrEmpty(menuCode)) return "";
        return CheckboxIdByCode.ContainsKey(menuCode)
            ? CheckboxIdByCode[menuCode]
            : "perm_" + menuCode;
    }

    // ============================================================
    // ✅ GÉNÉRATION DYNAMIQUE DU BLOC PERMISSIONS (UI)
    // ============================================================
    public static string RenderPermissionsUI()
    {
        try
        {
            var html = new StringBuilder();
            html.Append(@"<div class=""perm-sections"">");

            var bySection = AllMenus
                .GroupBy(m => m.Section)
                .OrderBy(g => g.Min(m => m.Order));

            foreach (var grp in bySection)
            {
                string sectionKey = grp.Key;
                string sectionIcon = SectionIcons.ContainsKey(sectionKey)
                    ? SectionIcons[sectionKey]
                    : "fas fa-circle";

                html.AppendFormat(
                    @"<div class=""perm-section"">
                        <div class=""perm-section-header"">
                            <i class=""{0}""></i>
                            <span data-i18n=""{1}"">{2}</span>
                        </div>
                        <div class=""perm-section-body"">",
                    sectionIcon,
                    HttpUtility.HtmlAttributeEncode(sectionKey),
                    HttpUtility.HtmlEncode(T(sectionKey)));

                foreach (var menu in grp.OrderBy(m => m.Order))
                {
                    if (menu.Code == "requetes" && !IsSuperAdmin())
                        continue;

                    string checkboxId = GetCheckboxId(menu.Code);
                    string emoji = EmojiByCode.ContainsKey(menu.Code)
                        ? EmojiByCode[menu.Code]
                        : "";

                    html.AppendFormat(
                        @"<label class=""perm-item"" for=""{0}"">
                            <input type=""checkbox"" id=""{0}"" value=""{1}"">
                            <span class=""perm-emoji"">{2}</span>
                            <span data-i18n=""{3}"">{4}</span>
                          </label>",
                        HttpUtility.HtmlAttributeEncode(checkboxId),
                        HttpUtility.HtmlAttributeEncode(menu.Code),
                        emoji,
                        HttpUtility.HtmlAttributeEncode(menu.Text),
                        HttpUtility.HtmlEncode(T(menu.Text)));
                }

                html.Append(@"</div></div>");
            }

            html.Append(@"</div>");
            return html.ToString();
        }
        catch (Exception ex)
        {
            return "<div style='color:red;padding:10px;'>Erreur permissions: " +
                   HttpUtility.HtmlEncode(ex.Message) + "</div>";
        }
    }

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

            string logoUrl = "";
            try
            {
                logoUrl = VirtualPathUtility.ToAbsolute("~/img/Logo4.png");
            }
            catch
            {
                logoUrl = "/img/Logo4.png";
            }

            html.AppendFormat(@"
                <a href=""#"" class=""brand-link"" onclick=""loadDashboard();return false;"">
                    <img src=""{0}"" alt=""Logo"" class=""brand-image"">
                    <span class=""brand-text"">Gestion de Stock</span>
                </a>", logoUrl);

            html.Append(RenderUserProfileHTML());

            html.Append(@"<div class=""sidebar-nav-modern"">");

            var orderedSections = sections
                .OrderBy(kv => kv.Value.Min(m => m.Order));

            foreach (var section in orderedSections)
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

            html.Append(@"
        <nav class=""main-header modern-topbar"">
            <ul class=""navbar-nav topbar-left"">
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""menuToggle"" role=""button"" title=""Menu"">
                        <i class=""fas fa-bars""></i>
                    </a>
                </li>
            </ul>");

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

            html.Append(@"<ul class=""navbar-nav topbar-right"">");

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

            html.Append(@"
                <li class=""nav-item"">
                    <label class=""switch switch-modern"" for=""toggleDarkMode"" title=""Mode sombre"">
                        <input type=""checkbox"" id=""toggleDarkMode"">
                        <span class=""slider-modern round""></span>
                    </label>
                </li>");

            if (HasPermission("requetes"))
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

            html.Append(@"
                <li class=""nav-item"">
                    <a href=""../../../auth/Logout.aspx"" class=""nav-link topbar-icon-btn topbar-logout"" title=""" + T("Logout") + @""">
                        <i class=""fas fa-sign-out-alt""></i>
                    </a>
                </li>");

            html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""fullscreenToggle"" title=""" + T("Fullscreen") + @""">
                        <i class=""fas fa-expand-arrows-alt""></i>
                    </a>
                </li>");

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

            // ✅ Injection du dictionnaire i18n + meta CSRF
            html.Append(LocalizationHelper.RenderDictionaryScript());
            html.Append(RenderCsrfMetaTag());

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

    public static string GetUserFullName()
    {
        int? userId = GetCurrentUserId();
        if (!userId.HasValue || userId.Value <= 0) return "";

        try
        {
            if (string.IsNullOrEmpty(connStr)) return "";

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (SqlCommand cmd = new SqlCommand(
                    "SELECT NOM FROM USERS WHERE IDUSER = @id", conn))
                {
                    cmd.Parameters.AddWithValue("@id", userId.Value);
                    object result = cmd.ExecuteScalar();
                    if (result != null && result != DBNull.Value)
                        return result.ToString().Trim();
                }
            }
        }
        catch (Exception ex)
        {
            LogAuthError("GetUserFullName exception: " + ex.Message);
        }
        return "";
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
    public static bool IsAdmin() { var r = GetUserRoleId(); return r.HasValue && r.Value == 1; }
    public static bool IsUser() { var r = GetUserRoleId(); return r.HasValue && r.Value == 2; }
    public static bool IsLogisticien() { var r = GetUserRoleId(); return r.HasValue && r.Value == 3; }
    public static bool IsComptable() { var r = GetUserRoleId(); return r.HasValue && r.Value == 4; }

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
