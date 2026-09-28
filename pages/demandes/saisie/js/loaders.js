// ============================================================
// CHARGEMENT DES DEMANDES – SAISIE
// Version alignée sur accusés/loaders.js
//   ✅ 9 colonnes (dont Bénéficiaire)
//   ✅ Format date identique à accusés
//   ✅ Format quantité "Dem → Reçu" (formatQuantitePair)
//   ✅ Colonne DATE_RECEPTION
//   ✅ colspan dynamique
// ============================================================

if (typeof window.AppState === 'undefined') {
    window.AppState = {
        sorties: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
        sortField: 'DATE_SORTIE',
        sortOrder: 'DESC',
        filters: { search: '', statut: '' },
        articles: []
    };
}

// ============================================================
// CHARGEMENT DES DEMANDES
// ============================================================
async function loadDemandes(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();

    try {
        var params = new URLSearchParams({
            page:     AppState.page,
            pageSize: AppState.pageSize,
            search:   AppState.filters.search || '',
            statut:   AppState.filters.statut || '',
            sort:     AppState.sortField,
            order:    AppState.sortOrder
        });
        var url  = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params.toString();
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.sorties    = data.Sorties || [];
            AppState.total      = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            renderDemandesTable(AppState.sorties);
            createPaginationControls(AppState.totalPages);
            loadDemandesStats();
        } else {
            showToast(T('message.error', 'Erreur'),
                      data.message || T('saisies.msg.load_error', 'Impossible de charger les demandes'),
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
async function loadDemandesStats() {
    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            var elT = document.getElementById('statTotal');
            var elV = document.getElementById('statValide');
            var elB = document.getElementById('statBrouillon');
            var elA = document.getElementById('statAnnule');
            if (elT) elT.textContent = data.total     ?? 0;
            if (elV) elV.textContent = data.valide    ?? 0;
            if (elB) elB.textContent = data.brouillon ?? 0;
            if (elA) elA.textContent = data.annule    ?? 0;
        }
    } catch (e) {
        console.warn('Erreur stats:', e);
    }
}

// ============================================================
// ARTICLES (pour les dropdowns du modal)
// ============================================================
async function loadArticlesForSaisie() {
    try {
        var url  = API.BASE + 'pages/modules/articles/handlers/' + API.ARTICLES + '?page=1&pageSize=999999';
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
        }
    } catch (e) { /* ignore */ }
}

// ============================================================
// FORMATAGE
// ============================================================
function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return '0';
    return Number(value).toFixed(decimals || 0);
}

// ✅ Identique à accusés/loaders.js
//    Gère : ISO "yyyy-MM-dd", ISO avec T, /Date(ms)/, Date natif
function formatDateValue(value, includeTime) {
    if (value === null || value === undefined || value === "") return "-";
    var date = null;

    if (typeof value === "string") {
        var str = value.trim();
        if (!str) return "-";
        var msMatch = str.match(/-?\d+/);
        if (str.indexOf("/Date(") !== -1 && msMatch) {
            date = new Date(parseInt(msMatch[0], 10));
        } else {
            date = new Date(str);
        }
    } else if (value instanceof Date) {
        date = value;
    } else {
        date = new Date(value);
    }

    if (!date || isNaN(date.getTime())) return "-";

    var options = includeTime
        ? { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }
        : { day: "2-digit", month: "2-digit", year: "numeric" };
    return date.toLocaleString("fr-FR", options);
}

