// loaders.js — Module ENTRÉES (design moderne aligné sur SORTIE)

// ============================================================
// SÉCURITÉ : garantir que AppState existe
// ============================================================
if (typeof window.AppState === "undefined") {
    window.AppState = {
        entrees: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
        sortField: "DATE_ENTREE",
        sortOrder: "DESC",
        filters: { search: "", fournisseur: "", statut: "" },
        editingId: null,
        fournisseurs: [],
        articles: []
    };
}

// ============================================================
// CHARGEMENT DES BONS D'ENTRÉE
// ============================================================
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

// ============================================================
// STATS
// ============================================================
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

// ============================================================
// DROPDOWNS (fournisseurs + articles)
// ============================================================
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
            document.querySelectorAll('.ligne-article').forEach(function (sel) {
                var currentVal = sel.value;
                sel.innerHTML = '<option value="">-- Article --</option>' +
                    AppState.articles.map(function (a) {
                        return '<option value="' + a.ID + '">' + a.CODE + ' - ' + a.NOM + '</option>';
                    }).join('');
                sel.value = currentVal;
                if (typeof refreshArticleSelect === 'function') {
                    refreshArticleSelect(sel);
                }
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

// ============================================================
// UTILITAIRES DE FORMATAGE
// ============================================================
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
        day: '2-digit', month: '2-digit', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    } : {
        day: '2-digit', month: '2-digit', year: 'numeric'
    };

    return date.toLocaleString('fr-FR', options);
}

function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return '0';
    return Number(value).toFixed(decimals || 0);
}

// ============================================================
// ✅ BADGE DE STATUT MODERNE (dégradé + icône)
// ============================================================
function getEntreeStatusBadge(statut) {
    var baseStyle =
        'display:inline-flex;align-items:center;gap:5px;' +
        'padding:5px 12px;border-radius:20px;' +
        'font-size:11.5px;font-weight:600;letter-spacing:0.3px;' +
        'text-transform:uppercase;white-space:nowrap;';

    var badges = {
        BROUILLON:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#64b5f6,#2196f3);' +
                'color:#fff;box-shadow:0 2px 6px rgba(33,150,243,0.35);">' +
                '<i class="fas fa-pencil-alt" style="font-size:10px;"></i> En cours' +
            '</span>',
        VALIDE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#66bb6a,#4caf50);' +
                'color:#fff;box-shadow:0 2px 6px rgba(76,175,80,0.35);">' +
                '<i class="fas fa-check-circle" style="font-size:10px;"></i> Validé' +
            '</span>',
        ANNULE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ef5350,#f44336);' +
                'color:#fff;box-shadow:0 2px 6px rgba(244,67,54,0.35);">' +
                '<i class="fas fa-times-circle" style="font-size:10px;"></i> Annulé' +
            '</span>'
    };

    return badges[statut] || ('<span style="' + baseStyle +
        'background:#e2e3e5;color:#383d41;">' + (statut || '—') + '</span>');
}

// ============================================================
// ✅ UTILITAIRE : formatage monétaire avec séparateur de milliers
//    Exemple : 1234567.89 → "1 234 567,89"
// ============================================================
function formatCurrency(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return '0';
    var n = Number(value);
    var d = (decimals === undefined) ? 2 : decimals;
    return n.toLocaleString('fr-FR', {
        minimumFractionDigits: d,
        maximumFractionDigits: d
    });
}

// ============================================================
// ✅ RENDU DU TABLEAU
// ============================================================
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
        var statut = e.STATUT;

        // ─── BADGE MODERNE ───
        var statutBadge = getEntreeStatusBadge(statut);

        var lignes = e.Lignes || [];

        var articlesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-article-item">' +
                    '<span>' + (ligne.ARTICLE_CODE ? ligne.ARTICLE_CODE + ' - ' : '') +
                    (ligne.ARTICLE_NOM || ligne.ARTICLE_ID || '') + '</span>' +
                    '</div>';
            }).join('')
            : '<span class="text-muted">Aucun article</span>';

        var quantitesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-quantity-item">' + formatNumber(ligne.QUANTITE, 2) + '</div>';
            }).join('')
            : '<span class="text-muted">-</span>';

        // ─────────────────────────────────────────────────────────
        // ACTIONS (boutons rectangulaires avec texte)
        // ─────────────────────────────────────────────────────────
        var actionsHtml = '<div class="actions-cell-wrap">';

        // 1. Visualiser (toujours présent)
        actionsHtml +=
            '<button type="button" class="btn-icon btn-info" ' +
            'onclick="viewEntree(\'' + e.ID + '\')" title="Voir détails">' +
            '<i class="fas fa-eye"></i><span></span></button>';

        // 2. Actions si statut != VALIDE
        if (statut !== 'VALIDE') {
            // 2.1 Modifier
            actionsHtml +=
                '<button type="button" class="btn-icon btn-primary" ' +
                'onclick="editEntree(\'' + e.ID + '\')" title="Modifier">' +
                '<i class="fas fa-edit"></i><span></span></button>';

            // 2.2 Supprimer
            actionsHtml +=
                '<button type="button" class="btn-icon btn-danger" ' +
                'onclick="deleteEntree(\'' + e.ID + '\')" title="Supprimer">' +
                '<i class="fas fa-trash"></i><span></span></button>';

            // 2.3 Valider (uniquement pour BROUILLON)
            if (statut === 'BROUILLON') {
                actionsHtml +=
                    '<button type="button" class="btn-icon btn-success btn-pulse" ' +
                    'onclick="validerEntree(\'' + e.ID + '\')" title="Valider le bon">' +
                    '<i class="fas fa-check"></i><span></span></button>';
            }
        }

        actionsHtml += '</div>';

        html += '<tr>' +
            '<td><strong>' + e.NUMERO + '</strong></td>' +
            '<td>' + formatDateValue(e.DATE_ENTREE, true) + '</td>' +
            '<td class="bon-articles-cell">' + articlesHtml + '</td>' +
            '<td class="bon-quantities-cell">' + quantitesHtml + '</td>' +
            '<td>' + statutBadge + '</td>' +
            '<td style="text-align:right;"><strong>' + formatCurrency(e.TOTAL_TTC, 2) + '</strong></td>' +
            '<td>' + actionsHtml + '</td>' +
            '</tr>';
    });

    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = AppState.total + ' bon(s)';
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.formatDateValue = formatDateValue;
window.formatNumber = formatNumber;
window.loadEntrees = loadEntrees;
window.loadEntreeStats = loadEntreeStats;
window.loadDropdownsEntree = loadDropdownsEntree;
window.renderEntreesTable = renderEntreesTable;
window.populateSelect = populateSelect;
window.getEntreeStatusBadge = getEntreeStatusBadge;
