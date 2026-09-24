// ============================================================
// CHARGEMENT DES DONNÉES – STOCK
// ============================================================

if (typeof window.AppState === "undefined") {
    window.AppState = {
        stock: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
        sortField: "ARTICLE_NOM",
        sortOrder: "ASC",
        filters: {
            search: "",
            article: "",
            emplacement: "",
            statut: ""
        },
        editingId: null,
        articles: [],
        emplacements: []
    };
}

// ============================================================
// CHARGEMENT DU STOCK
// ============================================================
async function loadStock(options) {
    var silent = !!(options && options.silent);
    if (!silent) showSpinner();

    try {
        var params = new URLSearchParams({
            page:        AppState.page,
            pageSize:    AppState.pageSize,
            search:      AppState.filters.search || '',
            article:     AppState.filters.article || '',
            emplacement: AppState.filters.emplacement || '',
            statut:      AppState.filters.statut || '',
            sort:        AppState.sortField,
            order:       AppState.sortOrder
        });
        var url  = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.stock      = data.Stock || [];
            AppState.total      = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);

            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages)
                AppState.page = AppState.totalPages;

            renderTable(AppState.stock);
            createPaginationControls(AppState.totalPages);
        } else {
            showToast(T('message.error', 'Erreur'),
                      data.message || T('stock.msg.load_error', 'Impossible de charger le stock'),
                      'error');
        }
    } catch (e) {
        showToast(T('message.error', 'Erreur'), e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

// ============================================================
// STATS
// ============================================================
async function loadStats() {
    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            var elTotalArticles = document.getElementById('statTotalArticles');
            var elTotalQuantite = document.getElementById('statTotalQuantite');
            var elSousSeuil     = document.getElementById('statSousSeuil');
            var elRupture       = document.getElementById('statRupture');

            if (elTotalArticles) elTotalArticles.textContent = data.totalArticles ?? 0;
            if (elTotalQuantite) elTotalQuantite.textContent = data.totalQuantite ?? 0;
            if (elSousSeuil)     elSousSeuil.textContent     = data.sousSeuil     ?? 0;
            if (elRupture)       elRupture.textContent       = data.rupture       ?? 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (e) {
        console.error('Erreur stats:', e);
    }
}

// ============================================================
// DROPDOWNS
// ============================================================
async function loadDropdowns() {
    // Articles
    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.ARTICLES;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
            populateSelect('article-filter', AppState.articles, 'ID', 'NOM', true,
                           T('stock.filter.all_articles', 'Tous articles'));
        }
    } catch (e) { /* ignore */ }

    // Emplacements
    try {
        var url2  = API.BASE + API.HANDLERS_PATH + API.EMPLACEMENTS;
        var resp2 = await fetch(url2);
        var data2 = await resp2.json();
        if (data2.success) {
            AppState.emplacements = data2.Emplacements || [];
            populateSelect('emplacement-filter', AppState.emplacements, 'ID', 'NOM', true,
                           T('stock.filter.all_emplacements', 'Tous emplacements'));
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
        opt.textContent = emptyText || T('stock.msg.select_placeholder', '-- Sélectionner --');
        select.appendChild(opt);
    }

    data.forEach(function (item) {
        var o = document.createElement('option');
        o.value = item[valueKey];
        o.textContent = item[textKey];
        select.appendChild(o);
    });

    if (currentValue) {
        var exists = false;
        for (var i = 0; i < select.options.length; i++) {
            if (select.options[i].value == currentValue) { exists = true; break; }
        }
        if (exists) select.value = currentValue;
    }
}

// ============================================================
// BADGE DE STATUT
// ============================================================
function getStockStatusBadge(statut) {
    var baseStyle =
        'display:inline-flex;align-items:center;gap:5px;' +
        'padding:4px 10px;border-radius:20px;' +
        'font-size:11.5px;font-weight:600;letter-spacing:0.3px;' +
        'text-transform:uppercase;white-space:nowrap;';

    var lblNormale = T('stock.status.normale', 'Normale');
    var lblAlerte  = T('stock.status.alerte',  'Alerte');
    var lblRupture = T('stock.status.rupture', 'Rupture');

    var badges = {
        NORMALE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#66bb6a,#4caf50);' +
                'color:#fff;box-shadow:0 2px 6px rgba(76,175,80,0.35);">' +
                '<i class="fas fa-check-circle" style="font-size:10px;"></i> ' + lblNormale +
            '</span>',
        ALERTE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ffb74d,#ff9800);' +
                'color:#fff;box-shadow:0 2px 6px rgba(255,152,0,0.35);">' +
                '<i class="fas fa-exclamation-triangle" style="font-size:10px;"></i> ' + lblAlerte +
            '</span>',
        RUPTURE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ef5350,#f44336);' +
                'color:#fff;box-shadow:0 2px 6px rgba(244,67,54,0.35);">' +
                '<i class="fas fa-times-circle" style="font-size:10px;"></i> ' + lblRupture +
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
        tbody.innerHTML = '<tr><td colspan="7" class="text-center">' +
            T('stock.msg.no_data', 'Aucun stock trouvé') +
            '</td></tr>';
        var c0 = document.getElementById('resultsCounter');
        if (c0) c0.textContent = T('stock.counter.zero', '0 ligne(s)');
        return;
    }

    var html = '';
    stock.forEach(function (s) {
        var disponible    = Number(s.DISPONIBLE    ?? 0);
        var seuil         = Number(s.SEUIL_ALERTE  ?? 0);
        var nomArticle    = s.ARTICLE_NOM    || '';
        var codeArticle   = s.ARTICLE_CODE   || '';
        var entree        = Number(s.ENTREE  || 0);
        var sortie        = Number(s.SORTIE  || 0);
        var articleId     = s.ARTICLE_ID     || '';
        var emplacementId = s.EMPLACEMENT_ID || '';

        var statut;
        if (disponible <= 0)                statut = 'RUPTURE';
        else if (seuil > 0 && disponible <= seuil) statut = 'ALERTE';
        else                                statut = 'NORMALE';

        var statusHtml = getStockStatusBadge(statut);

        var articleHtml = '<span style="font-weight:bold;">' +
            (codeArticle ? codeArticle + ' - ' : '') + (nomArticle || '') +
            '</span>';

        html += '<tr>' +
            '<td>' + articleHtml + '</td>' +
            '<td>' + entree + '</td>' +
            '<td>' + sortie + '</td>' +
            '<td>' + seuil + '</td>' +
            '<td><strong>' + disponible + '</strong></td>' +
            '<td>' + statusHtml + '</td>' +
            '<td>' +
                '<button type="button" class="btn btn-sm btn-info" ' +
                    'onclick="viewHistory(\'' + articleId + '\', \'' + emplacementId + '\')" ' +
                    'title="' + T('stock.btn.history', 'Historique') + '">' +
                    '<i class="fas fa-history"></i>' +
                '</button>' +
            '</td>' +
            '</tr>';
    });

    tbody.innerHTML = html;
    var cEl = document.getElementById('resultsCounter');
    if (cEl) cEl.textContent = T('stock.counter', '{n} ligne(s)', { n: AppState.total });
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.loadStock            = loadStock;
window.loadStats            = loadStats;
window.loadDropdowns        = loadDropdowns;
window.populateSelect       = populateSelect;
window.renderTable          = renderTable;
window.getStockStatusBadge  = getStockStatusBadge;
