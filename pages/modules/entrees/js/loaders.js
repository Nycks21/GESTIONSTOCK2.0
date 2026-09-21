// loaders.js — Module ENTRÉES
// ⚠️ Aucun objet ENTREE_I18N. Utilise directement T() défini dans utils.js

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
            page:        AppState.page,
            pageSize:    AppState.pageSize,
            search:      AppState.filters.search || '',
            fournisseur: AppState.filters.fournisseur || '',
            statut:      AppState.filters.statut || '',
            sort:        AppState.sortField,
            order:       AppState.sortOrder
        });
        var url  = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params.toString();
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.entrees    = data.Entrees || [];
            AppState.total      = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            renderEntreesTable(AppState.entrees);
            createPaginationControls(AppState.totalPages);
            loadEntreeStats();
        } else {
            showToast(T('message.error', 'Erreur'),
                      data.message || T('entrees.msg.load_error', 'Impossible de charger les bons'),
                      'error');
        }
    } catch (e) {
        showToast(T('message.error', 'Erreur'), e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

// ============================================================
// STATS
// ============================================================
async function loadEntreeStats() {
    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            var elTotal     = document.getElementById('statTotal');
            var elValide    = document.getElementById('statValide');
            var elBrouillon = document.getElementById('statBrouillon');
            var elAnnule    = document.getElementById('statAnnule');

            if (elTotal)     elTotal.textContent     = data.total     ?? 0;
            if (elValide)    elValide.textContent    = data.valide    ?? 0;
            if (elBrouillon) elBrouillon.textContent = data.brouillon ?? 0;
            if (elAnnule)    elAnnule.textContent    = data.annule    ?? 0;
        }
    } catch (e) {
        console.warn('Erreur stats:', e);
    }
}

