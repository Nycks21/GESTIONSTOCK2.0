// loaders.js
async function loadArticles(options = {}) {
    const silent = !!(options && options.silent);
    if (!silent) {
        showSpinner();
    }
    try {
        const params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            category: AppState.filters.category,
            status: AppState.filters.status,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        const url = `${API.BASE}${API.HANDLERS_PATH}${API.LIST}?${params}`;
        const resp = await fetch(url);
        const data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
            AppState.total = Number(data.total || 0);
            const computedTotalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            AppState.totalPages = computedTotalPages;
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) {
                AppState.page = AppState.totalPages;
            }
            renderTable(AppState.articles);
            loadStats(); // ← appel corrigé
            createPaginationControls(AppState.totalPages);
        } else {
            showToast('Erreur', data.message || 'Impossible de charger les articles', 'error');
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
            document.getElementById('statNormal').textContent = data.normal ?? 0;
            document.getElementById('statAlerte').textContent = data.alerte ?? 0;
            document.getElementById('statRupture').textContent = data.rupture ?? 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (e) {
        console.error('Erreur lors du chargement des stats :', e);
        showToast('Erreur', 'Impossible de charger les statistiques', 'error');
    }
}

async function loadDropdowns() {
    // Catégories
    try {
        const url = `${API.BASE}${API.HANDLERS_PATH}${API.CATEGORIES}`;
        const resp = await fetch(url);
        const data = await resp.json();
        if (data.success) {
            AppState.categories = data.Categories || [];
            populateSelect('articleCategorie', AppState.categories, 'ID', 'NOM');
            populateSelect('category-filter', AppState.categories, 'ID', 'NOM', true);
        }
    } catch (e) { /* ignore */ }

    // Fournisseurs
    try {
        const url = `${API.BASE}${API.HANDLERS_PATH}${API.FOURNISSEURS}`;
        const resp = await fetch(url);
        const data = await resp.json();
        if (data.success) {
            AppState.fournisseurs = data.Fournisseurs || [];
            populateSelect('articleFournisseur', AppState.fournisseurs, 'ID', 'NOM');
        }
    } catch (e) { /* ignore */ }

    // Unités
    try {
        const url = `${API.BASE}${API.HANDLERS_PATH}${API.UNITES}`;
        const resp = await fetch(url);
        const data = await resp.json();
        if (data.success) {
            AppState.unites = data.Unites || [];
            populateSelect('articleUnite', AppState.unites, 'ID', 'NOM');
        }
    } catch (e) { /* ignore */ }
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

function renderTable(articles) {
    const tbody = document.getElementById('articlesTableBody');
    if (!articles.length) {
        tbody.innerHTML = `<tr><td colspan="9" class="text-center">Aucun article trouvé</td></tr>`;
        document.getElementById('resultsCounter').textContent = '0 article(s)';
        return;
    }
    let html = '';
    articles.forEach(a => {
        // Nouveaux badges avec style inline (conforme à la demande)
        const statusHtml = a.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">✓ Actif</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">✗ Inactif</span>';
        const codeHtml = a.CODE
            ? '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + a.CODE + '</span>'
            : '<span class="badge bg-secondary" style="color:#6c757d; background-color:#f8f9fa; padding:4px 10px; border-radius:20px;color:#333;">N/A</span>';
        const nomHtml = a.NOM
            ? '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">' + a.NOM + '</span>'
            : '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">N/A</span>';
        html += `
            <tr>
                <td>${codeHtml}</td>
                <td>${nomHtml}</td>
                <td>${a.CATEGORIE || ''}</td>
                <td>${a.FOURNISSEUR || ''}</td>
                <td>${a.UNITE || ''}</td>
                <td>${a.STOCK_DISPONIBLE}</td>
                <td>${a.SEUIL_ALERTE}</td>
                <td>${statusHtml}</td>
                <td>
                    <button type="button" class="btn btn-sm btn-primary" onclick="editArticle('${a.ID}')"><i class="fas fa-edit"></i></button>
                    <button type="button" class="btn btn-sm btn-danger" onclick="deleteArticle('${a.ID}')"><i class="fas fa-trash"></i></button>
                </td>
            </tr>
        `;
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = `${AppState.total} article(s)`;
}
