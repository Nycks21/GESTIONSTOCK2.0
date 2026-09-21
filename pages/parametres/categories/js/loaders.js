// loaders.js - Module Catégories avec bouton Visualiser + i18n
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// CHARGEMENT DE LA LISTE
// ============================================================
async function loadCategories(options) {
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
            AppState.categories = data.Categories || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) {
                AppState.page = AppState.totalPages;
            }
            renderTable(AppState.categories);
            loadStats();
            createPaginationControls(AppState.totalPages);
        } else {
            showToast(_t('message.error'), data.message || _t('categories.msg.load_error'), 'error');
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
        console.error('Erreur lors du chargement des stats :', err);
        showToast(_t('message.error'), _t('categories.msg.stats_error'), 'error');
    }
}

// ============================================================
// CHARGEMENT DU DROPDOWN PARENT
// ============================================================
async function loadParentDropdown(callback) {
    try {
        var url = API.BASE + API.HANDLERS_PATH + 'GetAllCategoriesForDropdown.ashx';
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            var select = document.getElementById('categorieParent');
            if (!select) return;
            var currentId = currentCategorieId;
            select.innerHTML = '<option value="">' + _t('categories.modal.parent_none') + '</option>';
            data.Categories.forEach(function (cat) {
                if (cat.ID !== currentId) {
                    var opt = document.createElement('option');
                    opt.value = cat.ID;
                    opt.textContent = cat.NOM;
                    select.appendChild(opt);
                }
            });
            if (typeof callback === 'function') callback();
        }
    } catch (err) {
        console.warn('Impossible de charger les catégories parents', err);
        if (typeof callback === 'function') callback();
    }
}

// ============================================================
// PEUPLEMENT GÉNÉRIQUE D'UN SELECT
// ============================================================
function populateSelect(selectId, data, valueKey, textKey, addEmpty) {
    var select = document.getElementById(selectId);
    if (!select) return;
    select.innerHTML = '';
    if (addEmpty) {
        var opt0 = document.createElement('option');
        opt0.value = '';
        opt0.textContent = _t('categories.filter.all');
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
function renderTable(categories) {
    var tbody = document.getElementById('categoriesTableBody');
    if (!categories.length) {
        tbody.innerHTML = '<tr><td colspan="5" class="text-center">' + _t('categories.msg.no_data') + '</td></tr>';
        document.getElementById('resultsCounter').textContent = _t('categories.counter').replace('{n}', 0);
        return;
    }

    var html = '';
    categories.forEach(function (c) {
        var statusHtml = c.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">' + _t('categories.status.active') + '</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">' + _t('categories.status.inactive') + '</span>';

        var parentNom = c.PARENT_NOM || _t('categories.modal.parent_none');

        var codeHtml = c.CODE
            ? '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + c.CODE + '</span>'
            : '<span class="badge bg-secondary" style="color:#6c757d; background-color:#f8f9fa; padding:4px 10px; border-radius:20px;color:#333;">N/A</span>';

        var nomHtml = c.NOM
            ? '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">' + c.NOM + '</span>'
            : '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">N/A</span>';

        html += '<tr>'
            + '<td>' + codeHtml + '</td>'
            + '<td>' + nomHtml + '</td>'
            + '<td>' + parentNom + '</td>'
            + '<td>' + statusHtml + '</td>'
            + '<td>'
            +   '<button type="button" class="btn btn-sm btn-info" onclick="viewCategorie(\'' + c.ID + '\')" title="' + _t('categories.action.view_details') + '"><i class="fas fa-eye"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-primary" onclick="editCategorie(\'' + c.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-danger" onclick="deleteCategorie(\'' + c.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent =
        _t('categories.counter').replace('{n}', AppState.total);
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.loadCategories = loadCategories;
window.loadStats = loadStats;
window.loadParentDropdown = loadParentDropdown;
window.populateSelect = populateSelect;
window.renderTable = renderTable;
