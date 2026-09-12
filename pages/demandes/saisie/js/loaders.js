// ============================================================
// CHARGEMENT DES DEMANDES – SAISIE (style aligné sur SORTIE)
// ============================================================

// Sécurité : garantir que AppState existe
if (typeof window.AppState === 'undefined') {
    window.AppState = {
        sorties: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
        sortField: 'DATE_SORTIE',
        sortOrder: 'DESC',
        filters: { search: '', statut: '' },
        articles: []
    };
}

// ============================================================
// CHARGEMENT DES DEMANDES
// ============================================================
async function loadDemandes(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();

    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search || '',
            statut: AppState.filters.statut || '',
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params.toString();
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.sorties = data.Sorties || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            renderDemandesTable(AppState.sorties);
            createPaginationControls(AppState.totalPages);
            loadDemandesStats();
        } else {
            showToast('Erreur', data.message || 'Impossible de charger les demandes', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

// ============================================================
// STATS
// ============================================================
async function loadDemandesStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            document.getElementById('statTotal').textContent = data.total ?? 0;
            document.getElementById('statValide').textContent = data.valide ?? 0;
            document.getElementById('statBrouillon').textContent = data.brouillon ?? 0;
            document.getElementById('statAnnule').textContent = data.annule ?? 0;
        }
    } catch (e) {
        console.warn('Erreur stats:', e);
    }
}

// ============================================================
// ARTICLES (pour les dropdowns du modal)
// ============================================================
async function loadArticlesForSaisie() {
    try {
        var url = API.BASE + 'pages/modules/articles/handlers/' + API.ARTICLES + '?page=1&pageSize=999999';
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
        }
    } catch (e) { /* ignore */ }
}

// ============================================================
// UTILITAIRES DE FORMATAGE
// ============================================================
function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return '0';
    return Number(value).toFixed(decimals || 0);
}

function formatDateValue(value, includeTime) {
    if (value === null || value === undefined || value === '') return '-';
    var date = null;
    if (typeof value === 'string') {
        var str = value.trim();
        if (!str) return '-';
        var msMatch = str.match(/-?\d+/);
        if (str.indexOf('/Date(') !== -1 && msMatch) {
            date = new Date(parseInt(msMatch[0], 10));
        } else {
            date = new Date(str);
        }
    } else if (value instanceof Date) {
        date = value;
    } else {
        date = new Date(value);
    }
    if (!date || isNaN(date.getTime())) return '-';
    var options = includeTime
        ? { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }
        : { day: '2-digit', month: '2-digit', year: 'numeric' };
    return date.toLocaleString('fr-FR', options);
}

// ============================================================
// RENDU DU TABLEAU
// ============================================================
function renderDemandesTable(sorties) {
    var tbody = document.getElementById('saisieTableBody');
    if (!tbody) return;
    if (!sorties.length) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center">Aucune demande trouvée</td></tr>';
        document.getElementById('resultsCounter').textContent = '0 demande(s)';
        return;
    }

    var html = '';
    sorties.forEach(function (s) {
        var statut = s.STATUT;

        var statutBadge = (function () {
            var baseStyle =
                'display:inline-flex;align-items:center;gap:5px;' +
                'padding:5px 12px;border-radius:20px;' +
                'font-size:11.5px;font-weight:600;letter-spacing:0.3px;' +
                'text-transform:uppercase;white-space:nowrap;';

            var badges = {
                BROUILLON:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#64b5f6,#2196f3);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(33,150,243,0.35);">' +
                        '<i class="fas fa-pencil-alt" style="font-size:10px;"></i> En cours' +
                    '</span>',
                VALIDE:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#66bb6a,#4caf50);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(76,175,80,0.35);">' +
                        '<i class="fas fa-check-circle" style="font-size:10px;"></i> Validé' +
                    '</span>',
                ANNULE:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#ef5350,#f44336);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(244,67,54,0.35);">' +
                        '<i class="fas fa-times-circle" style="font-size:10px;"></i> Annulé' +
                    '</span>'
            };

            return badges[statut] || ('<span style="' + baseStyle +
                'background:#e2e3e5;color:#383d41;">' + statut + '</span>');
        })();

        var lignes = s.Lignes || [];

        var articlesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-article-item">' +
                    '<span>' + (ligne.ARTICLE_CODE ? ligne.ARTICLE_CODE + ' - ' : '') +
                    (ligne.ARTICLE_NOM || ligne.ARTICLE_ID || '') + '</span>' +
                    '</div>';
            }).join('')
            : '<span class="text-muted">Aucun article</span>';

        var quantitesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-quantity-item">' + formatNumber(ligne.QUANTITE_D, 2) + '</div>';
            }).join('')
            : '<span class="text-muted">-</span>';

        var actionsHtml = "";

        actionsHtml +=
            '<button type="button" class="btn-icon btn-info" ' +
            'onclick="viewDemande(\'' + s.ID + '\')" title="Voir détails">' +
            '<i class="fas fa-eye"></i></button>';

        if (statut === 'BROUILLON') {
            actionsHtml +=
                '<button type="button" class="btn-icon btn-primary" ' +
                'onclick="editDemande(\'' + s.ID + '\')" title="Modifier">' +
                '<i class="fas fa-edit"></i></button>';

            actionsHtml +=
                '<button type="button" class="btn-icon btn-danger" ' +
                'onclick="deleteDemande(\'' + s.ID + '\')" title="Supprimer">' +
                '<i class="fas fa-trash"></i></button>';
        }

        html += '<tr>' +
            '<td><strong>' + s.NUMERO + '</strong></td>' +
            '<td>' + formatDateValue(s.DATE_SORTIE, true) + '</td>' +
            '<td class="bon-articles-cell">' + articlesHtml + '</td>' +
            '<td class="bon-quantities-cell">' + quantitesHtml + '</td>' +
            '<td>' + (s.DESTINATION || '') + '</td>' +
            '<td>' + statutBadge + '</td>' +
            '<td>' + actionsHtml + '</td>' +
            '</tr>';
    });

    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = AppState.total + ' demande(s)';
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.loadDemandes = loadDemandes;
window.loadDemandesStats = loadDemandesStats;
window.loadArticlesForSaisie = loadArticlesForSaisie;
window.renderDemandesTable = renderDemandesTable;
window.formatDateValue = formatDateValue;
window.formatNumber = formatNumber;
