﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="index.cs" Inherits="index" UICulture="Auto" Culture="Auto" %>
  <!DOCTYPE html>
  <html lang="fr">

  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>
      <%= LocalizationHelper.GetString("Dashboard") %> — Gestion de Stock
    </title>

    <link rel="stylesheet" href="../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../_assets/css/global.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="css/dashboard.css?v=<%=AuthHelper.Version %>">
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="form1" runat="server">
      <asp:HiddenField ID="hfUserRole" runat="server" />
      <div class="wrapper">

        <%= AuthHelper.RenderTopBarHTML() %>

          <aside class="main-sidebar" id="sidebar">
            <a href="#" class="brand-link" onclick="loadDashboard();return false;">
              <img src="../../img/logo4.png" alt="Logo" class="brand-image">
              <span class="brand-text">Gestion de Stock</span>
            </a>

            <style>
              .brand-image {
                width: 33px;
                height: 33px;
                object-fit: contain;
              }
            </style>
            <div class="sidebar">
              <%= AuthHelper.RenderMenuHTML() %>
            </div>
          </aside>

          <%= AuthHelper.RenderControlSidebarHTML() %>

            <div class="content-wrapper" id="contentWrapper">
              <div class="content-header">
                <div class="container-fluid">
                  <div class="row">
                    <div class="col-lg-6">
                      <h1><i class="fas fa-chalkboard"></i> Tableau de bord</h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float:right;">
                        <li class="breadcrumb-item">Accueil</li>
                        <li class="breadcrumb-item active">Tableau de bord</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content">
                <div class="container-fluid">

                  <!-- ═══ ZONE 1 : KPI ═══ -->
                  <div class="kpi-row">
                    <div class="kpi-card" onclick="location.href='../modules/articles/articles.aspx'">
                      <div class="kpi-accent" style="background:#007bff"></div>
                      <div class="kpi-label"><i class="fas fa-boxes"></i> Articles actifs</div>
                      <div class="kpi-val" id="valArticles">—</div>
                      <div class="kpi-sub"><span class="pill pill-neu" id="pillArticlesTotal">— total</span></div>
                    </div>

                    <div class="kpi-card" onclick="location.href='../modules/stock/stock.aspx'">
                      <div class="kpi-accent" style="background:#dc3545"></div>
                      <div class="kpi-label"><i class="fas fa-exclamation-triangle"></i> Alertes stock</div>
                      <div class="kpi-val text-danger" id="valAlertes">—</div>
                      <div class="kpi-sub">
                        <span class="pill pill-dn" id="pillRuptures">0 rupture(s)</span>
                        <span class="pill pill-neu" id="pillAlertesCount">0 alerte(s)</span>
                      </div>
                    </div>

                    <div class="kpi-card" onclick="location.href='../modules/entrees/entrees.aspx'">
                      <div class="kpi-accent" style="background:#ffc107"></div>
                      <div class="kpi-label"><i class="fas fa-hourglass-half"></i> Bons en attente</div>
                      <div class="kpi-val" id="valBons">—</div>
                      <div class="kpi-sub">
                        <span class="pill pill-neu" id="pillEntree">0 entrée(s)</span>
                        <span class="pill pill-neu" id="pillSortie">0 sortie(s)</span>
                      </div>
                    </div>

                    <div class="kpi-card" onclick="location.href='../modules/stock/stock.aspx'">
                      <div class="kpi-accent" style="background:#28a745"></div>
                      <div class="kpi-label"><i class="fas fa-coins"></i> Valeur du stock</div>
                      <div class="kpi-val" id="valValeur">—</div>
                      <div class="kpi-sub">
                        <span class="pill pill-up" id="pillSousSeuil">0 article(s) sous seuil</span>
                      </div>
                    </div>
                  </div>

                  <!-- ═══ ZONE 2 : ALERTES ═══ -->
                  <% if (AuthHelper.HasPermission("stock") || AuthHelper.HasPermission("articles")) { %>
                    <div class="dash-card dash-card-alert" id="alertCard" style="display:none;">
                      <div class="dash-card-head">
                        <span class="dash-card-title">
                          <i class="fas fa-exclamation-triangle" style="color:#dc3545;"></i>
                          Alertes prioritaires
                          <span class="badge-count" id="alertCount">0</span>
                        </span>
                        <button class="btn btn-sm btn-danger" onclick="location.href='../modules/stock/stock.aspx'">
                          <i class="fas fa-arrow-right"></i> Voir tout
                        </button>
                      </div>
                      <div style="overflow-x:auto; max-height:320px;">
                        <table class="dash-table">
                          <thead>
                            <tr>
                              <th>Code</th>
                              <th>Article</th>
                              <th>Catégorie</th>
                              <th>Emplacement</th>
                              <th>Qté</th>
                              <th>Seuil</th>
                              <th>Statut</th>
                            </tr>
                          </thead>
                          <tbody id="tbodyAlerts"></tbody>
                        </table>
                      </div>
                    </div>
                    <% } %>

                      <!-- ═══ ZONE 3 : GRAPHIQUES ═══ -->
                      <div class="row mt-3">
                        <% if (AuthHelper.HasPermission("stock")) { %>
                          <div class="col-lg-8">
                            <div class="dash-card">
                              <div class="dash-card-head">
                                <span class="dash-card-title">
                                  <span class="dot-blue"></span> Mouvements — 30 derniers jours
                                </span>
                              </div>
                              <div class="dash-card-body">
                                <div style="position:relative;height:280px;">
                                  <canvas id="chartMovements"></canvas>
                                </div>
                              </div>
                            </div>
                          </div>
                          <div class="col-lg-4">
                            <div class="dash-card">
                              <div class="dash-card-head">
                                <span class="dash-card-title">
                                  <span class="dot-blue"></span> Stock par catégorie
                                </span>
                              </div>
                              <div class="dash-card-body">
                                <div style="position:relative;height:200px;">
                                  <canvas id="chartCategories"></canvas>
                                </div>
                                <div class="donut-legend" id="donutLegend" style="margin-top:12px;"></div>
                              </div>
                            </div>
                          </div>
                          <% } %>
                      </div>

                      <!-- ═══ ZONE 4 : ACTIVITÉ ═══ -->
                      <div class="row mt-3">
                        <% if (AuthHelper.HasPermission("stock")) { %>
                          <div class="col-lg-6">
                            <div class="dash-card">
                              <div class="dash-card-head">
                                <span class="dash-card-title">
                                  <span class="dot-green"></span> Derniers mouvements
                                </span>
                              </div>
                              <div style="max-height:350px; overflow-y:auto;">
                                <div class="activity-feed" id="activityFeed">
                                  <div class="loading-mini">Chargement…</div>
                                </div>
                              </div>
                            </div>
                          </div>
                          <% } %>

                            <% if (AuthHelper.HasPermission("entrees") || AuthHelper.HasPermission("sorties")) { %>
                              <div class="col-lg-6">
                                <div class="dash-card">
                                  <div class="dash-card-head">
                                    <span class="dash-card-title">
                                      <span class="dot-blue"></span> Derniers documents
                                    </span>
                                  </div>
                                  <div style="max-height:350px; overflow-y:auto;">
                                    <div class="activity-feed" id="documentsFeed">
                                      <div class="loading-mini">Chargement…</div>
                                    </div>
                                  </div>
                                </div>
                              </div>
                              <% } %>
                      </div>

                      <!-- ═══ ZONE 5 : TOP ARTICLES + RACCOURCIS ═══ -->
                      <div class="row mt-3">
                        <% if (AuthHelper.HasPermission("stock") || AuthHelper.HasPermission("articles")) { %>
                          <div class="col-lg-6">
                            <div class="dash-card">
                              <div class="dash-card-head">
                                <span class="dash-card-title">
                                  <span class="dot-gold"></span> Top 5 articles (30j)
                                </span>
                              </div>
                              <div class="dash-card-body">
                                <div id="topArticlesList"></div>
                              </div>
                            </div>
                          </div>
                          <% } %>

                            <div class="col-lg-6">
                              <div class="dash-card">
                                <div class="dash-card-head">
                                  <span class="dash-card-title">
                                    <span class="dot-gold"></span> Accès rapides
                                  </span>
                                </div>
                                <div class="dash-card-body">
                                  <div class="quick-actions">
                                    <% if (AuthHelper.HasPermission("entrees")) { %>
                                      <a href="../modules/entrees/entrees.aspx" class="quick-action">
                                        <i class="fas fa-arrow-down"></i> Entrées
                                      </a>
                                      <% } %>
                                        <% if (AuthHelper.HasPermission("sorties")) { %>
                                          <a href="../modules/sorties/sorties.aspx" class="quick-action">
                                            <i class="fas fa-arrow-up"></i> Sorties
                                          </a>
                                          <% } %>
                                            <% if (AuthHelper.HasPermission("articles")) { %>
                                              <a href="../modules/articles/articles.aspx" class="quick-action">
                                                <i class="fas fa-boxes"></i> Articles
                                              </a>
                                              <% } %>
                                                <% if (AuthHelper.HasPermission("stock")) { %>
                                                  <a href="../modules/stock/stock.aspx" class="quick-action">
                                                    <i class="fas fa-warehouse"></i> Stock
                                                  </a>
                                                  <% } %>
                                                    <% if (AuthHelper.HasPermission("inventaire")) { %>
                                                      <a href="../modules/inventaire/inventaire.aspx"
                                                        class="quick-action">
                                                        <i class="fas fa-clipboard-list"></i> Inventaire
                                                      </a>
                                                      <% } %>
                                                        <% if (AuthHelper.HasPermission("fournisseurs")) { %>
                                                          <a href="../parametres/fournisseurs/fournisseurs.aspx"
                                                            class="quick-action">
                                                            <i class="fas fa-truck"></i> Fournisseurs
                                                          </a>
                                                          <% } %>
                                  </div>
                                </div>
                              </div>
                            </div>
                      </div>

                </div>
              </section>
            </div>
      </div>

      <div id="spinnerOverlay"
        style="display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.35);z-index:9998;align-items:center;justify-content:center;">
        <div class="spinner"></div>
      </div>

      <script src="../_assets/js/chart.umd.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../_assets/js/sweetalert2.all.min.js?v=<%=AuthHelper.Version %>"></script>
      <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
      <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/charts.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
    </form>
  </body>

  </html>
