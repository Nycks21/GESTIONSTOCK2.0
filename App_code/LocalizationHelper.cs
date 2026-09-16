using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web;
using System.Web.Caching;
using System.Web.Script.Serialization;

/// <summary>
/// Helper de localisation côté serveur.
/// Charge un fichier JSON par langue (LANG/fr.json, LANG/en.json, LANG/mg.json),
/// expose les traductions via GetString(key) et fournit le sélecteur de langue.
/// Compatible C# 4/5 (.NET Framework 4.0).
/// </summary>
public static class LocalizationHelper
{
    // ============================================================
    // Configuration
    // ============================================================
    public static readonly string[] SupportedCultures = { "fr", "en", "mg" };
    public static readonly string[] CultureNames = { "Fr", "En", "Mg" };
    public static readonly string[] CultureFlags = { "🇫🇷", "🇬🇧", "🇲🇬" };

    private const string DEFAULT_CULTURE = "fr";
    private const string SK_CULTURE = "CurrentCulture";
    private const string CK_CULTURE = "UserLanguage";
    private const string CACHE_KEY_PREFIX = "LocalizationHelper_Lang_";
    private const string LANG_FOLDER = "~/LANG/";

    // ============================================================
    // APPLICATION DE LA LANGUE AU THREAD COURANT
    // ============================================================
    public static void HandleLanguage()
    {
        try
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null) return;

            string culture = null;
            string fromQuery = ctx.Request.QueryString["lang"];

            if (!string.IsNullOrEmpty(fromQuery))
                culture = NormalizeCulture(fromQuery);

            if (culture == null && ctx.Session != null)
            {
                object sessionValue = ctx.Session[SK_CULTURE];
                if (sessionValue is string)
                {
                    string s = (string)sessionValue;
                    if (!string.IsNullOrEmpty(s)) culture = NormalizeCulture(s);
                }
            }

            if (culture == null)
            {
                try
                {
                    HttpCookie cookie = ctx.Request.Cookies[CK_CULTURE];
                    if (cookie != null && !string.IsNullOrEmpty(cookie.Value))
                        culture = NormalizeCulture(cookie.Value);
                }
                catch { }
            }

            if (culture == null) culture = DEFAULT_CULTURE;

            if (!string.IsNullOrEmpty(fromQuery) && NormalizeCulture(fromQuery) != null)
            {
                if (ctx.Session != null) ctx.Session[SK_CULTURE] = culture;
                try
                {
                    HttpCookie cookie = new HttpCookie(CK_CULTURE, culture);
                    cookie.Expires = DateTime.Now.AddYears(1);
                    cookie.HttpOnly = true;
                    cookie.Path = "/";
                    ctx.Response.Cookies.Add(cookie);
                }
                catch { }
            }

