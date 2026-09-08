// loaders.js

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
            populateSelect('adjustArticle', AppState.articles, 'ID', 'NOM', true, '-- Sélectionner --');
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
            populateSelect('adjustEmplacement', AppState.emplacements, 'ID', 'NOM', true, '-- Sélectionner --');
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
    data.forEach(function(item) {
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

function renderTable(stock) {
    var tbody = document.getElementById('stockTableBody');
    if (!tbody) return;
    if (!stock || !stock.length) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">Aucun stock trouvé</td></tr>';
        document.getElementById('resultsCounter').textContent = '0 ligne(s)';
        return;
    }

    var html = '';
    stock.forEach(function(s) {
        // Utiliser des noms de champs flexibles
        var disponible = Number(s.DISPONIBLE ?? s.quantite ?? s.stock ?? 0);
        var seuil = Number(s.SEUIL_ALERTE ?? s.seuil ?? 0);
        var nomArticle = s.ARTICLE_NOM || s.nomArticle || '';
        var codeArticle = s.ARTICLE_CODE || s.codeArticle || '';
        var entree = Number(s.ENTREE || 0);
        var sortie = Number(s.SORTIE || 0);
        var articleId = s.ARTICLE_ID || s.articleId || '';
        var emplacementId = s.EMPLACEMENT_ID || s.emplacementId || '';

        // Calcul du statut
        var statutLabel = '';
        var badgeClass = '';
        if (disponible <= 0) {
            statutLabel = 'Rupture';
            badgeClass = 'badge-danger';
        } else if (disponible <= seuil) {
            statutLabel = 'Stock faible';
            badgeClass = 'badge-warning';
        } else {
            statutLabel = 'Normal';
            badgeClass = 'badge-success';
        }
        var statusHtml = '<span class="badge ' + badgeClass + '" style="padding:4px 10px;border-radius:20px;color:white;">' + statutLabel + '</span>';

        var articleHtml = '<span style="font-weight:bold;">' + (codeArticle ? codeArticle + ' - ' : '') + (nomArticle || '') + '</span>';

        html += '<tr>' +
            '<td>' + articleHtml + '</td>' +
            '<td>' + entree + '</td>' +
            '<td>' + sortie + '</td>' +
            '<td><strong>' + disponible + '</strong></td>' +
            '<td>' + statusHtml + '</td>' +
            '<td>' +
            '<button type="button" class="btn btn-sm btn-info" onclick="viewHistory(\'' + articleId + '\', \'' + emplacementId + '\')" title="Historique"><i class="fas fa-history"></i></button> ' +
            '<button type="button" class="btn btn-sm btn-warning" onclick="openAdjustModalFromStock(event, \'' + articleId + '\', \'' + emplacementId + '\')" title="Ajuster"><i class="fas fa-exchange-alt"></i></button>' +
            '</td>' +
            '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = AppState.total + ' ligne(s)';
}


// Expositions
window.loadStock = loadStock;
window.loadStats = loadStats;
window.loadDropdowns = loadDropdowns;
window.populateSelect = populateSelect;
window.renderTable = renderTable;