// ============================================================
// BADGE STATUT
// ============================================================
function getSaisieStatusBadge(statut) {
    var baseStyle =
        'display:inline-flex;align-items:center;gap:5px;' +
        'padding:5px 12px;border-radius:20px;' +
        'font-size:11.5px;font-weight:600;letter-spacing:0.3px;' +
        'text-transform:uppercase;white-space:nowrap;';

    var lblBrouillon = T('saisies.status.brouillon', 'En cours');
    var lblValide    = T('saisies.status.valide',    'Validé');
    var lblAnnule    = T('saisies.status.annule',    'Annulé');

    var badges = {
        BROUILLON:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#64b5f6,#2196f3);' +
                'color:#fff;box-shadow:0 2px 6px rgba(33,150,243,0.35);">' +
                '<i class="fas fa-pencil-alt" style="font-size:10px;"></i> ' + lblBrouillon +
            '</span>',
        VALIDE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#66bb6a,#4caf50);' +
                'color:#fff;box-shadow:0 2px 6px rgba(76,175,80,0.35);">' +
                '<i class="fas fa-check-circle" style="font-size:10px;"></i> ' + lblValide +
            '</span>',
        ANNULE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ef5350,#f44336);' +
                'color:#fff;box-shadow:0 2px 6px rgba(244,67,54,0.35);">' +
                '<i class="fas fa-times-circle" style="font-size:10px;"></i> ' + lblAnnule +
            '</span>'
    };
    return badges[statut] || ('<span style="' + baseStyle +
        'background:#e2e3e5;color:#383d41;">' + (statut || '—') + '</span>');
}

// ═══════════════════════════════════════════════════════════
// Rendu "Dem → Reçu" (identique à accusés)
//   - Vert  : Qté demandée == Qté reçue
//   - Orange: quantités différentes (réception partielle)
// ═══════════════════════════════════════════════════════════
function formatQuantitePair(quantiteD, quantiteR) {
    var qD = Number(quantiteD);
    var qR = Number(quantiteR);
    var isMatch = !isNaN(qD) && !isNaN(qR) && qD === qR;
    var colorR = isMatch ? '#28a745' : '#ff9800';
    var tooltipR = isMatch
        ? 'Réception complète'
        : 'Réception partielle (écart : ' + (qR - qD).toFixed(2) + ')';

    return '' +
        '<div style="display:flex;align-items:center;justify-content:flex-end;gap:6px;white-space:nowrap;">' +
            '<span style="color:#6c757d;font-size:12px;" title="Quantité demandée">' +
                formatNumber(qD, 2) +
            '</span>' +
            '<i class="fas fa-arrow-right" style="color:#adb5bd;font-size:9px;"></i>' +
            '<span style="color:' + colorR + ';font-weight:700;font-size:13px;" title="' + tooltipR + '">' +
                formatNumber(qR, 2) +
            '</span>' +
        '</div>';
}

