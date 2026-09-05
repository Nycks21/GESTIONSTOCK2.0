// loaders.js - Module Catégories
async function loadCategories(options = {}) {
    const silent = !!(options && options.silent);
    if (!silent) {
        showSpinner();
    }
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
            AppState.categories = data.Categories || [];
            AppState.total = Number(data.total || 0);
            const computedTotalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            AppState.totalPages = computedTotalPages;
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) {
                AppState.page = AppState.totalPages;
            }
            renderTable(AppState.categories);
            loadStats();
            createPaginationControls(AppState.totalPages);
        } else {
            showToast('Erreur', data.message || 'Impossible de charger les catégories', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        if (!silent) {
            hideSpinner();
        }
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
        console.error('Erreur lors du chargement des stats :', e);
        showToast('Erreur', 'Impossible de charger les statistiques', 'error');
    }
}

async function loadParentDropdown() {
    try {
        const url = `${API.BASE}${API.HANDLERS_PATH}GetAllCategoriesForDropdown.ashx`;
        const resp = await fetch(url);
        const data = await resp.json();
        if (data.success) {
            const select = document.getElementById('categorieParent');
            if (!select) return;
            const currentId = currentCategorieId;
            select.innerHTML = '<option value="">(Aucune)</option>';
            data.Categories.forEach(cat => {
                if (cat.ID !== currentId) {
                    const opt = document.createElement('option');
                    opt.value = cat.ID;
                    opt.textContent = cat.NOM;
                    select.appendChild(opt);
                }
            });
        }
    } catch (e) {
        console.warn('Impossible de charger les catégories parents', e);
    }
}

function populateSelect(selectId, data, valueKey, textKey, addEmpty = false) {
    const select = document.getElementById(selectId);
    if (!select) return;
    select.innerHTML = '';
    if (addEmpty) {
        const opt = document.createElement('option');
        opt.value = '';
        opt.textContent = 'Toutes catégories';
        select.appendChild(opt);
    }
    data.forEach(item => {
        const opt = document.createElement('option');
        opt.value = item[valueKey];
        opt.textContent = item[textKey];
        select.appendChild(opt);
    });
}

function renderTable(categories) {
    const tbody = document.getElementById('categoriesTableBody');
    if (!categories.length) {
        tbody.innerHTML = `<tr><td colspan="5" class="text-center">Aucune catégorie trouvée</td></tr>`;
        document.getElementById('resultsCounter').textContent = '0 catégorie(s)';
        return;
    }
    let html = '';
    categories.forEach(c => {
        // Badge de statut avec style personnalisé
        const statusHtml = c.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">✓ Actif</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">✗ Inactif</span>';
        const parentNom = c.PARENT_NOM || '(Aucune)';
        const codeHtml = c.CODE
            ? '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + c.CODE + '</span>'
            : '<span class="badge bg-secondary" style="color:#6c757d; background-color:#f8f9fa; padding:4px 10px; border-radius:20px;color:#333;">N/A</span>';
        const nomHtml = c.NOM
            ? '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">' + c.NOM + '</span>'
            : '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">N/A</span>';
        html += `
            <tr>
                <td>${codeHtml}</td>
                <td>${nomHtml}</td>
                <td>${parentNom}</td>
                <td>${statusHtml}</td>
                <td>
                    <button type="button" class="btn btn-sm btn-primary" onclick="editCategorie('${c.ID}')"><i class="fas fa-edit"></i></button>
                    <button type="button" class="btn btn-sm btn-danger" onclick="deleteCategorie('${c.ID}')"><i class="fas fa-trash"></i></button>
                </td>
            </tr>
        `;
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = `${AppState.total} catégorie(s)`;
}
