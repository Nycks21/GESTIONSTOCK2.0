// loaders.js – Version avec bouton Visualiser + i18n
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// CHARGEMENT DE LA LISTE
// ============================================================
async function loadUnites(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();
    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            status: AppState.filters.status,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.unites = data.Unites || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) AppState.page = AppState.totalPages;
            renderTable(AppState.unites);
            loadStats();
            createPaginationControls(AppState.totalPages);
        } else {
            showToast(_t('message.error'), data.message || _t('unites.msg.load_error'), 'error');
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
async function loadStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        var data = await resp.json();
        if (data.success) {
            document.getElementById('statTotal').textContent = data.total != null ? data.total : 0;
            document.getElementById('statActives').textContent = data.actives != null ? data.actives : 0;
            document.getElementById('statInactives').textContent = data.inactives != null ? data.inactives : 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (err) {
        console.error('Erreur stats :', err);
        showToast(_t('message.error'), _t('unites.msg.stats_error'), 'error');
    }
}

// ============================================================
// RENDU DU TABLEAU
// ============================================================
function renderTable(unites) {
    var tbody = document.getElementById('unitesTableBody');
    if (!unites.length) {
        tbody.innerHTML = '<tr><td colspan="4" class="text-center">' + _t('unites.msg.no_data') + '</td></tr>';
        document.getElementById('resultsCounter').textContent = _t('unites.counter').replace('{n}', 0);
        return;
    }

    var html = '';
    unites.forEach(function (u) {
        var statusHtml = u.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">' + _t('unites.status.active') + '</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">' + _t('unites.status.inactive') + '</span>';

        var codeHtml = u.CODE
            ? '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + u.CODE + '</span>'
            : '<span class="badge bg-secondary" style="color:#6c757d; background-color:#f8f9fa; padding:4px 10px; border-radius:20px;color:#333;">N/A</span>';

        var nomHtml = u.NOM
            ? '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">' + u.NOM + '</span>'
            : '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">N/A</span>';

        html += '<tr>'
            + '<td>' + codeHtml + '</td>'
            + '<td>' + nomHtml + '</td>'
            + '<td>' + statusHtml + '</td>'
            + '<td>'
            +   '<button type="button" class="btn btn-sm btn-info" onclick="viewUnite(\'' + u.ID + '\')" title="' + _t('unites.action.view_details') + '"><i class="fas fa-eye"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-primary" onclick="editUnite(\'' + u.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-danger" onclick="deleteUnite(\'' + u.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent =
        _t('unites.counter').replace('{n}', AppState.total);
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.loadUnites = loadUnites;
window.loadStats = loadStats;
window.renderTable = renderTable;
