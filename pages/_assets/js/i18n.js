/* ============================================================
   i18n.js — Client-side translation helper
   - Lit window.__I18N__ (injecté par LocalizationHelper côté serveur)
   - Expose t(key, params) pour traduire
   - Fournit applyTranslations() pour les attributs [data-i18n]
   - Notifie les erreurs de clés uniquement en dev
   ============================================================ */
(function () {
    "use strict";

    var dict = window.__I18N__ || {};
    var lang = window.__I18N_LANG__ || "fr";
    var DEV_MODE = (
        window.location.hostname === "localhost" ||
        window.location.hostname === "127.0.0.1"
    );

    /**
     * Traduit une clé.
     * @param {string} key - ex "button.save"
     * @param {object} [params] - ex { name: "Onyx" }
     * @returns {string}
     */
    function t(key, params) {
        if (!key) return "";

        var value = dict[key];

        if (value === undefined || value === null) {
            if (DEV_MODE) console.warn("[i18n] Clé manquante :", key);
            return key; // fallback visible en dev
        }

        if (params && typeof params === "object") {
            value = value.replace(/\{(\w+)\}/g, function (m, name) {
                return params.hasOwnProperty(name) ? params[name] : m;
            });
        }

        return value;
    }

    /**
     * Parcourt le DOM et remplace le contenu des éléments [data-i18n].
     * Gère [data-i18n-attr] pour traduire des attributs (placeholder, title…).
     * Exemples :
     *   <button data-i18n="button.save"></button>
     *   <input data-i18n-attr="placeholder:placeholder.search" />
     */
    function applyTranslations(root) {
        root = root || document;

        // 1) Contenu texte
        var nodes = root.querySelectorAll("[data-i18n]");
        for (var i = 0; i < nodes.length; i++) {
            var el = nodes[i];
            var key = el.getAttribute("data-i18n");
            var val = t(key);
            if (val !== key) el.textContent = val;
        }

        // 2) Attributs (séparateur : "attr:key" ou "attr1:key1;attr2:key2")
        var attrNodes = root.querySelectorAll("[data-i18n-attr]");
        for (var j = 0; j < attrNodes.length; j++) {
            var el2 = attrNodes[j];
            var spec = el2.getAttribute("data-i18n-attr") || "";
            spec.split(";").forEach(function (pair) {
                var parts = pair.split(":");
                if (parts.length !== 2) return;
                var attr = parts[0].trim();
                var k = parts[1].trim();
                var v = t(k);
                if (v !== k) el2.setAttribute(attr, v);
            });
        }
    }

    /**
     * Change la langue courante (redirige avec ?lang=xx).
     */
    function setLanguage(code) {
        if (!code) return;
        try {
            var url = new URL(window.location.href);
            url.searchParams.set("lang", code);
            window.location.href = url.toString();
        } catch (e) {
            window.location.href = window.location.pathname + "?lang=" + encodeURIComponent(code);
        }
    }

    // Auto-apply au chargement
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", function () { applyTranslations(); });
    } else {
        applyTranslations();
    }

    // Expositions
    window.t = t;
    window.applyTranslations = applyTranslations;
    window.setLanguage = setLanguage;
    window.i18n = {
        get lang() { return lang; },
        get dict() { return dict; },
        t: t,
        apply: applyTranslations,
        setLanguage: setLanguage
    };
})();
