// ============================================================
// CHARGEMENT DES DONNÉES – ACCUSE
// ============================================================

function formatNumber(value, decimals) {
    if (value === undefined || value === null || isNaN(value)) return '0';
    return Number(value).toFixed(decimals || 0);
}

async function loadAccuse(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();

    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search || "",
            destination: AppState.filters.destination || "",
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
            renderAccuseTable(AppState.sorties);
            createPaginationControls(AppState.totalPages);
            loadAccuseStats();
        } else {
            showToast(
                "Erreur",
                data.message || "Impossible de charger les accusés",
                "error",
            );
        }
    } catch (e) {
        showToast("Erreur", e.message, "error");
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadAccuseStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            document.getElementById("statTotal").textContent = data.total ?? 0;
            document.getElementById("statValide").textContent = data.valide ?? 0;
            document.getElementById("statAnnule").textContent = data.annule ?? 0;
        }
    } catch (e) {
        console.warn("Erreur stats:", e);
    }
}

// Les lignes du modal de visualisation utilisent les articles déjà chargés
async function loadArticlesForAccuse() {
    try {
        var url = API.BASE + 'pages/modules/articles/handlers/' + API.ARTICLES + '?page=1&pageSize=999999';
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.articles = data.Articles || [];
        }
    } catch (e) { /* ignore */ }
}

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

function renderAccuseTable(sorties) {
    var tbody = document.getElementById("accuseTableBody");
    if (!tbody) return;
    if (!sorties.length) {
        tbody.innerHTML =
            '<tr><td colspan="7" class="text-center">Aucun bon validé trouvé</td></tr>';
        document.getElementById("resultsCounter").textContent = "0 bon(s)";
        return;
    }
    var html = "";
    sorties.forEach(function (s) {
        var lignes = s.Lignes || [];
        var statut = s.STATUT;
        var statutBadge =
            {
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

        // Action : uniquement Visualiser
        var actionsHtml = '';
        actionsHtml += '<button type="button" class="btn btn-sm btn-info" onclick="viewAccuse(\'' + s.ID + '\')" title="Voir détails"><i class="fas fa-eye"></i></button> ';

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
            (s.DESTINATION || "") +
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

window.loadAccuse = loadAccuse;
window.loadAccuseStats = loadAccuseStats;
window.loadArticlesForAccuse = loadArticlesForAccuse;
window.renderAccuseTable = renderAccuseTable;
window.formatDateValue = formatDateValue;
window.formatNumber = formatNumber;
