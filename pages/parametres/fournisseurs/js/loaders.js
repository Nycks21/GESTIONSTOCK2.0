// loaders.js
async function loadFournisseurs(options = {}) {
    const silent = !!(options && options.silent);
    if (!silent) showSpinner();
    try {
        const params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            actif: AppState.filters.actif,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        const url = `${API.BASE}${API.HANDLERS_PATH}${API.LIST}?${params}`;
        const resp = await fetch(url);
        const data = await resp.json();
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
            showToast('Erreur', data.message || 'Impossible de charger les fournisseurs', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadFournisseurStats() {
    try {
        const url = `${API.BASE}${API.HANDLERS_PATH}${API.STATS}`;
        const resp = await fetch(url);
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();
        if (data.success) {
            document.getElementById('statTotal').textContent = data.total ?? 0;
            document.getElementById('statActif').textContent = data.actif ?? 0;
            document.getElementById('statInactif').textContent = data.inactif ?? 0;
            document.getElementById('statAvecEmail').textContent = data.avecEmail ?? 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (e) {
        console.error('Erreur stats :', e);
        showToast('Erreur', 'Impossible de charger les statistiques', 'error');
    }
}

function renderFournisseursTable(fournisseurs) {
    const tbody = document.getElementById('fournisseursTableBody');
    if (!fournisseurs.length) {
        tbody.innerHTML = `<tr><td colspan="9" class="text-center">Aucun fournisseur trouvé</td></tr>`;
        document.getElementById('resultsCounter').textContent = '0 fournisseur(s)';
        return;
    }
    let html = '';
    fournisseurs.forEach(f => {
        const statusHtml = f.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">✓ Actif</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">✗ Inactif</span>';
        const codeHtml = f.CODE
            ? '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + f.CODE + '</span>'
            : '<span class="badge bg-secondary" style="color:#6c757d; background-color:#f8f9fa; padding:4px 10px; border-radius:20px;color:#333;">N/A</span>';
        html += `
            <tr>
                <td>${codeHtml}</td>
                <td><strong>${f.NOM || ''}</strong></td>
                <td>${f.ADRESSE || ''}</td>
                <td>${f.TELEPHONE || ''}</td>
                <td>${f.EMAIL || ''}</td>
                <td>${f.CONTACT_NOM || ''}</td>
                <td>${f.SIRET || ''}</td>
                <td>${statusHtml}</td>
                <td>
                    <button type="button" class="btn btn-sm btn-info" onclick="viewFournisseur('${f.ID}')" title="Voir détails"><i class="fas fa-eye"></i></button>
                    <button type="button" class="btn btn-sm btn-primary" onclick="editFournisseur('${f.ID}')"><i class="fas fa-edit"></i></button>
                    <button type="button" class="btn btn-sm btn-danger" onclick="deleteFournisseur('${f.ID}')"><i class="fas fa-trash"></i></button>
                </td>
            </tr>
        `;
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = `${AppState.total} fournisseur(s)`;
}

// expositions
window.loadFournisseurs = loadFournisseurs;
window.loadFournisseurStats = loadFournisseurStats;
window.renderFournisseursTable = renderFournisseursTable;
