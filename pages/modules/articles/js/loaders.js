// ============================================================
// CHARGEMENT DES DONNÉES – ARTICLES + i18n
// ============================================================

function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return "0";
    return Number(value).toFixed(decimals || 0);
}

// ============================================================
// RÉSOLUTION DU LIBELLÉ D'UNITÉ
// Priorité : UNITE_NOM (serveur) → lookup par ID → UNITE → UNITE_CODE → UNITE_SYMBOLE
// ============================================================
function resolveUniteLabel(article) {
    if (!article) return '';

    // 1) Le serveur fournit explicitement le NOM
    if (article.UNITE_NOM) return article.UNITE_NOM;

    // 2) Champ historique "UNITE" qui contenait déjà le NOM
    if (article.UNITE) return article.UNITE;

    // 3) Lookup par ID dans AppState.unites (chargé via loadDropdowns)
    if (article.UNITE_MESURE_ID &&
        typeof AppState !== 'undefined' &&
        AppState.unites && AppState.unites.length) {
        var target = String(article.UNITE_MESURE_ID);
        for (var i = 0; i < AppState.unites.length; i++) {
            var u = AppState.unites[i];
            if (u && String(u.ID) === target) {
                return u.NOM || u.CODE || '';
            }
        }
    }

    // 4) Derniers recours (rétrocompatibilité)
    return article.UNITE_CODE || article.UNITE_SYMBOLE || '';
}

// Sécurité : garantir que AppState existe
if (typeof window.AppState === "undefined") {
    window.AppState = {
        articles: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
        sortField: "NOM",
        sortOrder: "ASC",
        filters: { search: "", category: "", status: "" },
        editingId: null,
        categories: [],
        fournisseurs: [],
        unites: [],
        emplacements: [],
    };
}

async function loadArticles(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();

    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search || "",
            category: AppState.filters.category || "",
            status: AppState.filters.status || "",
            sort: AppState.sortField,
            order: AppState.sortOrder,
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + "?" + params.toString();
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.articles = data.Articles || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(
                data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0,
            );
            renderArticlesTable(AppState.articles);
            createPaginationControls(AppState.totalPages);
            loadArticleStats();
        } else {
            showToast(_t('message.error'), data.message || _t('articles.msg.load_error'), 'error');
        }
    } catch (e) {
        showToast(_t('message.error'), e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadArticleStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        if (!resp.ok) throw new Error("HTTP " + resp.status);
        var data = await resp.json();
        if (data.success) {
            document.getElementById("statTotal").textContent = data.total != null ? data.total : 0;
            document.getElementById("statNormal").textContent = data.normal != null ? data.normal : 0;
            document.getElementById("statAlerte").textContent = data.alerte != null ? data.alerte : 0;
            document.getElementById("statRupture").textContent = data.rupture != null ? data.rupture : 0;
        } else {
            console.warn("Stats API returned success=false:", data.message);
        }
    } catch (e) {
        console.error("Erreur stats:", e);
        showToast(_t('message.error'), _t('articles.msg.stats_error'), 'error');
    }
}

async function loadDropdownsArticle() {
    // Catégories
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.CATEGORIES;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.categories = data.Categories || [];
            populateSelect("articleCategorie", AppState.categories, "ID", "NOM", true, _t('articles.modal.categorie_select'));
            populateSelect("category-filter", AppState.categories, "ID", "NOM", true, _t('articles.filter.all_categories'));
        }
    } catch (e) { /* ignore */ }

    // Fournisseurs
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.FOURNISSEURS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.fournisseurs = data.Fournisseurs || [];
            populateSelect("articleFournisseur", AppState.fournisseurs, "ID", "NOM", true, _t('articles.modal.fournisseur_none'));
        }
    } catch (e) { /* ignore */ }

    // Unités — textKey = "NOM" → affiche le libellé complet dans le select
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.UNITES;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.unites = data.Unites || [];
            populateSelect("articleUnite", AppState.unites, "ID", "NOM", true, _t('articles.modal.unite_select'));
        }
    } catch (e) { /* ignore */ }

    // Emplacements
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.EMPLACEMENTS + "?pageSize=999999";
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.emplacements = data.Emplacements || [];
            populateSelect("articleEmplacement", AppState.emplacements, "ID", "NOM", true, _t('articles.modal.emplacement_select'));
        }
    } catch (e) { /* ignore */ }
}

