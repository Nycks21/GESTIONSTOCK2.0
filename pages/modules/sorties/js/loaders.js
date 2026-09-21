// ============================================================
// CHARGEMENT DES DONNÉES – SORTIES
// ============================================================

function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return "0";
    return Number(value).toFixed(decimals || 0);
}

if (typeof window.AppState === "undefined") {
    window.AppState = {
        sorties: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
        sortField: "DATE_SORTIE",
        sortOrder: "DESC",
        filters: { search: "", destination: "", statut: "" },
        editingId: null,
        articles: [],
    };
}

async function loadSorties(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();

    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search || "",
            destination: AppState.filters.destination || "",
            statut: AppState.filters.statut || "",
            sort: AppState.sortField,
            order: AppState.sortOrder,
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + "?" + params.toString();
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.sorties    = data.Sorties || [];
            AppState.total      = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            renderSortiesTable(AppState.sorties);
            createPaginationControls(AppState.totalPages);
            loadSortieStats();
        } else {
            showToast(T('message.error', 'Erreur'),
                      data.message || T('sorties.msg.load_error', 'Impossible de charger les bons'),
                      'error');
        }
    } catch (e) {
        showToast(T('message.error', 'Erreur'), e.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadSortieStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            var elT = document.getElementById("statTotal");
            var elV = document.getElementById("statValide");
            var elB = document.getElementById("statBrouillon");
            var elA = document.getElementById("statAnnule");
            if (elT) elT.textContent = data.total     ?? 0;
            if (elV) elV.textContent = data.valide    ?? 0;
            if (elB) elB.textContent = data.brouillon ?? 0;
            if (elA) elA.textContent = data.annule    ?? 0;
            if (typeof updateSortieBadge === "function") {
                updateSortieBadge(data.pending);
            }
        }
    } catch (e) {
        console.warn("Erreur stats:", e);
    }
}

async function loadDropdownsSortie() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.ARTICLES + "?page=1&pageSize=999999";
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
            document.querySelectorAll(".ligne-article").forEach(function (sel) {
                var currentVal = sel.value;
                var artPh = T('sorties.modal.lignes_article_select', '-- Article --');
                sel.innerHTML =
                    '<option value="">' + artPh + '</option>' +
                    AppState.articles.map(function (a) {
                        return '<option value="' + a.ID + '">' + a.CODE + " - " + a.NOM + "</option>";
                    }).join("");
                sel.value = currentVal;
                if (typeof refreshArticleSelect === "function") {
                    refreshArticleSelect(sel);
                }
            });
        }
    } catch (e) { /* ignore */ }
}

// ─── FORMATAGE DATE ───
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

// ─── BADGE STATUT ───
function getSortieStatusBadge(statut) {
    var baseStyle =
        "display:inline-flex;align-items:center;gap:5px;" +
        "padding:5px 12px;border-radius:20px;" +
        "font-size:11.5px;font-weight:600;letter-spacing:0.3px;" +
        "text-transform:uppercase;white-space:nowrap;";

    var lblVide      = T('sorties.status.vide',      'QR vide');
    var lblBrouillon = T('sorties.status.brouillon', 'En cours');
    var lblValide    = T('sorties.status.valide',    'Validé');
    var lblAnnule    = T('sorties.status.annule',    'Annulé');
    var lblTermine   = T('sorties.status.termine',   'Reçu');

    var badges = {
        VIDE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#ffb74d,#ff9800);' +
                'color:#fff;box-shadow:0 2px 6px rgba(255,152,0,0.35);">' +
                '<i class="fas fa-qrcode" style="font-size:10px;"></i> ' + lblVide +
            '</span>',
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
            '</span>',
        TERMINE:
            '<span style="' + baseStyle +
                'background:linear-gradient(135deg,#26c6da,#009688);' +
                'color:#fff;box-shadow:0 2px 6px rgba(0,150,136,0.35);">' +
                '<i class="fas fa-check-double" style="font-size:10px;"></i> ' + lblTermine +
            '</span>',
    };
    return badges[statut] || ('<span style="' + baseStyle +
        'background:#e2e3e5;color:#383d41;">' + (statut || '—') + '</span>');
}

