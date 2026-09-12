// ============================================================
// CHARGEMENT DES DONNÉES – STOCK
// ============================================================

// ✅ Sécurité : garantir que AppState existe avant tout usage
if (typeof window.AppState === "undefined") {
    window.AppState = {
        stock: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
        sortField: "ARTICLE_NOM",
        sortOrder: "ASC",
        filters: { search: "", article: "", emplacement: "" },
        editingId: null,
        articles: [],
        emplacements: []
    };
}

async function loadStock(options) {
    var silent = !!(options && options.silent);
    if (!silent) showSpinner();
    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            article: AppState.filters.article,
            emplacement: AppState.filters.emplacement,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.stock = data.Stock || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages)
                AppState.page = AppState.totalPages;
            renderTable(AppState.stock);
            createPaginationControls(AppState.totalPages);
        } else {
            showToast('Erreur', data.message || 'Impossible de charger le stock', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            document.getElementById('statTotalArticles').textContent = data.totalArticles ?? 0;
            document.getElementById('statTotalQuantite').textContent = data.totalQuantite ?? 0;
            document.getElementById('statSousSeuil').textContent = data.sousSeuil ?? 0;
            document.getElementById('statRupture').textContent = data.rupture ?? 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (e) {
        console.error('Erreur stats:', e);
    }
}

async function loadDropdowns() {
    // Articles
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.ARTICLES;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
            populateSelect('article-filter', AppState.articles, 'ID', 'NOM', true, 'Tous articles');
        }
    } catch (e) { /* ignore */ }

    // Emplacements
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.EMPLACEMENTS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.emplacements = data.Emplacements || [];
            populateSelect('emplacement-filter', AppState.emplacements, 'ID', 'NOM', true, 'Tous emplacements');
        }
    } catch (e) { /* ignore */ }
}

function populateSelect(selectId, data, valueKey, textKey, addEmpty, emptyText) {
    var select = document.getElementById(selectId);
    if (!select) return;
    var currentValue = select.value;
    select.innerHTML = '';
    if (addEmpty) {
        var opt = document.createElement('option');
        opt.value = '';
        opt.textContent = emptyText || '-- Sélectionner --';
        select.appendChild(opt);
    }
    data.forEach(function (item) {
        var opt = document.createElement('option');
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

// ============================================================
// UTILITAIRE : génère un badge de statut STOCK
// ============================================================
function getStockStatusBadge(statut) {
    var baseStyle =
        'display:inline-flex;align-items:center;gap:5px;' +
        'padding:4px 10px;border-radius:20px;' +
        'font-size:11.5px;font-weight:600;letter-spacing:0.3px;' +
        'text-transform:uppercase;white-space:nowrap;';

    var badges = {
        NORMALE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#66bb6a,#4caf50);' +
                'color:#fff;box-shadow:0 2px 6px rgba(76,175,80,0.35);">' +
                '<i class="fas fa-check-circle" style="font-size:10px;"></i> Normale' +
            '</span>',
        ALERTE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ffb74d,#ff9800);' +
                'color:#fff;box-shadow:0 2px 6px rgba(255,152,0,0.35);">' +
                '<i class="fas fa-exclamation-triangle" style="font-size:10px;"></i> Alerte' +
            '</span>',
        RUPTURE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ef5350,#f44336);' +
                'color:#fff;box-shadow:0 2px 6px rgba(244,67,54,0.35);">' +
                '<i class="fas fa-times-circle" style="font-size:10px;"></i> Rupture' +
            '</span>'
    };

    return badges[statut] || ('<span style="' + baseStyle +
        'background:#e2e3e5;color:#383d41;">' + (statut || '—') + '</span>');
}

// ============================================================
// AFFICHAGE DU TABLEAU
// ============================================================

function renderTable(stock) {
    var tbody = document.getElementById('stockTableBody');
    if (!tbody) return;
    if (!stock || !stock.length) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">Aucun stock trouvé</td></tr>';
        document.getElementById('resultsCounter').textContent = '0 ligne(s)';
        return;
    }

    var html = '';
    stock.forEach(function (s) {
        var disponible = Number(s.DISPONIBLE ?? 0);
        var seuil = Number(s.SEUIL_ALERTE ?? 0);
        var nomArticle = s.ARTICLE_NOM || '';
        var codeArticle = s.ARTICLE_CODE || '';
        var entree = Number(s.ENTREE || 0);
        var sortie = Number(s.SORTIE || 0);
        var articleId = s.ARTICLE_ID || '';
        var emplacementId = s.EMPLACEMENT_ID || '';

        // ─────────────────────────────────────────────────────────
        // ✅ FIX : calcul du statut À PARTIR DE DISPONIBLE et SEUIL_ALERTE
        //    Variables :
        //      - statut      → clé technique (NORMALE / ALERTE / RUPTURE)
        //      - statutLabel → libellé français affiché si besoin
        // ─────────────────────────────────────────────────────────
        var statut;
        var statutLabel;

        if (disponible <= 0) {
            statut = 'RUPTURE';
            statutLabel = 'Rupture';
        } else if (seuil > 0 && disponible <= seuil) {
            statut = 'ALERTE';
            statutLabel = 'Alerte';
        } else {
            statut = 'NORMALE';
            statutLabel = 'Normale';
        }

        // ✅ Badge généré via la fonction utilitaire
        var statusHtml = getStockStatusBadge(statut);

        var articleHtml = '<span style="font-weight:bold;">' +
            (codeArticle ? codeArticle + ' - ' : '') + (nomArticle || '') +
            '</span>';

        html += '<tr>' +
            '<td>' + articleHtml + '</td>' +
            '<td>' + entree + '</td>' +
            '<td>' + sortie + '</td>' +
            '<td><strong>' + disponible + '</strong></td>' +
            '<td>' + statusHtml + '</td>' +
            '<td>' +
            '<button type="button" class="btn btn-sm btn-info" ' +
            'onclick="viewHistory(\'' + articleId + '\', \'' + emplacementId + '\')" ' +
            'title="Historique"><i class="fas fa-history"></i></button>' +
            '</td>' +
            '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = AppState.total + ' ligne(s)';
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.loadStock = loadStock;
window.loadStats = loadStats;
window.loadDropdowns = loadDropdowns;
window.populateSelect = populateSelect;
window.renderTable = renderTable;
window.getStockStatusBadge = getStockStatusBadge;
