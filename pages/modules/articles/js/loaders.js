// loaders.js

async function loadArticles(options) {
    const silent = !!(options && options.silent);
    if (!silent) showSpinner();
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
        const url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        const resp = await fetch(url);
        const data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 1);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages)
                AppState.page = AppState.totalPages;
            renderTable(AppState.articles);
            createPaginationControls(AppState.totalPages);
        } else {
            showToast('Erreur', data.message || 'Impossible de charger les articles', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadStats() {
    try {
        const url = API.BASE + API.HANDLERS_PATH + API.STATS;
        const resp = await fetch(url);
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
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
        console.error('Erreur stats :', e);
        showToast('Erreur', 'Impossible de charger les statistiques', 'error');
    }
}

async function loadDropdowns() {
    // Catégories
    try {
        const resp = await fetch(API.BASE + API.HANDLERS_PATH + API.CATEGORIES);
        const data = await resp.json();
        if (data.success) {
            AppState.categories = data.Categories || [];
            populateSelect('articleCategorie', AppState.categories, 'ID', 'NOM', true, '-- Sélectionner Catégorie --');
            populateSelect('category-filter', AppState.categories, 'ID', 'NOM', true, 'Toutes catégories');
        }
    } catch (e) { /* ignore */ }

    // Fournisseurs
    try {
        const resp = await fetch(API.BASE + API.HANDLERS_PATH + API.FOURNISSEURS);
        const data = await resp.json();
        if (data.success) {
            AppState.fournisseurs = data.Fournisseurs || [];
            populateSelect('articleFournisseur', AppState.fournisseurs, 'ID', 'NOM', true, '-- Sélectionner Fournisseur --');
        }
    } catch (e) { /* ignore */ }

    // Unités
    try {
        const resp = await fetch(API.BASE + API.HANDLERS_PATH + API.UNITES);
        const data = await resp.json();
        if (data.success) {
            AppState.unites = data.Unites || [];
            populateSelect('articleUnite', AppState.unites, 'ID', 'NOM', true, '-- Sélectionner Unité --');
        }
    } catch (e) { /* ignore */ }

    // Emplacements
    try {
        const resp = await fetch(API.BASE + API.HANDLERS_PATH + API.EMPLACEMENTS + '?pageSize=999999');
        const data = await resp.json();
        if (data.success) {
            AppState.emplacements = data.Emplacements || [];
            populateSelect('articleEmplacement', AppState.emplacements, 'ID', 'NOM', true, '-- Sélectionner Emplacement --');
        }
    } catch (e) { /* ignore */ }
}

function populateSelect(selectId, data, valueKey, textKey, addEmpty, emptyText) {
    const select = document.getElementById(selectId);
    if (!select) return;
    const currentValue = select.value;
    select.innerHTML = '';
    if (addEmpty) {
        const opt = document.createElement('option');
        opt.value = '';
        opt.textContent = emptyText || '-- Sélectionner --';
        select.appendChild(opt);
    }
    data.forEach(item => {
        const opt = document.createElement('option');
        opt.value = item[valueKey];
        opt.textContent = item[textKey];
        select.appendChild(opt);
    });
    if (currentValue) {
        let exists = false;
        for (let i = 0; i < select.options.length; i++) {
            if (select.options[i].value == currentValue) {
                exists = true;
                break;
            }
        }
        if (exists) select.value = currentValue;
    }
}

function renderTable(articles) {
    const tbody = document.getElementById('articlesTableBody');
    if (!articles || !articles.length) {
        tbody.innerHTML = '<tr><td colspan="9" class="text-center">Aucun article trouvé</td></tr>';
        document.getElementById('resultsCounter').textContent = '0 article(s)';
        return;
    }
    let html = '';
    articles.forEach(a => {
        const statusHtml = a.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">✓ Actif</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">✗ Inactif</span>';
        const statutStock = a.STATUT_STOCK || 'normal';
        let statutBadge = '';
        if (statutStock === 'normal') statutBadge = '<span class="badge bg-success" style=" display: inline-block; min-width: 50px; text-align: center; padding: 3px 8px; border: 1px solid #f0f0f0; border-radius: 8px; background:#28a745;color:white;">Normal</span>';
        else if (statutStock === 'alerte') statutBadge = '<span class="badge bg-warning" style=" display: inline-block; min-width: 50px; text-align: center; padding: 3px 8px; border: 1px solid #f0f0f0; border-radius: 8px; background:#ffc107;color:#212529;">Alerte</span>';
        else if (statutStock === 'rupture') statutBadge = '<span class="badge bg-danger" style="display: inline-block; min-width: 50px; text-align: center; padding: 3px 8px; border: 1px solid #f0f0f0; border-radius: 8px; background:#dc3545;color:white;">Rupture</span>';
        else statutBadge = '<span class="badge bg-secondary">Indéfini</span>';

        html += `<tr>
            <td><span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">${a.CODE || ''}</span></td>
            <td><span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">${a.NOM || ''}</span></td>
            <td>${a.CATEGORIE_NOM || ''}</td>
            <td>${a.FOURNISSEUR_NOM || ''}</td>
            <td>${a.UNITE_SYMBOLE || a.UNITE || ''}</td>
            <td><span style="display: inline-block; min-width: 50px; text-align: center; padding: 3px 8px; border-radius: 8px; background-color: #007bff; color: #ffffff; font-weight: 700; font-size: 14px;">${a.STOCK_TOTAL || 0}</span></td>
            <td><span style="display: inline-block; min-width: 50px; text-align: center; padding: 3px 8px; border: 1px solid #f0f0f0; border-radius: 8px;">${a.SEUIL_MIN || 0}</span></td>
            <td><span style="display: inline-block; min-width: 50px; text-align: center; padding: 3px 8px; border: 1px solid #f0f0f0; border-radius: 8px;">${a.SEUIL_ALERTE || 0}</span></td>
            <td>${statutBadge}</td>
            <td>
                <button type="button" class="btn btn-sm btn-primary" onclick="editArticle('${a.ID}')"><i class="fas fa-edit"></i></button>
                <button type="button" class="btn btn-sm btn-danger" onclick="deleteArticle('${a.ID}')"><i class="fas fa-trash"></i></button>
                <button type="button" class="btn btn-sm btn-info" onclick="viewHistory('${a.ID}', '')"><i class="fas fa-history"></i></button>
            </td>
        </tr>`;
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = AppState.total + ' article(s)';
}

window.loadArticles = loadArticles;
window.loadStats = loadStats;
window.loadDropdowns = loadDropdowns;
window.populateSelect = populateSelect;
window.renderTable = renderTable;