// ─── POPULATE SELECT ───
function populateSelect(selectId, data, valueKey, textKey, addEmpty, emptyText) {
    var select = document.getElementById(selectId);
    if (!select) return;
    var currentValue = select.value;
    select.innerHTML = "";
    if (addEmpty) {
        var opt = document.createElement("option");
        opt.value = "";
        opt.textContent = emptyText || _t('articles.modal.select_default');
        select.appendChild(opt);
    }
    data.forEach(function (item) {
        var opt = document.createElement("option");
        opt.value = item[valueKey];
        opt.textContent = item[textKey];
        select.appendChild(opt);
    });
    if (currentValue) {
        var exists = false;
        for (var i = 0; i < select.options.length; i++) {
            if (select.options[i].value == currentValue) {
                exists = true;
                break;
            }
        }
        if (exists) select.value = currentValue;
    }
}

// ─── FORMATAGE DATE ───
function formatDateValue(value, includeTime) {
    if (value === null || value === undefined || value === "") return "-";
    var date = null;
    if (typeof value === "string") {
        var str = value.trim();
        if (!str) return "-";
        var msMatch = str.match(/-?\d+/);
        if (str.indexOf("/Date(") !== -1 && msMatch) {
            date = new Date(parseInt(msMatch[0], 10));
        } else {
            date = new Date(str);
        }
    } else if (value instanceof Date) {
        date = value;
    } else {
        date = new Date(value);
    }
    if (!date || isNaN(date.getTime())) return "-";
    var options = includeTime
        ? { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }
        : { day: "2-digit", month: "2-digit", year: "numeric" };
    return date.toLocaleString("fr-FR", options);
}