            System.Globalization.CultureInfo ci =
                new System.Globalization.CultureInfo(culture);
            System.Threading.Thread.CurrentThread.CurrentCulture = ci;
            System.Threading.Thread.CurrentThread.CurrentUICulture = ci;
        }
        catch { }
    }

    // ============================================================
    // Culture courante (QueryString > Session > Cookie > défaut)
    // ============================================================
    public static string CurrentCultureCode
    {
        get
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null) return DEFAULT_CULTURE;

            string fromQuery = ctx.Request.QueryString["lang"];
            if (!string.IsNullOrEmpty(fromQuery))
            {
                string normalized = NormalizeCulture(fromQuery);
                if (normalized != null)
                {
                    if (ctx.Session != null) ctx.Session[SK_CULTURE] = normalized;
                    try
                    {
                        HttpCookie cookie = new HttpCookie(CK_CULTURE, normalized);
                        cookie.Expires = DateTime.Now.AddYears(1);
                        cookie.HttpOnly = true;
                        cookie.Path = "/";
                        ctx.Response.Cookies.Add(cookie);
                    }
                    catch { }
                    return normalized;
                }
            }

            if (ctx.Session != null)
            {
                object sessionValue = ctx.Session[SK_CULTURE];
                if (sessionValue is string)
                {
                    string s = (string)sessionValue;
                    if (!string.IsNullOrEmpty(s)) return s;
                }
            }

            try
            {
                HttpCookie cookie = ctx.Request.Cookies[CK_CULTURE];
                if (cookie != null && !string.IsNullOrEmpty(cookie.Value))
                {
                    string normalized = NormalizeCulture(cookie.Value);
                    if (normalized != null)
                    {
                        if (ctx.Session != null) ctx.Session[SK_CULTURE] = normalized;
                        return normalized;
                    }
                }
            }
            catch { }

            return DEFAULT_CULTURE;
        }
    }

    private static string NormalizeCulture(string raw)
    {
        if (string.IsNullOrEmpty(raw)) return null;
        string code = raw.Trim().ToLowerInvariant();
        int dash = code.IndexOf('-');
        if (dash > 0) code = code.Substring(0, dash);

        for (int i = 0; i < SupportedCultures.Length; i++)
            if (SupportedCultures[i] == code) return code;

        return null;
    }

    // ============================================================
    // Récupération des traductions
    // ============================================================
    public static string GetString(string key)
    {
        if (string.IsNullOrEmpty(key)) return key;

        string current = CurrentCultureCode;

        // 1) Langue courante
        Dictionary<string, string> dict = LoadTranslationsFor(current);
        if (dict != null && dict.ContainsKey(key))
            return dict[key];

        // 2) Fallback français
        if (current != DEFAULT_CULTURE)
        {
            Dictionary<string, string> fallback = LoadTranslationsFor(DEFAULT_CULTURE);
            if (fallback != null && fallback.ContainsKey(key))
                return fallback[key];
        }

        // 3) Clé introuvable → retourne la clé (visible en dev)
        return key;
    }

    public static string GetString(string key, params object[] args)
    {
        string template = GetString(key);
        if (args == null || args.Length == 0) return template;

        try { return string.Format(template, args); }
        catch { return template; }
    }

    /// <summary>
    /// Retourne le dictionnaire de la langue courante (utile pour RenderDictionaryScript).
    /// </summary>
    public static Dictionary<string, string> GetCurrentDictionary()
    {
        return LoadTranslationsFor(CurrentCultureCode);
    }

    // ============================================================
    // Injection du dictionnaire dans la page
    // ============================================================
    public static string RenderDictionaryScript()
    {
        try
        {
            Dictionary<string, string> dict = GetCurrentDictionary();
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            string json = serializer.Serialize(dict);

            return
                "<script>" +
                "window.__I18N_LANG__=" + serializer.Serialize(CurrentCultureCode) + ";" +
                "window.__I18N__=" + json + ";" +
                "</script>";
        }
        catch
        {
            return "<script>window.__I18N__={};window.__I18N_LANG__='fr';</script>";
        }
    }

    // ============================================================
    // Sélecteur de langue (HTML)
    // ============================================================
    public static string RenderLanguageSelector()
    {
        string current = CurrentCultureCode;
        StringBuilder sb = new StringBuilder();

        sb.Append(@"<div class=""lang-selector-modern"">");
        sb.Append(@"<i class=""fas fa-globe lang-selector-icon""></i>");
        sb.Append(@"<select id=""langSelect"" class=""lang-select-modern"" aria-label=""Language"">");

        for (int i = 0; i < SupportedCultures.Length; i++)
        {
            string code = SupportedCultures[i];
            string flag = i < CultureFlags.Length ? CultureFlags[i] + " " : "";
            string name = i < CultureNames.Length ? CultureNames[i] : code;
            string selected = (code == current) ? " selected" : "";

            sb.AppendFormat(
                @"<option value=""{0}""{1}>{2}{3}</option>",
                HttpUtility.HtmlAttributeEncode(code),
                selected,
                HttpUtility.HtmlEncode(flag),
                HttpUtility.HtmlEncode(name));
        }

        sb.Append(@"</select></div>");
        return sb.ToString();
    }

    // ============================================================
    // Chargement + cache d'un fichier de langue
    // ============================================================
    /// <summary>
    /// Charge le dictionnaire d'une langue depuis LANG/{culture}.json.
    /// Cache ASP.NET 10 min avec dépendance au fichier (invalidation auto).
    /// </summary>
    private static Dictionary<string, string> LoadTranslationsFor(string culture)
    {
        HttpContext ctx = HttpContext.Current;
        if (ctx == null) return new Dictionary<string, string>();

        string cacheKey = CACHE_KEY_PREFIX + culture;

        // Tentative depuis le cache
        Dictionary<string, string> cached = ctx.Cache[cacheKey] as Dictionary<string, string>;
        if (cached != null) return cached;

        string path = null;
        try { path = ctx.Server.MapPath(LANG_FOLDER + culture + ".json"); }
        catch { }

        if (string.IsNullOrEmpty(path) || !File.Exists(path))
            return new Dictionary<string, string>();

        try
        {
            string json = File.ReadAllText(path, Encoding.UTF8);
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Dictionary<string, string> data =
                serializer.Deserialize<Dictionary<string, string>>(json);

            if (data == null) data = new Dictionary<string, string>();

            // Cache 10 min avec dépendance au fichier
            ctx.Cache.Insert(
                cacheKey,
                data,
                new CacheDependency(path),
                DateTime.Now.AddMinutes(10),
                Cache.NoSlidingExpiration);

            return data;
        }
        catch
        {
            return new Dictionary<string, string>();
        }
    }
}