// ─── RENDU DU TABLEAU ───
function renderSortiesTable(sorties) {
    var tbody = document.getElementById("sortiesTableBody");
    if (!tbody) return;

    var noDat = T('sorties.msg.no_data', 'Aucun bon de sortie trouvé');
    var noArt = T('sorties.msg.no_article', 'Aucun article');
    var dash  = T('sorties.msg.dash', '—');
    var btnView     = T('sorties.btn.view',     'Voir détails');
    var btnEdit     = T('button.edit',          'Modifier');
    var btnDelete   = T('button.delete',        'Supprimer');
    var btnValidate = T('sorties.btn.validate', 'Valider la sortie');

    if (!sorties.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center">' + noDat + '</td></tr>';
        var c0 = document.getElementById("resultsCounter");
        if (c0) c0.textContent = T('sorties.counter.zero', '0 bon(s)');
        return;
    }

    var currentRoleId = typeof getCurrentUserRole === "function" ? getCurrentUserRole() : -1;
    var canValidate = currentRoleId === 0 || currentRoleId === 3;

    var html = "";
    sorties.forEach(function (s) {
        var lignes = s.Lignes || [];
        var statut = s.STATUT;

        var statutBadge = getSortieStatusBadge(statut);

        var articlesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-article-item"><span>' +
                    (ligne.ARTICLE_CODE ? ligne.ARTICLE_CODE + " - " : "") +
                    (ligne.ARTICLE_NOM || ligne.ARTICLE_ID || "") +
                    "</span></div>";
            }).join("")
            : '<span class="text-muted">' + noArt + '</span>';

        var quantitesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-quantity-item">' + formatNumber(ligne.QUANTITE_R, 2) + "</div>";
            }).join("")
            : '<span class="text-muted">-</span>';

        var dateReceptionHtml = s.DATE_RECEPTION
            ? '<span style="color:#009688;font-weight:600;font-size:12.5px;">' +
              '<i class="fas fa-calendar-check" style="margin-right:4px;opacity:0.7;"></i>' +
              formatDateValue(s.DATE_RECEPTION, false) + "</span>"
            : '<span class="text-muted" style="font-size:12px;">' + dash + '</span>';

        var allQteR = lignes.length > 0 && lignes.every(function (ligne) {
            return ligne.QUANTITE_R > 0;
        });

        var actionsHtml = "";
        actionsHtml +=
            '<button type="button" class="btn-icon btn-info" onclick="viewSortie(\'' + s.ID + '\')" title="' + btnView + '">' +
            '<i class="fas fa-eye"></i></button>';

        if (statut !== "VALIDE" && statut !== "TERMINE") {
            actionsHtml +=
                '<button type="button" class="btn-icon btn-primary" onclick="editSortie(\'' + s.ID + '\')" title="' + btnEdit + '">' +
                '<i class="fas fa-edit"></i></button>';
            actionsHtml +=
                '<button type="button" class="btn-icon btn-danger" onclick="deleteSortie(\'' + s.ID + '\')" title="' + btnDelete + '">' +
                '<i class="fas fa-trash"></i></button>';

            if (statut === "BROUILLON" && allQteR && canValidate) {
                actionsHtml +=
                    '<button type="button" class="btn-icon btn-success btn-pulse" ' +
                    'onclick="validerSortie(\'' + s.ID + '\')" title="' + btnValidate + '">' +
                    '<i class="fas fa-check"></i></button>';
            }
        }

        html +=
            "<tr>" +
            "<td><strong><span class='badge bg-secondary' style='color:#333;font-weight:bold;background-color:#e9e9e9;padding:4px 10px;border-radius:20px;'>" +
            s.NUMERO + "</span></strong></td>" +
            "<td>" + formatDateValue(s.DATE_SORTIE, true) + "</td>" +
            "<td>" + dateReceptionHtml + "</td>" +
            '<td class="bon-articles-cell">' + articlesHtml + "</td>" +
            '<td class="bon-quantities-cell">' + quantitesHtml + "</td>" +
            "<td><strong>" + (s.NOM || "") + "</strong></td>" +
            "<td>" + statutBadge + "</td>" +
            "<td>" + actionsHtml + "</td></tr>";
    });

    tbody.innerHTML = html;
    var cEl = document.getElementById("resultsCounter");
    if (cEl) cEl.textContent = T('sorties.counter', '{n} bon(s)', { n: AppState.total });
}

window.loadSorties         = loadSorties;
window.loadSortieStats     = loadSortieStats;
window.loadDropdownsSortie = loadDropdownsSortie;
window.renderSortiesTable  = renderSortiesTable;
window.formatDateValue     = formatDateValue;
window.formatNumber        = formatNumber;
window.getSortieStatusBadge = getSortieStatusBadge;
