// ============================================================
// CHARGEMENT DES DONNÉES – ARTICLES
// ============================================================

function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return "0";
    return Number(value).toFixed(decimals || 0);
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
            showToast("Erreur", data.message || "Impossible de charger les articles", "error");
        }
    } catch (e) {
        showToast("Erreur", e.message, "error");
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
            document.getElementById("statTotal").textContent = data.total ?? 0;
            document.getElementById("statNormal").textContent = data.normal ?? 0;
            document.getElementById("statAlerte").textContent = data.alerte ?? 0;
            document.getElementById("statRupture").textContent = data.rupture ?? 0;
        } else {
            console.warn("Stats API returned success=false:", data.message);
        }
    } catch (e) {
        console.error("Erreur stats:", e);
        showToast("Erreur", "Impossible de charger les statistiques", "error");
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
            populateSelect("articleCategorie", AppState.categories, "ID", "NOM", true, "-- Sélectionner Catégorie --");
            populateSelect("category-filter", AppState.categories, "ID", "NOM", true, "Toutes catégories");
        }
    } catch (e) { /* ignore */ }

    // Fournisseurs
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.FOURNISSEURS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.fournisseurs = data.Fournisseurs || [];
            populateSelect("articleFournisseur", AppState.fournisseurs, "ID", "NOM", true, "-- Sélectionner Fournisseur --");
        }
    } catch (e) { /* ignore */ }

    // Unités
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.UNITES;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.unites = data.Unites || [];
            populateSelect("articleUnite", AppState.unites, "ID", "NOM", true, "-- Sélectionner Unité --");
        }
    } catch (e) { /* ignore */ }

    // Emplacements
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.EMPLACEMENTS + "?pageSize=999999";
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.emplacements = data.Emplacements || [];
            populateSelect("articleEmplacement", AppState.emplacements, "ID", "NOM", true, "-- Sélectionner Emplacement --");
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
        opt.textContent = emptyText || "-- Sélectionner --";
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
        tbody.innerHTML = '<tr><td colspan="11" class="text-center">Aucun article trouvé</td></tr>';
        document.getElementById("resultsCounter").textContent = "0 article(s)";
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
                        '<i class="fas fa-check-circle" style="font-size:10px;"></i> Normal' +
                    '</span>',
                alerte:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#ffb74d,#ff9800);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(255,152,0,0.35);">' +
                        '<i class="fas fa-exclamation-triangle" style="font-size:10px;"></i> Alerte' +
                    '</span>',
                rupture:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#ef5350,#f44336);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(244,67,54,0.35);">' +
                        '<i class="fas fa-times-circle" style="font-size:10px;"></i> Rupture' +
                    '</span>'
            };

            return badges[statutStock] || ('<span style="' + baseStyle +
                'background:#e2e3e5;color:#383d41;">Indéfini</span>');
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
                    '<i class="fas fa-check-circle" style="font-size:10px;"></i> Actif' +
                '</span>';
            }

            return '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ef5350,#d32f2f);' +
                'color:#fff;box-shadow:0 2px 6px rgba(211,47,47,0.35);">' +
                '<i class="fas fa-times-circle" style="font-size:10px;"></i> Inactif' +
            '</span>';
        })();

        // ─── CELLULES STYLISÉES ───
        var codeHtml = '<span style="display:inline-block;font-weight:700;background:#e9e9e9;color:#333;padding:4px 10px;border-radius:20px;font-size:12px;">' +
            (a.CODE || '') + '</span>';

        var nomHtml = '<span style="font-weight:600;">' + (a.NOM || '') + '</span>';

        var stockTotalHtml = '<span style="display:inline-block;min-width:50px;text-align:center;padding:3px 8px;border-radius:8px;background:#007bff;color:#fff;font-weight:700;font-size:13px;">' +
            (a.STOCK_TOTAL || 0) + '</span>';

        var seuilMinHtml = '<span style="display:inline-block;min-width:50px;text-align:center;padding:3px 8px;border:1px solid #f0f0f0;border-radius:8px;">' +
            (a.SEUIL_MIN || 0) + '</span>';

        var seuilAlerteHtml = '<span style="display:inline-block;min-width:50px;text-align:center;padding:3px 8px;border:1px solid #f0f0f0;border-radius:8px;">' +
            (a.SEUIL_ALERTE || 0) + '</span>';

        // ─── ACTIONS (boutons icônes modernes) ───
        var actionsHtml = "";

        // 1. Historique
        actionsHtml +=
            '<button type="button" class="btn-icon btn-info" ' +
            'onclick="viewHistory(\'' + a.ID + '\', \'\')" title="Historique">' +
            '<i class="fas fa-history"></i></button>';

        // 2. Modifier
        actionsHtml +=
            '<button type="button" class="btn-icon btn-primary" ' +
            'onclick="editArticle(\'' + a.ID + '\')" title="Modifier">' +
            '<i class="fas fa-edit"></i></button>';

        // 3. Supprimer
        actionsHtml +=
            '<button type="button" class="btn-icon btn-danger" ' +
            'onclick="deleteArticle(\'' + a.ID + '\')" title="Supprimer">' +
            '<i class="fas fa-trash"></i></button>';

        html +=
            "<tr>" +
            "<td>" + codeHtml + "</td>" +
            "<td>" + nomHtml + "</td>" +
            "<td>" + (a.CATEGORIE_NOM || "") + "</td>" +
            "<td>" + (a.FOURNISSEUR_NOM || "") + "</td>" +
            "<td>" + (a.UNITE_SYMBOLE || a.UNITE || "") + "</td>" +
            '<td style="text-align:center;">' + stockTotalHtml + "</td>" +
            '<td style="text-align:center;">' + seuilMinHtml + "</td>" +
            '<td style="text-align:center;">' + seuilAlerteHtml + "</td>" +
            "<td>" + statutBadge + "</td>" +
            "<td>" + actionsHtml + "</td></tr>";
    });

    tbody.innerHTML = html;
    document.getElementById("resultsCounter").textContent = AppState.total + " article(s)";
}

// ─── EXPOSITIONS ───
window.loadArticles = loadArticles;
window.loadArticleStats = loadArticleStats;
window.loadDropdownsArticle = loadDropdownsArticle;
window.renderArticlesTable = renderArticlesTable;
window.populateSelect = populateSelect;
window.formatDateValue = formatDateValue;
window.formatNumber = formatNumber;

// ✅ ALIAS de compatibilité (init.js / crud.js utilisent encore ces noms)
window.loadStats = loadArticleStats;
window.loadDropdowns = loadDropdownsArticle;
window.renderTable = renderArticlesTable;
