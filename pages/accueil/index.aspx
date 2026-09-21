﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="index.cs" Inherits="index" UICulture="Auto" Culture="Auto" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>
      <%= LocalizationHelper.GetString("dashboard.title") %> — Gestion de Stock
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
                      <h1>
                        <i class="fas fa-chalkboard"></i>
                        <span data-i18n="dashboard.title"></span>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float:right;">
                        <li class="breadcrumb-item" data-i18n="menu.accueil"></li>
                        <li class="breadcrumb-item active" data-i18n="dashboard.title"></li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content">
                <div class="container-fluid">

                  <!-- ═══ ZONE 1 : KPI ═══ -->
                  <div class="kpi-row">

                    <% if (AuthHelper.HasPermission("articles")) { %>
                      <div class="kpi-card" onclick="location.href='../modules/articles/articles.aspx'">
                        <div class="kpi-accent" style="background:#007bff"></div>
                        <div class="kpi-label">
                          <i class="fas fa-boxes"></i>
                          <span data-i18n="dashboard.articles_actifs"></span>
                        </div>
                        <div class="kpi-val" id="valArticles">—</div>
                        <div class="kpi-sub">
                          <span class="pill pill-neu" id="pillArticlesTotal">—</span>
                        </div>
                      </div>
                      <% } %>

                        <% if (AuthHelper.HasPermission("stock")) { %>
                          <div class="kpi-card" onclick="location.href='../modules/stock/stock.aspx'">
                            <div class="kpi-accent" style="background:#dc3545"></div>
                            <div class="kpi-label">
                              <i class="fas fa-exclamation-triangle"></i>
                              <span data-i18n="dashboard.alertes_stock"></span>
                            </div>
                            <div class="kpi-val text-danger" id="valAlertes">—</div>
                            <div class="kpi-sub">
                              <span class="pill pill-dn" id="pillRuptures">—</span>
                              <span class="pill pill-neu" id="pillAlertesCount">—</span>
                            </div>
                          </div>
                          <% } %>

                            <% if (AuthHelper.HasPermission("entrees") || AuthHelper.HasPermission("sorties")) { %>
                              <div class="kpi-card" onclick="location.href='../modules/entrees/entrees.aspx'">
                                <div class="kpi-accent" style="background:#ffc107"></div>
                                <div class="kpi-label">
                                  <i class="fas fa-hourglass-half"></i>
                                  <span data-i18n="dashboard.bons_attente"></span>
                                </div>
                                <div class="kpi-val" id="valBons">—</div>
                                <div class="kpi-sub">
                                  <span class="pill pill-neu" id="pillEntree">—</span>
                                  <span class="pill pill-neu" id="pillSortie">—</span>
                                </div>
                              </div>
                              <% } %>

                                <% if (AuthHelper.HasPermission("stock")) { %>
                                  <div class="kpi-card" onclick="location.href='../modules/stock/stock.aspx'">
                                    <div class="kpi-accent" style="background:#28a745"></div>
                                    <div class="kpi-label">
                                      <i class="fas fa-coins"></i>
                                      <span data-i18n="dashboard.valeur_stock"></span>
                                    </div>
                                    <div class="kpi-val" id="valValeur">—</div>
                                  </div>
                                  <% } %>

                  </div>

                  <!-- ═══ ACCÈS RAPIDES ═══ -->
                  <div class="row">
                    <div class="col-lg-12">
                      <div class="dash-card">
                        <div class="dash-card-head">
                          <span class="dash-card-title">
                            <span class="dot-gold"></span>
                            <span data-i18n="dashboard.quick_access"></span>
                          </span>
                        </div>
                        <div class="dash-card-body">
                          <div class="quick-actions">

                            <% if (AuthHelper.HasPermission("entrees")) { %>
                              <a href="../modules/entrees/entrees.aspx" class="quick-action">
                                <i class="fas fa-arrow-down"></i>
                                <span data-i18n="menu.entrees"></span>
                              </a>
                              <% } %>

                                <% if (AuthHelper.HasPermission("sorties")) { %>
                                  <a href="../modules/sorties/sorties.aspx" class="quick-action">
                                    <i class="fas fa-arrow-up"></i>
                                    <span data-i18n="menu.sorties"></span>
                                  </a>
                                  <% } %>

                                    <% if (AuthHelper.HasPermission("stock")) { %>
                                      <a href="../modules/stock/stock.aspx" class="quick-action">
                                        <i class="fas fa-warehouse"></i>
                                        <span data-i18n="menu.stock"></span>
                                      </a>
                                      <% } %>

                                        <% if (AuthHelper.HasPermission("inventaire")) { %>
                                          <a href="../exploitations/inv/inventaires.aspx" class="quick-action">
                                            <i class="fas fa-clipboard-list"></i>
                                            <span data-i18n="menu.inventaire"></span>
                                          </a>
                                          <% } %>

                                            <% if (AuthHelper.HasPermission("exploitations")) { %>
                                              <a href="../exploitations/exp/exploitations.aspx" class="quick-action">
                                                <i class="fas fa-clipboard-list"></i>
                                                <span data-i18n="menu.exploitation"></span>
                                              </a>
                                              <% } %>

                                                <% if (AuthHelper.HasPermission("saisies")) { %>
                                                  <a href="../demandes/saisie/saisies.aspx" class="quick-action">
                                                    <i class="fas fa-file-alt"></i>
                                                    <span data-i18n="menu.saisies"></span>
                                                  </a>
                                                  <% } %>

                                                    <% if (AuthHelper.HasPermission("accuses")) { %>
                                                      <a href="../demandes/accuse/accuses.aspx" class="quick-action">
                                                        <i class="fas fa-file-alt"></i>
                                                        <span data-i18n="menu.accuses"></span>
                                                      </a>
                                                      <% } %>

                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- ═══ ZONE 2 : ALERTES ═══ -->
                  <div class="row mt-3">
                    <% if (AuthHelper.HasPermission("stock") || AuthHelper.HasPermission("articles")) { %>
                      <div class="col-lg-6">
                        <div class="dash-card dash-card-alert" id="alertCard" style="display:none;">
                          <div class="dash-card-head">
                            <span class="dash-card-title">
                              <i class="fas fa-exclamation-triangle" style="color:#dc3545;"></i>
                              <span data-i18n="dashboard.stock_rupture"></span>
                              <span class="badge-count" id="alertCount">0</span>
                            </span>
                            <button class="btn btn-sm btn-danger"
                              onclick="location.href='../modules/stock/stock.aspx';return false;">
                              <i class="fas fa-arrow-right"></i>
                              <span data-i18n="dashboard.voir_tout"></span>
                            </button>
                          </div>
                          <div style="overflow-x:auto; max-height:320px;">
                            <table class="dash-table">
                              <thead>
                                <tr>
                                  <th data-i18n="table.code"></th>
                                  <th data-i18n="table.article"></th>
                                  <th data-i18n="table.categorie"></th>
                                  <th data-i18n="table.emplacement"></th>
                                  <th data-i18n="table.seuil"></th>
                                  <th data-i18n="table.qte"></th>
                                  <th data-i18n="table.status"></th>
                                </tr>
                              </thead>
                              <tbody id="tbodyAlerts"></tbody>
                            </table>
                          </div>
                        </div>
                      </div>
                      <% } %>

                        <% if (AuthHelper.HasPermission("stock") || AuthHelper.HasPermission("articles")) { %>
                          <div class="col-lg-6">
                            <div class="dash-card dash-card-alert" id="stockAlertCard" style="display:none;">
                              <div class="dash-card-head">
                                <span class="dash-card-title">
                                  <i class="fas fa-exclamation-triangle" style="color:#ff9800;"></i>
                                  <span data-i18n="dashboard.stock_alerte"></span>
                                  <span class="badge-count" id="stockAlertCount">0</span>
                                </span>
                                <button class="btn btn-sm btn-warning"
                                  onclick="location.href='../modules/stock/stock.aspx';return false;">
                                  <i class="fas fa-arrow-right"></i>
                                  <span data-i18n="dashboard.voir_stock"></span>
                                </button>
                              </div>
                              <div style="overflow-x:auto; max-height:320px;">
                                <table class="dash-table">
                                  <thead>
                                    <tr>
                                      <th data-i18n="table.code"></th>
                                      <th data-i18n="table.article"></th>
                                      <th data-i18n="table.categorie"></th>
                                      <th data-i18n="table.emplacement"></th>
                                      <th data-i18n="table.seuil"></th>
                                      <th data-i18n="table.disponible"></th>
                                      <th data-i18n="table.status"></th>
                                    </tr>
                                  </thead>
                                  <tbody id="tbodyStockAlerts"></tbody>
                                </table>
                              </div>
                            </div>
                          </div>
                          <% } %>
                  </div>

                  <!-- ═══ ZONE 3 : GRAPHIQUES ═══ -->
                  <div class="row mt-3">
                    <% if (AuthHelper.HasPermission("stock")) { %>
                      <div class="col-lg-8">
                        <div class="dash-card">
                          <div class="dash-card-head">
                            <span class="dash-card-title">
                              <span class="dot-blue"></span>
                              <span data-i18n="dashboard.movements_30j"></span>
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
                              <span class="dot-blue"></span>
                              <span data-i18n="dashboard.stock_by_category"></span>
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
                              <span class="dot-green"></span>
                              <span data-i18n="dashboard.derniers_mouvements"></span>
                            </span>
                          </div>
                          <div style="max-height:350px; overflow-y:auto;">
                            <div class="activity-feed" id="activityFeed">
                              <div class="loading-mini" data-i18n="message.loading"></div>
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
                                  <span class="dot-blue"></span>
                                  <span data-i18n="dashboard.derniers_documents"></span>
                                </span>
                              </div>
                              <div style="max-height:350px; overflow-y:auto;">
                                <div class="activity-feed" id="documentsFeed">
                                  <div class="loading-mini" data-i18n="message.loading"></div>
                                </div>
                              </div>
                            </div>
                          </div>
                          <% } %>
                  </div>

                  <!-- ═══ ZONE 5 : TOP ARTICLES ═══ -->
                  <div class="row mt-3">
                    <% if (AuthHelper.HasPermission("stock") || AuthHelper.HasPermission("articles")) { %>
                      <div class="col-lg-6">
                        <div class="dash-card">
                          <div class="dash-card-head">
                            <span class="dash-card-title">
                              <span class="dot-gold"></span>
                              <span data-i18n="dashboard.top_articles"></span>
                            </span>
                          </div>
                          <div class="dash-card-body">
                            <div id="topArticlesList"></div>
                          </div>
                        </div>
                      </div>
                      <% } %>
                  </div>

                </div>
              </section>
            </div>
      </div>

      <div id="spinnerOverlay"
        style="display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.35);z-index:9998;align-items:center;justify-content:center;">
        <div class="ldr" aria-label="Chargement">
          <span></span>
          <span></span>
          <span></span>
          <span></span>
          <span></span>
        </div>
      </div>

      <script src="../_assets/js/chart.umd.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
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
