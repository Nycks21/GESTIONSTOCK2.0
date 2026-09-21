// loaders.js - Module Fournisseurs + i18n
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// CHARGEMENT DE LA LISTE
// ============================================================
async function loadFournisseurs(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();
    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            actif: AppState.filters.actif,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.fournisseurs = data.Fournisseurs || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) {
                AppState.page = AppState.totalPages;
            }
            renderFournisseursTable(AppState.fournisseurs);
            loadFournisseurStats();
            createPaginationControls(AppState.totalPages);
        } else {
            showToast(_t('message.error'), data.message || _t('fournisseurs.msg.load_error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

// ============================================================
// CHARGEMENT DES STATISTIQUES
// ============================================================
async function loadFournisseurStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        var data = await resp.json();
        if (data.success) {
            document.getElementById('statTotal').textContent = data.total != null ? data.total : 0;
            document.getElementById('statActif').textContent = data.actif != null ? data.actif : 0;
            document.getElementById('statInactif').textContent = data.inactif != null ? data.inactif : 0;
            document.getElementById('statAvecEmail').textContent = data.avecEmail != null ? data.avecEmail : 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (err) {
        console.error('Erreur stats :', err);
        showToast(_t('message.error'), _t('fournisseurs.msg.stats_error'), 'error');
    }
}

// ============================================================
// RENDU DU TABLEAU
// ============================================================
function renderFournisseursTable(fournisseurs) {
    var tbody = document.getElementById('fournisseursTableBody');
    if (!fournisseurs.length) {
        tbody.innerHTML = '<tr><td colspan="9" class="text-center">' + _t('fournisseurs.msg.no_data') + '</td></tr>';
        document.getElementById('resultsCounter').textContent = _t('fournisseurs.counter').replace('{n}', 0);
        return;
    }

    var html = '';
    fournisseurs.forEach(function (f) {
        var statusHtml = f.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">' + _t('fournisseurs.status.active') + '</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">' + _t('fournisseurs.status.inactive') + '</span>';

        var codeHtml = f.CODE
            ? '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + f.CODE + '</span>'
            : '<span class="badge bg-secondary" style="color:#6c757d; background-color:#f8f9fa; padding:4px 10px; border-radius:20px;color:#333;">N/A</span>';

        html += '<tr>'
            + '<td>' + codeHtml + '</td>'
            + '<td><strong>' + (f.NOM || '') + '</strong></td>'
            + '<td>' + (f.ADRESSE || '') + '</td>'
            + '<td>' + (f.TELEPHONE || '') + '</td>'
            + '<td>' + (f.EMAIL || '') + '</td>'
            + '<td>' + (f.CONTACT_NOM || '') + '</td>'
            + '<td>' + (f.SIRET || '') + '</td>'
            + '<td>' + statusHtml + '</td>'
            + '<td>'
            +   '<button type="button" class="btn btn-sm btn-info" onclick="viewFournisseur(\'' + f.ID + '\')" title="' + _t('fournisseurs.action.view_details') + '"><i class="fas fa-eye"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-primary" onclick="editFournisseur(\'' + f.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-danger" onclick="deleteFournisseur(\'' + f.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent =
        _t('fournisseurs.counter').replace('{n}', AppState.total);
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.loadFournisseurs = loadFournisseurs;
window.loadFournisseurStats = loadFournisseurStats;
window.renderFournisseursTable = renderFournisseursTable;
