// loaders.js - Module Emplacements + i18n
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// CHARGEMENT DE LA LISTE
// ============================================================
async function loadEmplacements(options) {
    var silent = !!(options && options.silent);
    if (!silent) showSpinner();
    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            type: AppState.filters.type,
            parent: AppState.filters.parent,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.emplacements = data.Emplacements || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages)
                AppState.page = AppState.totalPages;
            renderTable(AppState.emplacements);
            createPaginationControls(AppState.totalPages);
            loadStats();
        } else {
            showToast(_t('message.error'), data.message || _t('emplacements.msg.load_error'), 'error');
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
        var data = await resp.json();
        if (data.success) {
            document.getElementById('statTotal').textContent = data.total != null ? data.total : 0;
            document.getElementById('statActifs').textContent = data.actifs != null ? data.actifs : 0;
            document.getElementById('statInactifs').textContent = data.inactifs != null ? data.inactifs : 0;
            document.getElementById('statSousEmplacements').textContent = data.sousEmplacements != null ? data.sousEmplacements : 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (err) {
        console.error('Erreur lors du chargement des stats :', err);
    }
}

// ============================================================
// CHARGEMENT DES DROPDOWNS
// ============================================================
async function loadDropdowns() {
    // Types
    try {
        var urlTypes = API.BASE + API.HANDLERS_PATH + API.TYPES;
        var respTypes = await fetch(urlTypes);
        var dataTypes = await respTypes.json();
        if (dataTypes.success) {
            AppState.types = dataTypes.Types || [];
            populateSelect('emplacementType', AppState.types, 'VALUE', 'LABEL', false, _t('emplacements.modal.type_select'));
            populateSelect('type-filter', AppState.types, 'VALUE', 'LABEL', true, _t('emplacements.filter.all_types'));
        }
    } catch (err) { /* ignore */ }

    // Parents
    try {
        var urlParents = API.BASE + API.HANDLERS_PATH + API.PARENTS;
        var respParents = await fetch(urlParents);
        var dataParents = await respParents.json();
        if (dataParents.success) {
            AppState.parents = dataParents.Parents || [];
            populateSelect('emplacementParent', AppState.parents, 'ID', 'NOM', false, _t('emplacements.modal.parent_none'));
            populateSelect('parent-filter', AppState.parents, 'ID', 'NOM', true, _t('emplacements.filter.all_parents'));
        }
    } catch (err) { /* ignore */ }
}

// ============================================================
// PEUPLEMENT GÉNÉRIQUE D'UN SELECT
// ============================================================
function populateSelect(selectId, data, valueKey, textKey, addEmpty, emptyLabel) {
    var select = document.getElementById(selectId);
    if (!select) return;
    select.innerHTML = '';

    if (addEmpty) {
        var emptyOpt = document.createElement('option');
        emptyOpt.value = '';
        emptyOpt.textContent = emptyLabel || _t('emplacements.filter.all');
        select.appendChild(emptyOpt);
    } else if (emptyLabel) {
        var opt0 = document.createElement('option');
        opt0.value = '';
        opt0.textContent = emptyLabel;
        select.appendChild(opt0);
    }

    data.forEach(function (item) {
        var opt = document.createElement('option');
        opt.value = item[valueKey];
        opt.textContent = item[textKey];
        select.appendChild(opt);
    });
}

// ============================================================
// RENDU DU TABLEAU
// ============================================================
function renderTable(emplacements) {
    var tbody = document.getElementById('emplacementsTableBody');
    if (!emplacements || !emplacements.length) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">' + _t('emplacements.msg.no_data') + '</td></tr>';
        document.getElementById('resultsCounter').textContent = _t('emplacements.counter').replace('{n}', 0);
        return;
    }

    var html = '';
    emplacements.forEach(function (e) {
        var statusHtml = e.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">' + _t('emplacements.status.active') + '</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">' + _t('emplacements.status.inactive') + '</span>';

        var codeHtml = '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + (e.CODE || '') + '</span>';
        var nomHtml = '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">' + (e.NOM || '') + '</span>';

        html += '<tr>' +
            '<td>' + codeHtml + '</td>' +
            '<td>' + nomHtml + '</td>' +
            '<td>' + (e.TYPE || '') + '</td>' +
            '<td>' + (e.PARENT_NOM || '') + '</td>' +
            '<td>' + statusHtml + '</td>' +
            '<td>' +
            '<button type="button" class="btn btn-sm btn-info" onclick="viewEmplacement(\'' + e.ID + '\')" title="' + _t('emplacements.action.view_details') + '"><i class="fas fa-eye"></i></button> ' +
            '<button type="button" class="btn btn-sm btn-primary" onclick="editEmplacement(\'' + e.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> ' +
            '<button type="button" class="btn btn-sm btn-danger" onclick="deleteEmplacement(\'' + e.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>' +
            '</td>' +
            '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent =
        _t('emplacements.counter').replace('{n}', AppState.total);
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.loadEmplacements = loadEmplacements;
window.loadStats = loadStats;
window.loadDropdowns = loadDropdowns;
window.populateSelect = populateSelect;
window.renderTable = renderTable;
