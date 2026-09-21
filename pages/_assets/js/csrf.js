/* ============================================================
   csrf.js — Protection CSRF côté client
   ------------------------------------------------------------
   Ce fichier fournit :
     1) getCsrfToken()   → lit le token depuis <meta name="csrf-token">
     2) csrfFetch()      → wrapper de fetch() qui ajoute automatiquement
                            le header X-CSRF-Token pour POST/PUT/DELETE/PATCH
     3) patchGlobalFetch() → remplace window.fetch par la version sécurisée

   ⚠️ IMPORTANT : la fonction fetch NATIVE est capturée dès le chargement
   de ce fichier, AVANT que global.js (ou tout autre module) ne la patche.
   Cela évite toute boucle infinie entre wrappers.
   ============================================================ */
(function () {
    "use strict";

    // ============================================================
    // ⚠️ CAPTURER LA VRAIE fetch NATIVE AVANT TOUT PATCH
    // ------------------------------------------------------------
    // Doit être la toute première instruction du fichier.
    // Cette référence ne sera JAMAIS modifiée par les patchs ultérieurs.
    // ============================================================
    var __nativeFetch = window.fetch.bind(window);

    // ============================================================
    // 1) Récupération du token depuis le DOM
    // ============================================================
    function getCsrfToken() {
        var meta = document.querySelector('meta[name="csrf-token"]');
        return meta ? (meta.getAttribute("content") || "") : "";
    }

    // ============================================================
    // 2) Détection des méthodes HTTP mutantes
    // ============================================================
    var MUTATING_METHODS = ["POST", "PUT", "DELETE", "PATCH"];

    function isMutatingMethod(method) {
        return MUTATING_METHODS.indexOf((method || "GET").toUpperCase()) !== -1;
    }

    // ============================================================
    // 3) Normalisation des headers en objet simple
    // ============================================================
    function normalizeHeaders(headers) {
        if (!headers) return {};

        if (typeof Headers !== "undefined" && headers instanceof Headers) {
            var obj = {};
            headers.forEach(function (value, name) {
                obj[name] = value;
            });
            return obj;
        }

        if (Array.isArray(headers)) {
            var obj2 = {};
            headers.forEach(function (pair) {
                if (Array.isArray(pair) && pair.length === 2) {
                    obj2[pair[0]] = pair[1];
                }
            });
            return obj2;
        }

        if (typeof headers === "object") {
            return Object.assign({}, headers);
        }

        return {};
    }

    // ============================================================
    // 4) csrfFetch — wrapper sécurisé
    // ------------------------------------------------------------
    // ⚠️ Utilise __nativeFetch (et NON fetch()) pour éviter les boucles
    //    infinies avec les autres modules qui patchent window.fetch
    //    (ex. global.js pour la correction Mixed-Content).
    // ============================================================
    function csrfFetch(url, options) {
        options = options || {};

        var method = (options.method || "GET").toUpperCase();
        var headers = normalizeHeaders(options.headers);

        if (isMutatingMethod(method)) {
            var token = getCsrfToken();
            if (token) {
                if (!headers["X-CSRF-Token"] && !headers["x-csrf-token"]) {
                    headers["X-CSRF-Token"] = token;
                }
            } else {
                if (window.console && console.warn) {
                    console.warn("[csrf] Aucun token CSRF trouvé dans le <head>");
                }
            }
        }

        if (options.credentials === undefined) {
            options.credentials = "same-origin";
        }

        var finalOptions = Object.assign({}, options, { headers: headers });

        // ✅ APPEL À LA fetch NATIVE, PAS window.fetch
        return __nativeFetch(url, finalOptions);
    }

    // ============================================================
    // 5) patchGlobalFetch — remplace window.fetch par csrfFetch
    // ============================================================
    function patchGlobalFetch() {
        if (window.__csrfPatched) {
            return;
        }

        var currentFetch = window.fetch;

        window.fetch = function (url, options) {
            return csrfFetch(url, options);
        };

        // Conserver une référence pour debug
        window.__originalFetch = currentFetch;
        window.__nativeFetch = __nativeFetch;
        window.__csrfPatched = true;
    }

    // ============================================================
    // 6) Exposition globale
    // ============================================================
    window.getCsrfToken = getCsrfToken;
    window.csrfFetch = csrfFetch;
    window.patchGlobalFetch = patchGlobalFetch;

})();
