"use strict";

// ────────────────────────────────────────────────────────────
// Formate un montant en chiffres COMPLETS (entier, espaces)
// ────────────────────────────────────────────────────────────
function formatMontantComplet(value) {
  var n = Number(value);
  if (!isFinite(n)) n = 0;
  n = Math.round(n);
  return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, "\u00A0");
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
      showToast(t('msg.dashboard_error'), "error");
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
async function loadKpi() {
  try {
    var data = await fetchJson(DASHBOARD_API.KPI);
    if (!data.success) return;
    DashboardState.kpi = data;

    var el;

    // ── Articles ──
    el = document.getElementById("valArticles");
    if (el) el.textContent = formatNumber(data.articlesActifs);

    el = document.getElementById("pillArticlesTotal");
    if (el) el.textContent = t('pill.total', { n: formatNumber(data.articlesTotal) });

    // ── Alertes stock ──
    el = document.getElementById("valAlertes");
    if (el) el.textContent = formatNumber(data.alertesStock);

    el = document.getElementById("pillRuptures");
    if (el) el.textContent = t('pill.ruptures', { n: formatNumber(data.ruptures) });

    el = document.getElementById("pillAlertesCount");
    if (el) el.textContent = t('pill.alertes', { n: formatNumber(data.alertes) });

    // ── Bons en attente ──
    el = document.getElementById("valBons");
    if (el) el.textContent = formatNumber(data.bonsAttente);

    el = document.getElementById("pillEntree");
    if (el) el.textContent = t('pill.entrees', { n: formatNumber(data.entrees) });

    el = document.getElementById("pillSortie");
    if (el) el.textContent = t('pill.sorties', { n: formatNumber(data.sorties) });

    // ── Valeur du stock ──
    el = document.getElementById("valValeur");
    if (el) el.textContent = formatMontantComplet(data.valeurStock) + '\u00A0Ar';

    // ── Sous seuil (optionnel) ──
    el = document.getElementById("pillSousSeuil");
    if (el)
      el.textContent = t('pill.sous_seuil', { n: formatNumber(data.articlesSousSeuil) });
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
        "<td><strong>" + escapeHtml(a.code) + "</strong></td>" +
        "<td>" + escapeHtml(a.nom) + "</td>" +
        "<td>" + escapeHtml(a.categorie || "—") + "</td>" +
        "<td>" + escapeHtml(a.emplacement || "—") + "</td>" +
        "<td><strong>" + formatNumber(a.quantite) + "</strong> " + escapeHtml(a.unite) + "</td>" +
        "<td>" + formatNumber(a.seuilAlerte) + "</td>" +
        "<td>" + statutBadge(a.statut) + "</td>" +
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

    var alerts = items.filter(function (a) {
      var dispo = Number(a.DISPONIBLE || 0);
      var seuil = Number(a.SEUIL_ALERTE || 0);
      return seuil > 0 && dispo > 0 && dispo <= seuil;
    });

    if (!alerts.length) {
      card.style.display = "none";
      document.getElementById("stockAlertCount").textContent = "0";
      document.getElementById("tbodyStockAlerts").innerHTML = "";
      return;
    }

    card.style.display = "block";
    document.getElementById("stockAlertCount").textContent = alerts.length;

    var html = "";
    for (var i = 0; i < alerts.length; i++) {
      var a = alerts[i];
      html +=
        "<tr>" +
        "<td><strong>" + escapeHtml(a.ARTICLE_CODE) + "</strong></td>" +
        "<td>" + escapeHtml(a.ARTICLE_NOM) + "</td>" +
        "<td>" + escapeHtml(a.CATEGORIE_NOM || "—") + "</td>" +
        "<td>" + escapeHtml(a.EMPLACEMENT_NOM || "—") + "</td>" +
        "<td><strong>" + formatNumber(a.DISPONIBLE, 0) + "</strong>" +
          (a.UNITE_NOM ? " <small>" + escapeHtml(a.UNITE_NOM) + "</small>" : "") + "</td>" +
        "<td>" + formatNumber(a.SEUIL_ALERTE, 0) + "</td>" +
        "<td>" + statutBadge("ALERTE") + "</td>" +
        "</tr>";
    }
    document.getElementById("tbodyStockAlerts").innerHTML = html;
  } catch (e) {
    console.error("Stock alerts:", e);
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

// ═══ ACTIVITÉ RÉCENTE ═══
async function loadRecentMovements() {
  var feed = document.getElementById("activityFeed");
  if (!feed) return;

  try {
    var data = await fetchJson(DASHBOARD_API.RECENT_MVT);
    var items = data.data || [];
    DashboardState.recentMovements = items;

    if (!items.length) {
      feed.innerHTML = '<div class="loading-mini">' + t('msg.no_recent_mvt') + '</div>';
      return;
    }

    var html = "";
    for (var i = 0; i < items.length; i++) {
      var m = items[i];
      var isEntree = m.type === "ENTREE";
      html +=
        '<div class="activity-item">' +
        '<div class="activity-icon ' + (isEntree ? "entry" : "exit") + '">' +
        '<i class="fas fa-arrow-' + (isEntree ? "down" : "up") + '"></i>' +
        "</div>" +
        '<div class="activity-content">' +
        '<div class="activity-text">' +
        "<strong>" + (isEntree ? "+" : "-") + formatNumber(m.quantite) + " " + escapeHtml(m.unite) + "</strong>" +
        " — " + escapeHtml(m.code) + " " + escapeHtml(m.nom) +
        "</div>" +
        '<div class="activity-time">' +
        timeAgo(m.date) + (m.utilisateur ? " · " + escapeHtml(m.utilisateur) : "") +
        "</div>" +
        "</div>" +
        "</div>";
    }
    feed.innerHTML = html;
  } catch (e) {
    console.error("Recent movements:", e);
    feed.innerHTML = '<div class="loading-mini">' + t('msg.load_error') + '</div>';
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
      feed.innerHTML = '<div class="loading-mini">' + t('msg.no_recent_docs') + '</div>';
      return;
    }

    var html = "";
    for (var i = 0; i < items.length; i++) {
      var d = items[i];
      var isEntree = d.type === "ENTREE";
      html +=
        '<div class="activity-item">' +
        '<div class="activity-icon doc">' +
        '<i class="fas fa-file-' + (isEntree ? "import" : "export") + '"></i>' +
        "</div>" +
        '<div class="activity-content">' +
        '<div class="activity-text">' +
        "<strong>" + escapeHtml(d.numero) + "</strong> " + statutBadge(d.statut) +
        "</div>" +
        '<div class="activity-time">' +
        (isEntree ? t('doc.entry') : t('doc.exit')) + " · " + formatDateFr(d.date) +
        "</div>" +
        "</div>" +
        "</div>";
    }
    feed.innerHTML = html;
  } catch (e) {
    console.error("Recent documents:", e);
    feed.innerHTML = '<div class="loading-mini">' + t('msg.load_error') + '</div>';
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
      container.innerHTML = '<div class="loading-mini">' + t('msg.no_data_30j') + '</div>';
      return;
    }

    var html = "";
    for (var i = 0; i < items.length; i++) {
      var a = items[i];
      var rankClass = i < 3 ? " rank-" + (i + 1) : "";
      html +=
        '<div class="top-article">' +
        '<div class="top-rank' + rankClass + '">' + (i + 1) + "</div>" +
        '<div class="top-info">' +
        '<div class="top-name">' + escapeHtml(a.nom) + "</div>" +
        '<div class="top-code">' + escapeHtml(a.code) + "</div>" +
        "</div>" +
        '<div class="top-volume">' + formatNumber(a.volume) + " " + escapeHtml(a.unite) + "</div>" +
        "</div>";
    }
    container.innerHTML = html;
  } catch (e) {
    console.error("Top articles:", e);
    container.innerHTML = '<div class="loading-mini">' + t('msg.load_error') + '</div>';
  }
}

window.loadDashboard = loadDashboard;
