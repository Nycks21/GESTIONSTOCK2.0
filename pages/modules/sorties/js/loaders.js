// ============================================================
// CHARGEMENT DES DONNÉES
// ============================================================

async function loadSorties(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();

    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search || '',
            destination: AppState.filters.destination || '',
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
            renderSortiesTable(AppState.sorties);
            createPaginationControls(AppState.totalPages);
            loadSortieStats();
        } else {
            showToast('Erreur', data.message || 'Impossible de charger les bons', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadSortieStats() {
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

async function loadDropdownsSortie() {
    // Récupération des articles pour les lignes
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.ARTICLES;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
            // Mettre à jour les selects déjà présents
            document.querySelectorAll('.ligne-article').forEach(function (sel) {
                var currentVal = sel.value;
                sel.innerHTML = '<option value="">-- Article --</option>' +
                    AppState.articles.map(function (a) {
                        return '<option value="' + a.ID + '">' + a.CODE + ' - ' + a.NOM + '</option>';
                    }).join('');
                sel.value = currentVal;
            });
        }
    } catch (e) { /* ignore */ }
}

// ============================================================
// FONCTIONS D'AFFICHAGE
// ============================================================

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
    var options = includeTime ? {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    } : {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
    };
    return date.toLocaleString('fr-FR', options);
}

function renderSortiesTable(sorties) {
    var tbody = document.getElementById('sortiesTableBody');
    if (!tbody) return;
    if (!sorties.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center">Aucun bon de sortie trouvé</td></tr>';
        document.getElementById('resultsCounter').textContent = '0 bon(s)';
        return;
    }
    var html = '';
    sorties.forEach(function (s) {
        var statutBadge = {
            'BROUILLON': '<span class="badge bg-warning" style="background:#ffc107;color:#212529;">Brouillon</span>',
            'VALIDE': '<span class="badge bg-success" style="background:#28a745;">Validé</span>',
            'ANNULE': '<span class="badge bg-danger" style="background:#dc3545;">Annulé</span>'
        }[s.STATUT] || s.STATUT;
        html += '<tr>' +
            '<td><strong>' + s.NUMERO + '</strong></td>' +
            '<td>' + formatDateValue(s.DATE_SORTIE, true) + '</td>' +
            '<td>' + (s.DESTINATION || '') + '</td>' +
            '<td>' + (s.NOM || '') + '</td>' +
            '<td>' + (s.FONCTION || '') + '</td>' +
            '<td>' + statutBadge + '</td>' +
            '<td>' + formatDateValue(s.CREATED_AT, true) + '</td>' +
            '<td>' +
            '<button type="button" class="btn btn-sm btn-primary" onclick="editSortie(\'' + s.ID + '\')"><i class="fas fa-edit"></i></button> ' +
            '<button type="button" class="btn btn-sm btn-danger" onclick="deleteSortie(\'' + s.ID + '\')"><i class="fas fa-trash"></i></button> ' +
            (s.STATUT === 'BROUILLON' ? '<button type="button" class="btn btn-sm btn-success" onclick="validerSortie(\'' + s.ID + '\')"><i class="fas fa-check"></i></button>' : '') +
            '</td></tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = AppState.total + ' bon(s)';
}

// Expositions globales
window.loadSorties = loadSorties;
window.loadSortieStats = loadSortieStats;
window.loadDropdownsSortie = loadDropdownsSortie;
window.renderSortiesTable = renderSortiesTable;
window.formatDateValue = formatDateValue;
