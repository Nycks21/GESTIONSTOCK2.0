'use strict';

function loadDashboard() {
    showSpinner();
    activateDashboardLink();

    Promise.all([
        loadKpi(),
        loadAlerts(),
        loadMovements(),
        loadStockByCategory(),
        loadRecentMovements(),
        loadRecentDocuments(),
        loadTopArticles()
    ]).catch(function(err) {
        console.error('Dashboard load error:', err);
        showToast('Erreur lors du chargement du tableau de bord', 'error');
    }).finally(function() {
        hideSpinner();
        DashboardState.lastRefresh = new Date();
    });
}

async function fetchJson(url) {
    var resp = await fetch(url, { credentials: 'same-origin' });
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    return resp.json();
}

// ═══ KPI ═══
async function loadKpi() {
    try {
        var data = await fetchJson(DASHBOARD_API.KPI);
        if (!data.success) return;
        DashboardState.kpi = data;

        document.getElementById('valArticles').textContent = formatNumber(data.articlesActifs);
        document.getElementById('pillArticlesTotal').textContent = formatNumber(data.articlesTotal) + ' total';

        document.getElementById('valAlertes').textContent = formatNumber(data.alertesStock);
        document.getElementById('pillRuptures').textContent = formatNumber(data.ruptures) + ' rupture(s)';
        document.getElementById('pillAlertesCount').textContent = formatNumber(data.alertes) + ' alerte(s)';

        document.getElementById('valBons').textContent = formatNumber(data.bonsAttente);
        document.getElementById('pillEntree').textContent = formatNumber(data.bonsEntree) + ' entrée(s)';
        document.getElementById('pillSortie').textContent = formatNumber(data.bonsSortie) + ' sortie(s)';

        document.getElementById('valValeur').textContent = formatCurrency(data.valeurStock);
        document.getElementById('pillSousSeuil').textContent = formatNumber(data.articlesSousSeuil) + ' sous seuil';
    } catch (e) {
        console.error('KPI:', e);
    }
}

// ═══ ALERTES ═══
async function loadAlerts() {
    var card = document.getElementById('alertCard');
    if (!card) return;

    try {
        var data = await fetchJson(DASHBOARD_API.ALERTS);
        var items = data.data || [];
        DashboardState.alerts = items;

        if (!items.length) {
            card.style.display = 'none';
            return;
        }
        card.style.display = 'block';
        document.getElementById('alertCount').textContent = items.length;

        var html = '';
        for (var i = 0; i < items.length; i++) {
            var a = items[i];
            html += '<tr>'
                + '<td><strong>' + escapeHtml(a.code) + '</strong></td>'
                + '<td>' + escapeHtml(a.nom) + '</td>'
                + '<td>' + escapeHtml(a.categorie || '—') + '</td>'
                + '<td>' + escapeHtml(a.emplacement || '—') + '</td>'
                + '<td><strong>' + formatNumber(a.quantite) + '</strong> ' + escapeHtml(a.unite) + '</td>'
                + '<td>' + formatNumber(a.seuilAlerte) + '</td>'
                + '<td>' + statutBadge(a.statut) + '</td>'
                + '</tr>';
        }
        document.getElementById('tbodyAlerts').innerHTML = html;
    } catch (e) {
        console.error('Alerts:', e);
    }
}

// ═══ MOUVEMENTS ═══
async function loadMovements() {
    try {
        var data = await fetchJson(DASHBOARD_API.MOVEMENTS);
        if (!data.success) return;
        DashboardState.movements = data;
        initMovementsChart(data.labels, data.entrees, data.sorties);
    } catch (e) {
        console.error('Movements:', e);
    }
}

// ═══ CATÉGORIES ═══
async function loadStockByCategory() {
    try {
        var data = await fetchJson(DASHBOARD_API.STOCK_CATEGORY);
        if (!data.success || !data.labels) return;
        DashboardState.categories = data;
        initCategoriesChart(data.labels, data.quantites);
    } catch (e) {
        console.error('Categories:', e);
    }
}

