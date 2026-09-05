async function loadEntrees(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();

    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search || '',
            fournisseur: AppState.filters.fournisseur || '',
            statut: AppState.filters.statut || '',
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params.toString();
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.entrees = data.Entrees || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            renderEntreesTable(AppState.entrees);
            createPaginationControls(AppState.totalPages);
            loadEntreeStats();
        } else {
            showToast('Erreur', data.message || 'Impossible de charger les bons', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadEntreeStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            document.getElementById('statTotal').textContent = data.total ?? 0;
            document.getElementById('statValide').textContent = data.valide ?? 0;
            document.getElementById('statBrouillon').textContent = data.brouillon ?? 0;
            document.getElementById('statAnnule').textContent = data.annule ?? 0;
        }
    } catch (e) {
        console.warn('Erreur stats:', e);
    }
}

async function loadDropdownsEntree() {
    // Fournisseurs
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.FOURNISSEURS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.fournisseurs = data.Fournisseurs || [];
            populateSelect('entreeFournisseur', AppState.fournisseurs, 'ID', 'NOM');
            populateSelect('fournisseur-filter', AppState.fournisseurs, 'ID', 'NOM', true);
        }
    } catch (e) { /* ignore */ }

    // Articles
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.ARTICLES;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
            // Mettre à jour les selects dans les lignes déjà présentes
            document.querySelectorAll('.ligne-article').forEach(function (sel) {
                var currentVal = sel.value;
                sel.innerHTML = '<option value="">-- Article --</option>' +
                    AppState.articles.map(function (a) {
                        return '<option value="' + a.ID + '">' + a.CODE + ' - ' + a.NOM + '</option>';
                    }).join('');
                sel.value = currentVal;
            });
        }
    } catch (e) { /* ignore */ }
}

function populateSelect(selectId, data, valueKey, textKey, addEmpty) {
    addEmpty = addEmpty || false;
    var select = document.getElementById(selectId);
    if (!select) return;
    select.innerHTML = '';
    if (addEmpty) {
        var opt = document.createElement('option');
        opt.value = '';
        opt.textContent = 'Tous';
        select.appendChild(opt);
    }
    data.forEach(function (item) {
        var opt = document.createElement('option');
        opt.value = item[valueKey];
        opt.textContent = item[textKey];
        select.appendChild(opt);
    });
}

function formatDateValue(value, includeTime) {
    if (value === null || value === undefined || value === '') return '-';

    var date = null;
    if (typeof value === 'string') {
        var str = value.trim();
        if (!str) return '-';

        var msMatch = str.match(/-?\d+/);
        if (str.indexOf('/Date(') !== -1 && msMatch) {
            date = new Date(parseInt(msMatch[0], 10));
        } else {
            date = new Date(str);
        }
    } else if (value instanceof Date) {
        date = value;
    } else {
        date = new Date(value);
    }

    if (!date || isNaN(date.getTime())) return '-';

    var options = includeTime ? {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    } : {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
    };

    return date.toLocaleString('fr-FR', options);
}

/**
 * Formate un nombre avec séparateur de millier et nombre de décimales fixe.
 * @param {number|string} value - La valeur à formater.
 * @param {number} decimals - Nombre de décimales (par défaut 2).
 * @returns {string} Le nombre formaté (ex: "1 234,56").
 */
function formatNumber(value, decimals) {
    decimals = decimals || 2;
    var num = parseFloat(value);
    if (isNaN(num)) return '0,00';

    // Arrondir et garder les décimales
    var fixed = num.toFixed(decimals);
    // Séparer partie entière et décimale
    var parts = fixed.split('.');
    var integerPart = parts[0];
    var decimalPart = parts[1] || '';

    // Ajouter séparateur de millier (espace) sur la partie entière
    var integerWithSpaces = integerPart.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');

    // Retourner avec la virgule comme séparateur décimal
    return integerWithSpaces + ',' + decimalPart;
}

function renderEntreesTable(entrees) {
    var tbody = document.getElementById('entreesTableBody');
    if (!tbody) return;
    if (!entrees.length) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center">Aucun bon d\'entrée trouvé</td></tr>';
        document.getElementById('resultsCounter').textContent = '0 bon(s)';
        return;
    }
    var html = '';
    entrees.forEach(function (e) {
        var statutBadge = {
            'BROUILLON': '<span class="badge bg-warning" style="background:#ffc107;color:#212529;">Brouillon</span>',
            'VALIDE': '<span class="badge bg-success" style="background:#28a745;">Validé</span>',
            'ANNULE': '<span class="badge bg-danger" style="background:#dc3545;">Annulé</span>'
        }[e.STATUT] || e.STATUT;
        html += '<tr>' +
            '<td><strong>' + e.NUMERO + '</strong></td>' +
            '<td>' + formatDateValue(e.DATE_ENTREE, true) + '</td>' +
            '<td>' + (e.FOURNISSEUR || '') + '</td>' +
            '<td>' + statutBadge + '</td>' +
            '<td style="text-align:right;"><strong>' + formatNumber(e.TOTAL_TTC, 2) + '</strong></td>' +
            '<td>' + formatDateValue(e.CREATED_AT, true) + '</td>' +
            '<td>' +
            '<button type="button" class="btn btn-sm btn-primary" onclick="editEntree(\'' + e.ID + '\')"><i class="fas fa-edit"></i></button> ' +
            '<button type="button" class="btn btn-sm btn-danger" onclick="deleteEntree(\'' + e.ID + '\')"><i class="fas fa-trash"></i></button> ' +
            (e.STATUT === 'BROUILLON' ? '<button type="button" class="btn btn-sm btn-success" onclick="validerEntree(\'' + e.ID + '\')"><i class="fas fa-check"></i></button>' : '') +
            '</td></tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = AppState.total + ' bon(s)';
}

// Expositions globales
window.formatNumber = formatNumber;
window.formatDateValue = formatDateValue;
window.loadEntrees = loadEntrees;
window.loadEntreeStats = loadEntreeStats;
window.loadDropdownsEntree = loadDropdownsEntree;
window.renderEntreesTable = renderEntreesTable;
window.populateSelect = populateSelect;