// ─── RENDU DU TABLEAU ───
function renderArticlesTable(articles) {
    var tbody = document.getElementById("articlesTableBody");
    if (!tbody) return;
    if (!articles || !articles.length) {
        tbody.innerHTML = '<tr><td colspan="11" class="text-center">' + _t('articles.msg.no_data') + '</td></tr>';
        document.getElementById("resultsCounter").textContent = _t('articles.counter').replace('{n}', 0);
        return;
    }

    var html = "";
    articles.forEach(function (a) {
        var statutStock = (a.STATUT_STOCK || "normal").toLowerCase();
        var isActive = !!a.ACTIVE;

        // ─── BADGE STATUT STOCK ───
        var statutBadge = (function () {
            var baseStyle =
                'display:inline-flex;align-items:center;gap:5px;' +
                'padding:5px 12px;border-radius:20px;' +
                'font-size:11.5px;font-weight:600;letter-spacing:0.3px;' +
                'text-transform:uppercase;white-space:nowrap;';

            var badges = {
                normal:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#66bb6a,#4caf50);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(76,175,80,0.35);">' +
                        '<i class="fas fa-check-circle" style="font-size:10px;"></i> ' + _t('articles.status.normal') +
                    '</span>',
                alerte:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#ffb74d,#ff9800);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(255,152,0,0.35);">' +
                        '<i class="fas fa-exclamation-triangle" style="font-size:10px;"></i> ' + _t('articles.status.alerte') +
                    '</span>',
                rupture:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#ef5350,#f44336);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(244,67,54,0.35);">' +
                        '<i class="fas fa-times-circle" style="font-size:10px;"></i> ' + _t('articles.status.rupture') +
                    '</span>'
            };

            return badges[statutStock] || ('<span style="' + baseStyle +
                'background:#e2e3e5;color:#383d41;">' + _t('articles.status.undefined') + '</span>');
        })();

        // ─── BADGE ACTIF / INACTIF ───
        var activeBadge = (function () {
            var baseStyle =
                'display:inline-flex;align-items:center;gap:5px;' +
                'padding:5px 12px;border-radius:20px;' +
                'font-size:11.5px;font-weight:600;letter-spacing:0.3px;' +
                'text-transform:uppercase;white-space:nowrap;';

            if (isActive) {
                return '<span style="' + baseStyle +
                    'background:linear-gradient(135deg,#66bb6a,#43a047);' +
                    'color:#fff;box-shadow:0 2px 6px rgba(67,160,71,0.35);">' +
                    '<i class="fas fa-check-circle" style="font-size:10px;"></i> ' + _t('articles.status.active') +
                '</span>';
            }

            return '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ef5350,#d32f2f);' +
                'color:#fff;box-shadow:0 2px 6px rgba(211,47,47,0.35);">' +
                '<i class="fas fa-times-circle" style="font-size:10px;"></i> ' + _t('articles.status.inactive') +
            '</span>';
        })();

        var codeHtml = '<span style="display:inline-block;font-weight:700;background:#e9e9e9;color:#333;padding:4px 10px;border-radius:20px;font-size:12px;">' +
            (a.CODE || '') + '</span>';

        var nomHtml = '<span style="font-weight:600;">' + (a.NOM || '') + '</span>';

        // ✅ CORRECTION : affiche le NOM de l'unité (via resolveUniteLabel)
        var uniteHtml = resolveUniteLabel(a);

        var stockTotalHtml = '<span style="display:inline-block;min-width:50px;text-align:center;padding:3px 8px;border-radius:8px;background:#007bff;color:#fff;font-weight:700;font-size:13px;">' +
            (a.STOCK_TOTAL || 0) + '</span>';

        var seuilAlerteHtml = '<span style="display:inline-block;min-width:50px;text-align:center;padding:3px 8px;border:1px solid #f0f0f0;border-radius:8px;">' +
            (a.SEUIL_ALERTE || 0) + '</span>';

        // ─── ACTIONS ───
        var actionsHtml = "";
        actionsHtml +=
            '<button type="button" class="btn-icon btn-info" ' +
            'onclick="viewHistory(\'' + a.ID + '\', \'\')" title="' + _t('articles.action.history') + '">' +
            '<i class="fas fa-history"></i></button>';

        actionsHtml +=
            '<button type="button" class="btn-icon btn-primary" ' +
            'onclick="editArticle(\'' + a.ID + '\')" title="' + _t('button.edit') + '">' +
            '<i class="fas fa-edit"></i></button>';

        actionsHtml +=
            '<button type="button" class="btn-icon btn-danger" ' +
            'onclick="deleteArticle(\'' + a.ID + '\')" title="' + _t('button.delete') + '">' +
            '<i class="fas fa-trash"></i></button>';

        html +=
            "<tr>" +
            "<td>" + codeHtml + "</td>" +
            "<td>" + nomHtml + "</td>" +
            "<td>" + (a.CATEGORIE_NOM || "") + "</td>" +
            "<td>" + (a.FOURNISSEUR_NOM || "") + "</td>" +
            "<td>" + uniteHtml + "</td>" +               /* ✅ NOM de l'unité */
            '<td style="text-align:center;">' + stockTotalHtml + "</td>" +
            '<td style="text-align:center;">' + seuilAlerteHtml + "</td>" +
            "<td>" + statutBadge + "</td>" +
            "<td>" + actionsHtml + "</td></tr>";
    });

    tbody.innerHTML = html;
    document.getElementById("resultsCounter").textContent =
        _t('articles.counter').replace('{n}', AppState.total);
}

// ─── EXPOSITIONS ───
window.loadArticles = loadArticles;
window.loadArticleStats = loadArticleStats;
window.loadDropdownsArticle = loadDropdownsArticle;
window.renderArticlesTable = renderArticlesTable;
window.populateSelect = populateSelect;
window.formatDateValue = formatDateValue;
window.formatNumber = formatNumber;
window.resolveUniteLabel = resolveUniteLabel;   /* ✅ nouvelle fonction exposée */

// ✅ ALIAS de compatibilité
window.loadStats = loadArticleStats;
window.loadDropdowns = loadDropdownsArticle;
window.renderTable = renderArticlesTable;
