// loaders.js – Version avec bouton Visualiser
async function loadUnites(options = {}) {
    const silent = !!(options && options.silent);
    if (!silent) showSpinner();
    try {
        const params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            status: AppState.filters.status,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        const url = `${API.BASE}${API.HANDLERS_PATH}${API.LIST}?${params}`;
        const resp = await fetch(url);
        const data = await resp.json();
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
            showToast('Erreur', data.message || 'Impossible de charger les unités', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadStats() {
    try {
        const url = `${API.BASE}${API.HANDLERS_PATH}${API.STATS}`;
        const resp = await fetch(url);
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();
        if (data.success) {
            document.getElementById('statTotal').textContent = data.total ?? 0;
            document.getElementById('statActives').textContent = data.actives ?? 0;
            document.getElementById('statInactives').textContent = data.inactives ?? 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (e) {
        console.error('Erreur stats :', e);
        showToast('Erreur', 'Impossible de charger les statistiques', 'error');
    }
}

function renderTable(unites) {
    const tbody = document.getElementById('unitesTableBody');
    if (!unites.length) {
        tbody.innerHTML = `<tr><td colspan="4" class="text-center">Aucune unité trouvée</td></tr>`;
        document.getElementById('resultsCounter').textContent = '0 unité(s)';
        return;
    }
    let html = '';
    unites.forEach(u => {
        const statusHtml = u.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">✓ Actif</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">✗ Inactif</span>';
        const codeHtml = u.CODE
            ? '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + u.CODE + '</span>'
            : '<span class="badge bg-secondary" style="color:#6c757d; background-color:#f8f9fa; padding:4px 10px; border-radius:20px;color:#333;">N/A</span>';
        const nomHtml = u.NOM
            ? '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">' + u.NOM + '</span>'
            : '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">N/A</span>';
        html += `
            <tr>
                <td>${codeHtml}</td>
                <td>${nomHtml}</td>
                <td>${statusHtml}</td>
                <td>
                    <button type="button" class="btn btn-sm btn-info" onclick="viewUnite('${u.ID}')" title="Voir détails"><i class="fas fa-eye"></i></button>
                    <button type="button" class="btn btn-sm btn-primary" onclick="editUnite('${u.ID}')"><i class="fas fa-edit"></i></button>
                    <button type="button" class="btn btn-sm btn-danger" onclick="deleteUnite('${u.ID}')"><i class="fas fa-trash"></i></button>
                </td>
            </tr>
        `;
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = `${AppState.total} unité(s)`;
}

// Expositions
window.loadUnites = loadUnites;
window.loadStats = loadStats;
window.renderTable = renderTable;