// ============================================================
// RENDU DU TABLEAU (9 colonnes = 9 <td>)
//   1. N°            2. Date sortie     3. Date réception
//   4. Articles      5. Qté demandée    6. Destination
//   7. Bénéficiaire  8. Statut          9. Actions
// ============================================================
function renderDemandesTable(sorties) {
    var tbody = document.getElementById('saisieTableBody');
    if (!tbody) return;

    var noDat = T('saisies.msg.no_data', 'Aucune demande trouvée');
    var noArt = T('saisies.msg.no_article', 'Aucun article');
    var dash  = T('saisies.msg.dash', '—');
    var btnView   = T('sorties.btn.view',   'Voir détails');
    var btnEdit   = T('button.edit',        'Modifier');
    var btnDelete = T('button.delete',      'Supprimer');

    if (!sorties.length) {
        // ✅ 9 colonnes → colspan="9"
        tbody.innerHTML = '<tr><td colspan="9" class="text-center">' + noDat + '</td></tr>';
        var c0 = document.getElementById('resultsCounter');
        if (c0) c0.textContent = T('saisies.counter.zero', '0 demande(s)');
        return;
    }

    var html = '';
    sorties.forEach(function (s) {
        var statut = s.STATUT;
        var statutBadge = getSaisieStatusBadge(statut);
        var lignes = s.Lignes || [];

        // ─── Articles ───
        var articlesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-article-item"><span>' +
                    (ligne.ARTICLE_CODE ? ligne.ARTICLE_CODE + ' - ' : '') +
                    (ligne.ARTICLE_NOM || ligne.ARTICLE_ID || '') +
                    '</span></div>';
            }).join('')
            : '<span class="text-muted">' + noArt + '</span>';

        // ─── Quantités : "Dem → Reçu" si QUANTITE_R renseignée, sinon Qté demandée seule ───
        var quantitesHtml = lignes.length
            ? lignes.map(function (ligne) {
                var qD = Number(ligne.QUANTITE_D || 0);
                var qR = Number(ligne.QUANTITE_R || 0);
                // Si la réception a été saisie (> 0), on affiche la paire
                if (ligne.QUANTITE_R !== undefined && ligne.QUANTITE_R !== null && qR > 0) {
                    return '<div class="bon-quantity-item">' +
                        formatQuantitePair(qD, qR) +
                    '</div>';
                }
                return '<div class="bon-quantity-item" ' +
                       'style="text-align:right;font-weight:700;color:#212529;">' +
                    formatNumber(qD, 2) +
                '</div>';
            }).join('')
            : '<span class="text-muted">-</span>';

        // ─── Date réception ───
        var dateReceptionHtml = s.DATE_RECEPTION
            ? '<span style="color:#009688;font-weight:600;font-size:12.5px;">' +
                  '<i class="fas fa-calendar-check" style="margin-right:4px;opacity:0.7;"></i>' +
                  formatDateValue(s.DATE_RECEPTION, false) + '</span>'
            : '<span class="text-muted" style="font-size:12px;">' + dash + '</span>';

        // ─── Bénéficiaire (NOM + FONCTION en sous-titre) ───
        var beneficiaireHtml =
            '<div style="display:flex;flex-direction:column;gap:2px;">' +
                '<strong style="font-size:13px;color:#212529;">' +
                    (s.NOM || dash) +
                '</strong>' +
                (s.FONCTION
                    ? '<small style="font-size:11px;color:#6c757d;">' +
                          '<i class="fas fa-user-tie" style="opacity:0.7;margin-right:3px;"></i>' +
                          s.FONCTION +
                      '</small>'
                    : '') +
            '</div>';

        // ─── Actions ───
        var actionsHtml = '';
        actionsHtml +=
            '<button type="button" class="btn-icon btn-info" ' +
            'onclick="viewDemande(\'' + s.ID + '\')" title="' + btnView + '">' +
            '<i class="fas fa-eye"></i></button>';

        if (statut === 'BROUILLON') {
            actionsHtml +=
                '<button type="button" class="btn-icon btn-primary" ' +
                'onclick="editDemande(\'' + s.ID + '\')" title="' + btnEdit + '">' +
                '<i class="fas fa-edit"></i></button>';

            actionsHtml +=
                '<button type="button" class="btn-icon btn-danger" ' +
                'onclick="deleteDemande(\'' + s.ID + '\')" title="' + btnDelete + '">' +
                '<i class="fas fa-trash"></i></button>';
        }

        // ─── Ligne complète (9 <td>) ───
        html += '<tr>' +
            '<td><strong><span class="badge bg-secondary" style="color:#333;font-weight:bold;' +
                'background-color:#e9e9e9;padding:4px 10px;border-radius:20px;">' +
                s.NUMERO +
            '</span></strong></td>' +

            '<td>' + formatDateValue(s.DATE_SORTIE, true) + '</td>' +

            '<td>' + dateReceptionHtml + '</td>' +

            '<td class="bon-articles-cell">' + articlesHtml + '</td>' +

            '<td class="bon-quantities-cell">' + quantitesHtml + '</td>' +

            '<td><strong>' + (s.DESTINATION || '') + '</strong></td>' +

            '<td>' + beneficiaireHtml + '</td>' +

            '<td>' + statutBadge + '</td>' +

            '<td>' + actionsHtml + '</td>' +
        '</tr>';
    });

    tbody.innerHTML = html;

    var cEl = document.getElementById('resultsCounter');
    if (cEl) cEl.textContent = T('saisies.counter', '{n} demande(s)', { n: AppState.total });
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.loadDemandes          = loadDemandes;
window.loadDemandesStats     = loadDemandesStats;
window.loadArticlesForSaisie = loadArticlesForSaisie;
window.renderDemandesTable   = renderDemandesTable;
window.getSaisieStatusBadge  = getSaisieStatusBadge;
window.formatDateValue       = formatDateValue;
window.formatNumber          = formatNumber;
window.formatQuantitePair    = formatQuantitePair;
