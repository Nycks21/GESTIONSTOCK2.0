// ============================================================
// CHARGEMENT DES DONNÉES – SORTIES
// ============================================================

function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return "0";
    return Number(value).toFixed(decimals || 0);
}

// Sécurité : garantir que AppState existe
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
            AppState.sorties = data.Sorties || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(
                data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0,
            );
            renderSortiesTable(AppState.sorties);
            createPaginationControls(AppState.totalPages);
            loadSortieStats();
        } else {
            showToast("Erreur", data.message || "Impossible de charger les bons", "error");
        }
    } catch (e) {
        showToast("Erreur", e.message, "error");
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
            document.getElementById("statTotal").textContent = data.total ?? 0;
            document.getElementById("statValide").textContent = data.valide ?? 0;
            document.getElementById("statBrouillon").textContent = data.brouillon ?? 0;
            document.getElementById("statAnnule").textContent = data.annule ?? 0;
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
                sel.innerHTML = '<option value="">-- Article --</option>' +
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

// ─── RENDU DU TABLEAU ───
function renderSortiesTable(sorties) {
    var tbody = document.getElementById("sortiesTableBody");
    if (!tbody) return;
    if (!sorties.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center">Aucun bon de sortie trouvé</td></tr>';
        document.getElementById("resultsCounter").textContent = "0 bon(s)";
        return;
    }

    var currentRoleId =
        typeof getCurrentUserRole === "function" ? getCurrentUserRole() : -1;
    var canValidate = currentRoleId === 0 || currentRoleId === 3;

    var html = "";
    sorties.forEach(function (s) {
        var lignes = s.Lignes || [];
        var statut = s.STATUT;

        // ─── BADGES DE STATUT MODERNES ───
        var statutBadge = (function () {
            var baseStyle =
                'display:inline-flex;align-items:center;gap:5px;' +
                'padding:5px 12px;border-radius:20px;' +
                'font-size:11.5px;font-weight:600;letter-spacing:0.3px;' +
                'text-transform:uppercase;white-space:nowrap;';

            var badges = {
                VIDE:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#ffb74d,#ff9800);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(255,152,0,0.35);">' +
                        '<i class="fas fa-qrcode" style="font-size:10px;"></i> QR vide' +
                    '</span>',
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
                    '</span>',
                TERMINE:
                    '<span style="' + baseStyle +
                        'background:linear-gradient(135deg,#26c6da,#009688);' +
                        'color:#fff;box-shadow:0 2px 6px rgba(0,150,136,0.35);">' +
                        '<i class="fas fa-check-double" style="font-size:10px;"></i> Reçu' +
                    '</span>'
            };

            return badges[statut] || ('<span style="' + baseStyle +
                'background:#e2e3e5;color:#383d41;">' + statut + '</span>');
        })();

        var articlesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-article-item">' +
                    "<span>" +
                    (ligne.ARTICLE_CODE ? ligne.ARTICLE_CODE + " - " : "") +
                    (ligne.ARTICLE_NOM || ligne.ARTICLE_ID || "") +
                    "</span></div>";
            }).join("")
            : '<span class="text-muted">Aucun article</span>';

        var quantitesHtml = lignes.length
            ? lignes.map(function (ligne) {
                return '<div class="bon-quantity-item">' +
                    formatNumber(ligne.QUANTITE_R, 2) + "</div>";
            }).join("")
            : '<span class="text-muted">-</span>';

        // Cellule "Date réception"
        var dateReceptionHtml = s.DATE_RECEPTION
            ? '<span style="color:#009688;font-weight:600;font-size:12.5px;">' +
                  '<i class="fas fa-calendar-check" style="margin-right:4px;opacity:0.7;"></i>' +
                  formatDateValue(s.DATE_RECEPTION, false) + '</span>'
            : '<span class="text-muted" style="font-size:12px;">—</span>';

        var allQteR = lignes.length > 0 &&
            lignes.every(function (ligne) { return ligne.QUANTITE_R > 0; });

        // ─── ACTIONS (boutons modernes) ───
        var actionsHtml = "";

        // 1. Visualiser (toujours présent)
        actionsHtml +=
            '<button type="button" class="btn-icon btn-info" onclick="viewSortie(\'' +
            s.ID + '\')" title="Voir détails"><i class="fas fa-eye"></i></button>';

        // 2. Actions si statut != VALIDE et != TERMINE
        if (statut !== "VALIDE" && statut !== "TERMINE") {
            actionsHtml +=
                '<button type="button" class="btn-icon btn-primary" onclick="editSortie(\'' +
                s.ID + '\')" title="Modifier"><i class="fas fa-edit"></i></button>';

            actionsHtml +=
                '<button type="button" class="btn-icon btn-danger" onclick="deleteSortie(\'' +
                s.ID + '\')" title="Supprimer"><i class="fas fa-trash"></i></button>';

            if (statut === "BROUILLON" && allQteR && canValidate) {
                actionsHtml +=
                    '<button type="button" class="btn-icon btn-success btn-pulse" ' +
                    'onclick="validerSortie(\'' + s.ID + '\')" ' +
                    'title="Valider la sortie"><i class="fas fa-check"></i></button>';
            }
        }

        html +=
            "<tr>" +
            "<td><strong>" + s.NUMERO + "</strong></td>" +
            "<td>" + formatDateValue(s.DATE_SORTIE, true) + "</td>" +
            "<td>" + dateReceptionHtml + "</td>" +
            '<td class="bon-articles-cell">' + articlesHtml + "</td>" +
            '<td class="bon-quantities-cell">' + quantitesHtml + "</td>" +
            "<td>" + (s.NOM || "") + "</td>" +
            "<td>" + statutBadge + "</td>" +
            "<td>" + actionsHtml + "</td></tr>";
    });

    tbody.innerHTML = html;
    document.getElementById("resultsCounter").textContent = AppState.total + " bon(s)";
}

// ─── EXPOSITIONS ───
window.loadSorties = loadSorties;
window.loadSortieStats = loadSortieStats;
window.loadDropdownsSortie = loadDropdownsSortie;
window.renderSortiesTable = renderSortiesTable;
window.formatDateValue = formatDateValue;
window.formatNumber = formatNumber;