// ═══ ACTIVITÉ RÉCENTE (mouvements) ═══
async function loadRecentMovements() {
    var feed = document.getElementById('activityFeed');
    if (!feed) return;

    try {
        var data = await fetchJson(DASHBOARD_API.RECENT_MVT);
        var items = data.data || [];
        DashboardState.recentMovements = items;

        if (!items.length) {
            feed.innerHTML = '<div class="loading-mini">Aucun mouvement récent</div>';
            return;
        }

        var html = '';
        for (var i = 0; i < items.length; i++) {
            var m = items[i];
            var isEntree = m.type === 'ENTREE';
            html += '<div class="activity-item">'
                + '<div class="activity-icon ' + (isEntree ? 'entry' : 'exit') + '">'
                + '<i class="fas fa-arrow-' + (isEntree ? 'down' : 'up') + '"></i>'
                + '</div>'
                + '<div class="activity-content">'
                + '<div class="activity-text">'
                + '<strong>' + (isEntree ? '+' : '-') + formatNumber(m.quantite) + ' ' + escapeHtml(m.unite) + '</strong>'
                + ' — ' + escapeHtml(m.code) + ' ' + escapeHtml(m.nom)
                + '</div>'
                + '<div class="activity-time">'
                + timeAgo(m.date)
                + (m.utilisateur ? ' · ' + escapeHtml(m.utilisateur) : '')
                + '</div>'
                + '</div>'
                + '</div>';
        }
        feed.innerHTML = html;
    } catch (e) {
        console.error('Recent movements:', e);
        feed.innerHTML = '<div class="loading-mini">Erreur de chargement</div>';
    }
}

// ═══ DOCUMENTS RÉCENTS ═══
async function loadRecentDocuments() {
    var feed = document.getElementById('documentsFeed');
    if (!feed) return;

    try {
        var data = await fetchJson(DASHBOARD_API.RECENT_DOCS);
        var items = data.data || [];
        DashboardState.recentDocuments = items;

        if (!items.length) {
            feed.innerHTML = '<div class="loading-mini">Aucun document récent</div>';
            return;
        }

        var html = '';
        for (var i = 0; i < items.length; i++) {
            var d = items[i];
            var isEntree = d.type === 'ENTREE';
            html += '<div class="activity-item">'
                + '<div class="activity-icon doc">'
                + '<i class="fas fa-file-' + (isEntree ? 'import' : 'export') + '"></i>'
                + '</div>'
                + '<div class="activity-content">'
                + '<div class="activity-text">'
                + '<strong>' + escapeHtml(d.numero) + '</strong> '
                + statutBadge(d.statut)
                + '</div>'
                + '<div class="activity-time">'
                + (isEntree ? 'Entrée' : 'Sortie') + ' · ' + formatDateFr(d.date)
                + '</div>'
                + '</div>'
                + '</div>';
        }
        feed.innerHTML = html;
    } catch (e) {
        console.error('Recent documents:', e);
        feed.innerHTML = '<div class="loading-mini">Erreur de chargement</div>';
    }
}

// ═══ TOP ARTICLES ═══
async function loadTopArticles() {
    var container = document.getElementById('topArticlesList');
    if (!container) return;

    try {
        var data = await fetchJson(DASHBOARD_API.TOP_ARTICLES);
        var items = data.data || [];
        DashboardState.topArticles = items;

        if (!items.length) {
            container.innerHTML = '<div class="loading-mini">Aucune donnée sur 30 jours</div>';
            return;
        }

        var html = '';
        for (var i = 0; i < items.length; i++) {
            var a = items[i];
            var rankClass = i < 3 ? ' rank-' + (i + 1) : '';
            html += '<div class="top-article">'
                + '<div class="top-rank' + rankClass + '">' + (i + 1) + '</div>'
                + '<div class="top-info">'
                + '<div class="top-name">' + escapeHtml(a.nom) + '</div>'
                + '<div class="top-code">' + escapeHtml(a.code) + '</div>'
                + '</div>'
                + '<div class="top-volume">' + formatNumber(a.volume) + ' ' + escapeHtml(a.unite) + '</div>'
                + '</div>';
        }
        container.innerHTML = html;
    } catch (e) {
        console.error('Top articles:', e);
        container.innerHTML = '<div class="loading-mini">Erreur de chargement</div>';
    }
}

window.loadDashboard = loadDashboard;
