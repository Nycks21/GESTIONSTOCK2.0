// ============================================================
// CHARGEMENT DES DONNÉES – SORTIES
// ============================================================

function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return '0';
    return Number(value).toFixed(decimals || 0);
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
            showToast(
                "Erreur",
                data.message || "Impossible de charger les bons",
                "error",
            );
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
            document.getElementById("statBrouillon").textContent =
                data.brouillon ?? 0;
            document.getElementById("statAnnule").textContent = data.annule ?? 0;
            // ✅ Mise à jour du badge après chargement des stats
            if (typeof updateSortieBadge === 'function') {
                updateSortieBadge(data.pending);
            }
        }
    } catch (e) {
        console.warn("Erreur stats:", e);
    }
}

async function loadDropdownsSortie() {
    // Récupération des articles pour les lignes
    try {
        var url =
            API.BASE + API.HANDLERS_PATH + API.ARTICLES + "?page=1&pageSize=999999";
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
            // Mettre à jour les selects déjà présents
            document.querySelectorAll(".ligne-article").forEach(function (sel) {
                var currentVal = sel.value;
                sel.innerHTML =
                    '<option value="">-- Article --</option>' +
                    AppState.articles
                        .map(function (a) {
                            return (
                                '<option value="' +
                                a.ID +
                                '">' +
                                a.CODE +
                                " - " +
                                a.NOM +
                                "</option>"
                            );
                        })
                        .join("");
                sel.value = currentVal;
                if (typeof refreshArticleSelect === 'function') {
                    refreshArticleSelect(sel);
                }
            });
        }
    } catch (e) {
        /* ignore */
    }
}

// ============================================================
// FONCTIONS D'AFFICHAGE
// ============================================================

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
        ? {
              day: "2-digit",
              month: "2-digit",
              year: "numeric",
              hour: "2-digit",
              minute: "2-digit",
          }
        : {
              day: "2-digit",
              month: "2-digit",
              year: "numeric",
          };
    return date.toLocaleString("fr-FR", options);
}

function renderSortiesTable(sorties) {
    var tbody = document.getElementById("sortiesTableBody");
    if (!tbody) return;
    if (!sorties.length) {
        tbody.innerHTML =
            '<tr><td colspan="8" class="text-center">Aucun bon de sortie trouvé</td></tr>';
        document.getElementById("resultsCounter").textContent = "0 bon(s)";
        return;
    }
    var html = "";
    sorties.forEach(function (s) {
        var lignes = s.Lignes || [];
        var statut = s.STATUT;
        var statutBadge =
            {
                VIDE: '<span class="badge bg-warning" style="background:#F5DF4D;padding:4px 10px;border-radius:20px;color:#1E0F1C;">QR vide</span>',
                BROUILLON:
                    '<span class="badge bg-warning" style="background:#B6D8F2;padding:4px 10px;border-radius:20px;color:#1E0F1C;">En cours</span>',
                VALIDE:
                    '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:#fff;">Validé</span>',
                ANNULE:
                    '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:#fff;">Annulé</span>',
            }[statut] || statut;
        var articlesHtml = lignes.length
            ? lignes
                  .map(function (ligne) {
                      return (
                          '<div class="bon-article-item">' +
                          "<span>" +
                          (ligne.ARTICLE_CODE ? ligne.ARTICLE_CODE + " - " : "") +
                          (ligne.ARTICLE_NOM || ligne.ARTICLE_ID || "") +
                          "</span>" +
                          "</div>"
                      );
                  })
                  .join("")
            : '<span class="text-muted">Aucun article</span>';
        var quantitesHtml = lignes.length
            ? lignes
                  .map(function (ligne) {
                      return (
                          '<div class="bon-quantity-item">' +
                          formatNumber(ligne.QUANTITE_R, 2) +
                          "</div>"
                      );
                  })
                  .join("")
            : '<span class="text-muted">-</span>';

        // La validation est disponible uniquement si toutes les lignes sont renseignées.
        var allQteR = lignes.length > 0 && lignes.every(function (ligne) {
            return ligne.QUANTITE_R > 0;
        });

        // --- Construction des actions ---
        var actionsHtml = '';

        // 1. Bouton Visualiser (toujours présent)
        actionsHtml += '<button type="button" class="btn btn-sm btn-info" onclick="viewSortie(\'' + s.ID + '\')" title="Voir détails"><i class="fas fa-eye"></i></button> ';

        // 2. Si le statut n'est pas VALIDE, on affiche les autres actions
        if (statut !== 'VALIDE') {
            actionsHtml += '<button type="button" class="btn btn-sm btn-primary" onclick="editSortie(\'' + s.ID + '\')"><i class="fas fa-edit"></i></button> ';
            actionsHtml += '<button type="button" class="btn btn-sm btn-danger" onclick="deleteSortie(\'' + s.ID + '\')"><i class="fas fa-trash"></i></button> ';
            if (statut === 'BROUILLON' && allQteR) {
                actionsHtml += '<button type="button" class="btn btn-sm btn-success" onclick="validerSortie(\'' + s.ID + '\')"><i class="fas fa-check"></i></button> ';
            }
        }

        html +=
            "<tr>" +
            "<td><strong>" +
            s.NUMERO +
            "</strong></td>" +
            "<td>" +
            formatDateValue(s.DATE_SORTIE, true) +
            "</td>" +
            '<td class="bon-articles-cell">' +
            articlesHtml +
            "</td>" +
            '<td class="bon-quantities-cell">' +
            quantitesHtml +
            "</td>" +
            "<td>" +
            (s.NOM || "") +
            "</td>" +
            "<td>" +
            statutBadge +
            "</td>" +
            "<td>" +
            actionsHtml +
            "</td></tr>";
    });
    tbody.innerHTML = html;
    document.getElementById("resultsCounter").textContent =
        AppState.total + " bon(s)";
}

// Expositions globales
window.loadSorties = loadSorties;
window.loadSortieStats = loadSortieStats;
window.loadDropdownsSortie = loadDropdownsSortie;
window.renderSortiesTable = renderSortiesTable;
window.formatDateValue = formatDateValue;
window.formatNumber = formatNumber;
