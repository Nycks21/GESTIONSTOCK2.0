// ============================================================
// CHARGEMENT DES DEMANDES (filtrées par utilisateur)
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
// FONCTIONS UTILITAIRES
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
        ? {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }
        : {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
        };
    return date.toLocaleString('fr-FR', options);
}

// ============================================================
// AFFICHAGE DU TABLEAU AVEC ACTIONS DYNAMIQUES
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
        var statutBadge = {
            'BROUILLON': '<span class="badge bg-warning" style="background:#B6D8F2;padding:4px 10px;border-radius:20px;color:#1E0F1C;">En cours</span>',
            'VALIDE': '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:#fff;">Validé</span>',
            'ANNULE': '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:#fff;">Annulé</span>'
        }[s.STATUT] || s.STATUT;
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

        // --- Construction des actions selon le statut ---
        var actionsHtml = '';
        // Bouton Visualiser toujours présent
        actionsHtml += '<button type="button" class="btn btn-sm btn-info" onclick="viewDemande(\'' + s.ID + '\')" title="Voir détails"><i class="fas fa-eye"></i></button> ';
        // Si le statut est "BROUILLON" (En cours), on ajoute Modifier et Supprimer
        if (s.STATUT === 'BROUILLON') {
            actionsHtml += '<button type="button" class="btn btn-sm btn-primary" onclick="editDemande(\'' + s.ID + '\')" title="Modifier"><i class="fas fa-edit"></i></button> ';
            actionsHtml += '<button type="button" class="btn btn-sm btn-danger" onclick="deleteDemande(\'' + s.ID + '\')" title="Supprimer"><i class="fas fa-trash"></i></button>';
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

// Expositions
window.loadDemandes = loadDemandes;
window.loadDemandesStats = loadDemandesStats;
window.loadArticlesForSaisie = loadArticlesForSaisie;
window.renderDemandesTable = renderDemandesTable;
window.formatDateValue = formatDateValue;
window.formatNumber = formatNumber;
