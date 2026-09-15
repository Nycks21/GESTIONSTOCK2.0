"use strict";

// ────────────────────────────────────────────────────────────
// Formate un montant en chiffres COMPLETS :
//   - pas d'abréviation (K / M / B)
//   - pas de décimale
//   - espace insécable comme séparateur de milliers
// Ex : 5904000 → "5 904 000"
// ────────────────────────────────────────────────────────────
function formatMontantComplet(value) {
  var n = Number(value);
  if (!isFinite(n)) n = 0;
  n = Math.round(n); // entier, pas de décimale
  return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, "\u00A0"); // espace insécable
}

function loadDashboard() {
  showSpinner();
  activateDashboardLink();

  Promise.all([
    loadKpi(),
    loadAlerts(),
    loadStockAlerts(),
    loadMovements(),
    loadStockByCategory(),
    loadRecentMovements(),
    loadRecentDocuments(),
    loadTopArticles(),
  ])
    .catch(function (err) {
      console.error("Dashboard load error:", err);
      showToast("Erreur lors du chargement du tableau de bord", "error");
    })
    .finally(function () {
      hideSpinner();
      DashboardState.lastRefresh = new Date();
    });
}

async function fetchJson(url) {
  var resp = await fetch(url, { credentials: "same-origin" });
  if (!resp.ok) throw new Error("HTTP " + resp.status);
  return resp.json();
}

// ═══ KPI ═══
// ═══ KPI ═══
async function loadKpi() {
  try {
    var data = await fetchJson(DASHBOARD_API.KPI);
    if (!data.success) return;
    DashboardState.kpi = data;

    // ── Articles ──
    var el;

    el = document.getElementById("valArticles");
    if (el) el.textContent = formatNumber(data.articlesActifs);
    el = document.getElementById("pillArticlesTotal");
    if (el) el.textContent = formatNumber(data.articlesTotal) + " total";

    // ── Alertes stock ──
    //   valAlertes = alertes + ruptures (total)
    //   pillRuptures / pillAlertesCount = valeurs calculées par le backend
    el = document.getElementById("valAlertes");
    if (el) el.textContent = formatNumber(data.alertesStock);

    el = document.getElementById("pillRuptures");
    if (el) el.textContent = formatNumber(data.ruptures) + " rupture(s)";

    el = document.getElementById("pillAlertesCount");
    if (el) el.textContent = formatNumber(data.alertes) + " alerte(s)";

    // ── Bons en attente (BROUILLON) — conservé ──
    el = document.getElementById("valBons");
    if (el) el.textContent = formatNumber(data.bonsAttente);

    // ── ✅ FIX : total des MOUVEMENTS enregistrés dans MSTOCK ──
    el = document.getElementById("pillEntree");
    if (el) el.textContent = formatNumber(data.entrees) + " entrée(s)";

    el = document.getElementById("pillSortie");
    if (el) el.textContent = formatNumber(data.sorties) + " sortie(s)";

    // ── Valeur du stock ──
    el = document.getElementById("valValeur");
    if (el) el.textContent = formatMontantComplet(data.valeurStock) + '\u00A0Ar';
    // → affiche "5 904 000" et JAMAIS "5.90", "5,90 M" ou "5.9M"

    // ── Sous seuil (élément optionnel — ne plus planter si absent) ──
    el = document.getElementById("pillSousSeuil");
    if (el)
      el.textContent = formatNumber(data.articlesSousSeuil) + " sous seuil";
  } catch (e) {
    console.error("KPI:", e);
  }
}