// ============================================================
// DROPDOWNS
// ============================================================
async function loadDropdownsEntree() {
    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.FOURNISSEURS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.fournisseurs = data.Fournisseurs || [];
            populateSelect('entreeFournisseur', AppState.fournisseurs, 'ID', 'NOM');
            populateSelect('fournisseur-filter', AppState.fournisseurs, 'ID', 'NOM', true);
        }
    } catch (e) { /* ignore */ }

    try {
        var url2  = API.BASE + API.HANDLERS_PATH + API.ARTICLES;
        var resp2 = await fetch(url2);
        var data2 = await resp2.json();
        if (data2.success) {
            AppState.articles = data2.Articles || [];
            document.querySelectorAll('.ligne-article').forEach(function (sel) {
                var currentVal = sel.value;
                var artPh = T('entrees.modal.lignes_article_select', '-- Article --');
                sel.innerHTML = '<option value="">' + artPh + '</option>' +
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

    var emptyLabel = T('entrees.filter.all_fournisseurs', 'Tous fournisseurs');

    select.innerHTML = '';
    if (addEmpty) {
        var opt = document.createElement('option');
        opt.value = '';
        opt.textContent = emptyLabel;
        select.appendChild(opt);
    }
    data.forEach(function (item) {
        var o = document.createElement('option');
        o.value = item[valueKey];
        o.textContent = item[textKey];
        select.appendChild(o);
    });
}

// ============================================================
// FORMATAGE
// ============================================================
function formatDateValue(value, includeTime) {
    if (value === null || value === undefined || value === '') return '-';
    var date = null;
    var str  = String(value).trim();
    if (!str) return '-';

    var m1 = str.match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?/);
    if (m1) {
        date = new Date(+m1[1], +m1[2] - 1, +m1[3], +(m1[4] || 0), +(m1[5] || 0), +(m1[6] || 0));
    } else {
        var m2 = str.match(/^\/Date\((-?\d+)\)\/$/);
        if (m2) date = new Date(+m2[1]);
        else    date = new Date(str);
    }
    if (!date || isNaN(date.getTime())) return '-';

    var pad = function (n) { return String(n).padStart(2, '0'); };
    var result = pad(date.getDate()) + '/' + pad(date.getMonth() + 1) + '/' + date.getFullYear();
    if (includeTime) result += ' ' + pad(date.getHours()) + ':' + pad(date.getMinutes());
    return result;
}

function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return '0';
    return Number(value).toFixed(decimals || 0);
}

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
// BADGE DE STATUT
// ============================================================
function getEntreeStatusBadge(statut) {
    var baseStyle =
        'display:inline-flex;align-items:center;gap:5px;' +
        'padding:5px 12px;border-radius:20px;' +
        'font-size:11.5px;font-weight:600;letter-spacing:0.3px;' +
        'text-transform:uppercase;white-space:nowrap;';

    var labelBrouillon = T('entrees.status.brouillon', 'En cours');
    var labelValide    = T('entrees.status.valide',    'Validé');
    var labelAnnule    = T('entrees.status.annule',    'Annulé');

    var badges = {
        BROUILLON:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#64b5f6,#2196f3);' +
                'color:#fff;box-shadow:0 2px 6px rgba(33,150,243,0.35);">' +
                '<i class="fas fa-pencil-alt" style="font-size:10px;"></i> ' + labelBrouillon +
            '</span>',
        VALIDE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#66bb6a,#4caf50);' +
                'color:#fff;box-shadow:0 2px 6px rgba(76,175,80,0.35);">' +
                '<i class="fas fa-check-circle" style="font-size:10px;"></i> ' + labelValide +
            '</span>',
        ANNULE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ef5350,#f44336);' +
                'color:#fff;box-shadow:0 2px 6px rgba(244,67,54,0.35);">' +
                '<i class="fas fa-times-circle" style="font-size:10px;"></i> ' + labelAnnule +
            '</span>'
    };

    return badges[statut] || ('<span style="' + baseStyle +
        'background:#e2e3e5;color:#383d41;">' + (statut || '—') + '</span>');
}

// ============================================================
// RENDU DU TABLEAU
// ============================================================
function renderEntreesTable(entrees) {
    var tbody = document.getElementById('entreesTableBody');
    if (!tbody) return;

    var dash  = T('entrees.msg.dash', '—');
    var noArt = T('entrees.msg.no_article', 'Aucun article');
    var noDat = T('entrees.msg.no_data', "Aucun bon d'entrée trouvé");
    var btnView     = T('entrees.btn.view',     'Voir détails');
    var btnEdit     = T('button.edit',          'Modifier');
    var btnDelete   = T('button.delete',        'Supprimer');
    var btnValidate = T('entrees.btn.validate', 'Valider le bon');

    if (!entrees.length) {
        tbody.innerHTML = '<tr><td colspan="9" class="text-center">' + noDat + '</td></tr>';
        var c0 = document.getElementById('resultsCounter');
        if (c0) c0.textContent = T('entrees.counter.zero', '0 bon(s)');
        return;
    }

    var html = '';
    entrees.forEach(function (e) {
        var statut = e.STATUT;
        var statutBadge = getEntreeStatusBadge(statut);
        var lignes = e.Lignes || [];

        var articlesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-article-item">' +
                    '<span>' + (ligne.ARTICLE_CODE ? ligne.ARTICLE_CODE + ' - ' : '') +
                    (ligne.ARTICLE_NOM || ligne.ARTICLE_ID || '') + '</span>' +
                    '</div>';
            }).join('')
            : '<span class="text-muted">' + noArt + '</span>';

        var refHtml = e.REFERENCE
            ? '<span style="font-weight:600;color:#495057;">' + e.REFERENCE + '</span>'
            : '<span class="text-muted">' + dash + '</span>';

        var frnsHtml = e.FOURNISSEUR
            ? '<span style="font-weight:600;color:#495057;">' + e.FOURNISSEUR + '</span>'
            : '<span class="text-muted">' + dash + '</span>';

        var quantitesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-quantity-item">' + formatNumber(ligne.QUANTITE, 2) + '</div>';
            }).join('')
            : '<span class="text-muted">-</span>';

        var actionsHtml = '<div class="actions-cell-wrap">';

        actionsHtml +=
            '<button type="button" class="btn-icon btn-info" ' +
            'onclick="viewEntree(\'' + e.ID + '\')" title="' + btnView + '">' +
            '<i class="fas fa-eye"></i></button>';

        if (statut !== 'VALIDE') {
            actionsHtml +=
                '<button type="button" class="btn-icon btn-primary" ' +
                'onclick="editEntree(\'' + e.ID + '\')" title="' + btnEdit + '">' +
                '<i class="fas fa-edit"></i></button>';

            actionsHtml +=
                '<button type="button" class="btn-icon btn-danger" ' +
                'onclick="deleteEntree(\'' + e.ID + '\')" title="' + btnDelete + '">' +
                '<i class="fas fa-trash"></i></button>';

            if (statut === 'BROUILLON') {
                actionsHtml +=
                    '<button type="button" class="btn-icon btn-success btn-pulse" ' +
                    'onclick="validerEntree(\'' + e.ID + '\')" title="' + btnValidate + '">' +
                    '<i class="fas fa-check"></i></button>';
            }
        }

        actionsHtml += '</div>';

        html +=
            '<tr>' +
                '<td><strong><span class="badge bg-secondary" ' +
                    'style="color:#333;font-weight:bold;background-color:#e9e9e9;' +
                    'padding:4px 10px;border-radius:20px;">' +
                    (e.NUMERO || '') +
                '</span></strong></td>' +
                '<td>' + formatDateValue(e.DATE_ENTREE, true) + '</td>' +
                '<td class="bon-articles-cell">' + articlesHtml + '</td>' +
                '<td class="bon-ref-cell">' + refHtml + '</td>' +
                '<td class="bon-frns-cell"><strong>' + frnsHtml + '</strong></td>' +
                '<td class="bon-quantities-cell">' + quantitesHtml + '</td>' +
                '<td>' + statutBadge + '</td>' +
                '<td style="text-align:right;"><strong>' + formatCurrency(e.TOTAL_TTC, 2) + '</strong></td>' +
                '<td>' + actionsHtml + '</td>' +
            '</tr>';
    });

    tbody.innerHTML = html;

    var counterEl = document.getElementById('resultsCounter');
    if (counterEl) {
        counterEl.textContent = T('entrees.counter', '{n} bon(s)', { n: AppState.total });
    }
}

window.formatDateValue      = formatDateValue;
window.formatNumber         = formatNumber;
window.formatCurrency       = formatCurrency;
window.loadEntrees          = loadEntrees;
window.loadEntreeStats      = loadEntreeStats;
window.loadDropdownsEntree  = loadDropdownsEntree;
window.renderEntreesTable   = renderEntreesTable;
window.populateSelect       = populateSelect;
window.getEntreeStatusBadge = getEntreeStatusBadge;
