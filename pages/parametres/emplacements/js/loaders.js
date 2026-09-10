// loaders.js
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
            showToast('Erreur', data.message || 'Impossible de charger les emplacements', 'error');
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
            document.getElementById('statTotal').textContent = data.total ?? 0;
            document.getElementById('statActifs').textContent = data.actifs ?? 0;
            document.getElementById('statInactifs').textContent = data.inactifs ?? 0;
            document.getElementById('statSousEmplacements').textContent = data.sousEmplacements ?? 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (e) {
        console.error('Erreur lors du chargement des stats :', e);
    }
}

async function loadDropdowns() {
    // Types
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.TYPES;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.types = data.Types || [];
            populateSelect('emplacementType', AppState.types, 'VALUE', 'LABEL');
            populateSelect('type-filter', AppState.types, 'VALUE', 'LABEL', true);
        }
    } catch (e) { /* ignore */ }

    // Parents
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.PARENTS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.parents = data.Parents || [];
            populateSelect('emplacementParent', AppState.parents, 'ID', 'NOM');
            populateSelect('parent-filter', AppState.parents, 'ID', 'NOM', true);
        }
    } catch (e) { /* ignore */ }
}

function populateSelect(selectId, data, valueKey, textKey, addEmpty) {
    var select = document.getElementById(selectId);
    if (!select) return;
    select.innerHTML = '';
    if (addEmpty) {
        var emptyOpt = document.createElement('option');
        emptyOpt.value = '';
        emptyOpt.textContent = 'Tous';
        select.appendChild(emptyOpt);
    }
    data.forEach(function(item) {
        var opt = document.createElement('option');
        opt.value = item[valueKey];
        opt.textContent = item[textKey];
        select.appendChild(opt);
    });
}

function renderTable(emplacements) {
    var tbody = document.getElementById('emplacementsTableBody');
    if (!emplacements || !emplacements.length) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">Aucun emplacement trouvé</td></tr>';
        document.getElementById('resultsCounter').textContent = '0 emplacement(s)';
        return;
    }
    var html = '';
    emplacements.forEach(function(e) {
        var statusHtml = e.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">✓ Actif</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">✗ Inactif</span>';
        var codeHtml = '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + (e.CODE || '') + '</span>';
        var nomHtml = '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">' + (e.NOM || '') + '</span>';
        html += '<tr>' +
            '<td>' + codeHtml + '</td>' +
            '<td>' + nomHtml + '</td>' +
            '<td>' + (e.TYPE || '') + '</td>' +
            '<td>' + (e.PARENT_NOM || '') + '</td>' +
            '<td>' + statusHtml + '</td>' +
            '<td>' +
            '<button type="button" class="btn btn-sm btn-info" onclick="viewEmplacement(\'' + e.ID + '\')" title="Voir détails"><i class="fas fa-eye"></i></button> ' +
            '<button type="button" class="btn btn-sm btn-primary" onclick="editEmplacement(\'' + e.ID + '\')"><i class="fas fa-edit"></i></button> ' +
            '<button type="button" class="btn btn-sm btn-danger" onclick="deleteEmplacement(\'' + e.ID + '\')"><i class="fas fa-trash"></i></button>' +
            '</td>' +
            '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = AppState.total + ' emplacement(s)';
}

// Exports
window.loadEmplacements = loadEmplacements;
window.loadStats = loadStats;
window.loadDropdowns = loadDropdowns;
window.populateSelect = populateSelect;
window.renderTable = renderTable;