// ═══ ALERTES ═══
async function loadAlerts() {
  var card = document.getElementById("alertCard");
  if (!card) return;

  try {
    var data = await fetchJson(DASHBOARD_API.ALERTS);
    var items = data.data || [];
    DashboardState.alerts = items;

    if (!items.length) {
      card.style.display = "none";
      return;
    }
    card.style.display = "block";
    document.getElementById("alertCount").textContent = items.length;

    var html = "";
    for (var i = 0; i < items.length; i++) {
      var a = items[i];
      html +=
        "<tr>" +
        "<td><strong>" +
        escapeHtml(a.code) +
        "</strong></td>" +
        "<td>" +
        escapeHtml(a.nom) +
        "</td>" +
        "<td>" +
        escapeHtml(a.categorie || "—") +
        "</td>" +
        "<td>" +
        escapeHtml(a.emplacement || "—") +
        "</td>" +
        "<td><strong>" +
        formatNumber(a.quantite) +
        "</strong> " +
        escapeHtml(a.unite) +
        "</td>" +
        "<td>" +
        formatNumber(a.seuilAlerte) +
        "</td>" +
        "<td>" +
        statutBadge(a.statut) +
        "</td>" +
        "</tr>";
    }
    document.getElementById("tbodyAlerts").innerHTML = html;
  } catch (e) {
    console.error("Alerts:", e);
  }
}

// ═══ STOCK EN ALERTE ═══
async function loadStockAlerts() {
  var card = document.getElementById("stockAlertCard");
  if (!card) return;

  try {
    var data = await fetchJson(DASHBOARD_API.STOCK_ALERTS);
    var items = data && data.data ? data.data : [];

    // ✅ Règle métier identique à la page STOCK :
    //    Un article est "en alerte" si seuil > 0 ET 0 < disponible <= seuil
    var alerts = items.filter(function (a) {
      var dispo = Number(a.DISPONIBLE || 0);
      var seuil = Number(a.SEUIL_ALERTE || 0);
      return seuil > 0 && dispo > 0 && dispo <= seuil;
    });

    if (!alerts.length) {
      // Aucun article en alerte → masquer la carte
      card.style.display = "none";
      document.getElementById("stockAlertCount").textContent = "0";
      document.getElementById("tbodyStockAlerts").innerHTML = "";
      return;
    }

    // Afficher + remplir
    card.style.display = "block";
    document.getElementById("stockAlertCount").textContent = alerts.length;

    var html = "";
    for (var i = 0; i < alerts.length; i++) {
      var a = alerts[i];
      html +=
        "<tr>" +
        "<td><strong>" +
        escapeHtml(a.ARTICLE_CODE) +
        "</strong></td>" +
        "<td>" +
        escapeHtml(a.ARTICLE_NOM) +
        "</td>" +
        "<td>" +
        escapeHtml(a.CATEGORIE_NOM || "—") +
        "</td>" +
        "<td>" +
        escapeHtml(a.EMPLACEMENT_NOM || "—") +
        "</td>" +
        "<td><strong>" +
        formatNumber(a.DISPONIBLE, 0) +
        "</strong>" +
        (a.UNITE_NOM ? " <small>" + escapeHtml(a.UNITE_NOM) + "</small>" : "") +
        "</td>" +
        "<td>" +
        formatNumber(a.SEUIL_ALERTE, 0) +
        "</td>" +
        "<td>" +
        statutBadge("ALERTE") +
        "</td>" +
        "</tr>";
    }
    document.getElementById("tbodyStockAlerts").innerHTML = html;
  } catch (e) {
    console.error("Stock alerts:", e);
    // En cas d'erreur, on masque la carte pour ne pas afficher un bloc vide
    card.style.display = "none";
  }
}

// ═══ MOUVEMENTS ═══
async function loadMovements() {
  try {
    var data = await fetchJson(DASHBOARD_API.MOVEMENTS);
    if (!data.success) return;
    DashboardState.movements = data;
    initMovementsChart(data.labels, data.entrees, data.sorties);
  } catch (e) {
    console.error("Movements:", e);
  }
}

// ═══ CATÉGORIES ═══
async function loadStockByCategory() {
  try {
    var data = await fetchJson(DASHBOARD_API.STOCK_CATEGORY);
    if (!data.success || !data.labels) return;
    DashboardState.categories = data;
    initCategoriesChart(data.labels, data.quantites);
  } catch (e) {
    console.error("Categories:", e);
  }
}

// ═══ ACTIVITÉ RÉCENTE (mouvements) ═══
async function loadRecentMovements() {
  var feed = document.getElementById("activityFeed");
  if (!feed) return;

  try {
    var data = await fetchJson(DASHBOARD_API.RECENT_MVT);
    var items = data.data || [];
    DashboardState.recentMovements = items;

    if (!items.length) {
      feed.innerHTML = '<div class="loading-mini">Aucun mouvement récent</div>';
      return;
    }

    var html = "";
    for (var i = 0; i < items.length; i++) {
      var m = items[i];
      var isEntree = m.type === "ENTREE";
      html +=
        '<div class="activity-item">' +
        '<div class="activity-icon ' +
        (isEntree ? "entry" : "exit") +
        '">' +
        '<i class="fas fa-arrow-' +
        (isEntree ? "down" : "up") +
        '"></i>' +
        "</div>" +
        '<div class="activity-content">' +
        '<div class="activity-text">' +
        "<strong>" +
        (isEntree ? "+" : "-") +
        formatNumber(m.quantite) +
        " " +
        escapeHtml(m.unite) +
        "</strong>" +
        " — " +
        escapeHtml(m.code) +
        " " +
        escapeHtml(m.nom) +
        "</div>" +
        '<div class="activity-time">' +
        timeAgo(m.date) +
        (m.utilisateur ? " · " + escapeHtml(m.utilisateur) : "") +
        "</div>" +
        "</div>" +
        "</div>";
    }
    feed.innerHTML = html;
  } catch (e) {
    console.error("Recent movements:", e);
    feed.innerHTML = '<div class="loading-mini">Erreur de chargement</div>';
  }
}

// ═══ DOCUMENTS RÉCENTS ═══
async function loadRecentDocuments() {
  var feed = document.getElementById("documentsFeed");
  if (!feed) return;

  try {
    var data = await fetchJson(DASHBOARD_API.RECENT_DOCS);
    var items = data.data || [];
    DashboardState.recentDocuments = items;

    if (!items.length) {
      feed.innerHTML = '<div class="loading-mini">Aucun document récent</div>';
      return;
    }

    var html = "";
    for (var i = 0; i < items.length; i++) {
      var d = items[i];
      var isEntree = d.type === "ENTREE";
      html +=
        '<div class="activity-item">' +
        '<div class="activity-icon doc">' +
        '<i class="fas fa-file-' +
        (isEntree ? "import" : "export") +
        '"></i>' +
        "</div>" +
        '<div class="activity-content">' +
        '<div class="activity-text">' +
        "<strong>" +
        escapeHtml(d.numero) +
        "</strong> " +
        statutBadge(d.statut) +
        "</div>" +
        '<div class="activity-time">' +
        (isEntree ? "Entrée" : "Sortie") +
        " · " +
        formatDateFr(d.date) +
        "</div>" +
        "</div>" +
        "</div>";
    }
    feed.innerHTML = html;
  } catch (e) {
    console.error("Recent documents:", e);
    feed.innerHTML = '<div class="loading-mini">Erreur de chargement</div>';
  }
}

// ═══ TOP ARTICLES ═══
async function loadTopArticles() {
  var container = document.getElementById("topArticlesList");
  if (!container) return;

  try {
    var data = await fetchJson(DASHBOARD_API.TOP_ARTICLES);
    var items = data.data || [];
    DashboardState.topArticles = items;

    if (!items.length) {
      container.innerHTML =
        '<div class="loading-mini">Aucune donnée sur 30 jours</div>';
      return;
    }

    var html = "";
    for (var i = 0; i < items.length; i++) {
      var a = items[i];
      var rankClass = i < 3 ? " rank-" + (i + 1) : "";
      html +=
        '<div class="top-article">' +
        '<div class="top-rank' +
        rankClass +
        '">' +
        (i + 1) +
        "</div>" +
        '<div class="top-info">' +
        '<div class="top-name">' +
        escapeHtml(a.nom) +
        "</div>" +
        '<div class="top-code">' +
        escapeHtml(a.code) +
        "</div>" +
        "</div>" +
        '<div class="top-volume">' +
        formatNumber(a.volume) +
        " " +
        escapeHtml(a.unite) +
        "</div>" +
        "</div>";
    }
    container.innerHTML = html;
  } catch (e) {
    console.error("Top articles:", e);
    container.innerHTML =
      '<div class="loading-mini">Erreur de chargement</div>';
  }
}

window.loadDashboard = loadDashboard;
