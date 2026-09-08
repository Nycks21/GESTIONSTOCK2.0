<%@ Page Language="C#" AutoEventWireup="true" CodeFile="stock.aspx.cs" Inherits="stock" %>
  <!DOCTYPE html>
  <html lang="fr">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Stock — Gestion de Stock</title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="stockForm" runat="server">
      <div class="wrapper">
        <!-- Topbar -->
        <%= AuthHelper.RenderTopBarHTML() %>

          <!-- Sidebar -->
          <aside class="main-sidebar" id="sidebar">
            <a href="#" class="brand-link" onclick="loadDashboard()">
              <img
                src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='33' height='33' viewBox='0 0 33 33'%3E%3Ccircle cx='16.5' cy='16.5' r='16.5' fill='%23007bff'/%3E%3Ctext x='16.5' y='22' font-size='16' font-weight='bold' text-anchor='middle' fill='white'%3EGS%3C/text%3E%3C/svg%3E"
                alt="Logo" class="brand-image" />
              <span class="brand-text">Gestion de Stock</span>
            </a>
            <div class="sidebar">
              <%= AuthHelper.RenderMenuHTML() %>
            </div>
          </aside>

          <!-- Control Sidebar -->
          <%= AuthHelper.RenderControlSidebarHTML() %>

            <!-- Content -->
            <div class="content-wrapper" id="contentWrapper">
              <div class="content-header">
                <div class="container-fluid">
                  <div class="row">
                    <div class="col-lg-6">
                      <h1><i class="fas fa-cubes" style="color:#007bff;"></i> Stock</h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float:right;">
                        <li class="breadcrumb-item">Stock</li>
                        <li class="breadcrumb-item active">Stock</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content" id="section-stock">

                <!-- CARTES DE SYNTHÈSE -->
                <div class="row stock-stats" id="stockStats">
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-total">
                      <div class="stat-icon"><i class="fas fa-cubes"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statTotalArticles">0</span>
                        <span class="stat-label">Articles en stock</span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-normal">
                      <div class="stat-icon"><i class="fas fa-warehouse"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statTotalQuantite">0</span>
                        <span class="stat-label">Quantité totale</span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-alerte">
                      <div class="stat-icon"><i class="fas fa-exclamation-triangle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statSousSeuil">0</span>
                        <span class="stat-label">Sous seuil d'alerte</span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-rupture">
                      <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statRupture">0</span>
                        <span class="stat-label">En rupture (0)</span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title"><i class="fas fa-cubes"></i> État du stock</span>
                    <div class="action-buttons">
                      <button class="btn btn-success btn-sm" onclick="openAdjustModal(event)" type="button">
                        <i class="fas fa-exchange-alt"></i> Ajuster
                      </button>
                      <button class="btn btn-primary btn-sm" onclick="exportStockPDF()" type="button">
                        <i class="fas fa-file-pdf"></i> PDF
                      </button>
                      <button class="btn btn-outline-success btn-sm" onclick="exportStockToExcelOnly()" type="button">
                        <i class="fas fa-file-excel"></i> Excel
                      </button>
                    </div>
                  </div>

                  <!-- BARRE DE FILTRES -->
                  <div class="dash-card-toolbar">
                    <div class="toolbar-search">
                      <i class="fas fa-search"></i>
                      <input type="text" id="search-filter" class="form-control"
                        placeholder="Rechercher par article ou code…" autocomplete="off" />
                    </div>
                    <select id="article-filter" class="form-control toolbar-select">
                      <option value="">Tous articles</option>
                    </select>
                    <select id="emplacement-filter" class="form-control toolbar-select">
                      <option value="">Tous emplacements</option>
                    </select>
                    <select id="rows-per-page-top" class="form-control toolbar-select">
                      <option value="10">10 par page</option>
                      <option value="25">25 par page</option>
                      <option value="50">50 par page</option>
                      <option value="100">100 par page</option>
                      <option value="all">Tous</option>
                    </select>
                    <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                      title="Réinitialiser les filtres">
                      <i class="fas fa-undo"></i>
                    </button>
                    <span class="toolbar-counter" id="resultsCounter">0 ligne(s)</span>
                  </div>

                  <div class="dash-card-body">
                    <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                      <table class="dash-table"
                        style="table-layout:fixed; width:100%; min-width:900px; border-collapse:collapse;">
                        <thead>
                          <tr style="background-color:#f8f9fa; text-align:left;">
                            <th onclick="sortData('ARTICLE_NOM')" style="cursor:pointer; width:260px;">ARTICLE <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('ENTREE')" style="cursor:pointer; width:110px;">ENTRÉE <i
                              class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('SORTIE')" style="cursor:pointer; width:110px;">SORTIE <i
                              class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('DISPONIBLE')" style="cursor:pointer; width:120px;">DISPONIBLE <i
                              class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('STATUT')" style="cursor:pointer; width:150px;">STATUT <i
                                class="fas fa-sort ml-1"></i></th>
                            <th style="width:150px;">ACTIONS</th>
                          </tr>
                        </thead>
                        <tbody id="stockTableBody">
                          <tr>
                            <td colspan="6" style="text-align:center;padding:40px;">
                              <i class="fas fa-spinner fa-spin" style="font-size:24px;color:#ccc;"></i>
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                    <div class="pagination-wrapper" id="paginationWrapper"></div>
                  </div>
                </div>
              </section>
            </div>
      </div>

      <!-- MODAL AJUSTEMENT DE STOCK -->
      <div id="adjustModal" class="modal">
        <input type="hidden" id="editingId" value="" />
        <div class="modal-content modal-adjust" style="max-width:500px;">
          <div class="modal-header">
            <h3 id="modalTitle"><i class="fas fa-exchange-alt"></i> Ajuster le stock</h3>
            <span class="close" onclick="closeAdjustModal()">&times;</span>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Article <span class="text-danger">*</span></label>
              <select id="adjustArticle" class="form-control">
                <option value="">-- Sélectionner --</option>
              </select>
              <small class="field-error" id="err-adjustArticle"></small>
            </div>
            <div class="form-group">
              <label>Emplacement <span class="text-danger">*</span></label>
              <select id="adjustEmplacement" class="form-control">
                <option value="">-- Sélectionner --</option>
              </select>
              <small class="field-error" id="err-adjustEmplacement"></small>
            </div>
            <div class="form-group">
              <label>Type de mouvement <span class="text-danger">*</span></label>
              <select id="adjustType" class="form-control">
                <option value="ENTREE">Entrée</option>
                <option value="SORTIE">Sortie</option>
              </select>
            </div>
            <div class="form-group">
              <label>Quantité <span class="text-danger">*</span></label>
              <input type="number" id="adjustQuantite" class="form-control" step="0.01" min="0.01" />
              <small class="field-error" id="err-adjustQuantite"></small>
            </div>
            <div class="form-group">
              <label>Motif</label>
              <input type="text" id="adjustMotif" class="form-control"
                placeholder="Ex: Réapprovisionnement, cassé, etc." />
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" id="btnSaveAdjust" onclick="saveAdjust(event)" type="button">
              <i class="fas fa-save"></i> Enregistrer
            </button>
            <button class="btn btn-danger" onclick="closeAdjustModal()" type="button">
              <i class="fas fa-times"></i> Annuler
            </button>
          </div>
        </div>
      </div>

      <!-- MODALE HISTORIQUE -->
      <div id="historyModal" class="modal">
        <div class="modal-content" style="max-width:800px;">
          <div class="modal-header">
            <h3><i class="fas fa-history"></i> Historique des mouvements</h3>
            <span class="close" onclick="closeHistoryModal()">&times;</span>
          </div>
          <div class="modal-body">
            <div style="overflow-x:auto;">
              <table class="dash-table" style="width:100%; border-collapse:collapse;">
                <thead>
                  <tr style="background-color:#f8f9fa; text-align:left;">
                    <th>Date</th>
                    <th>Type</th>
                    <th>Quantité</th>
                    <th>Avant</th>
                    <th>Après</th>
                    <th style="width:150px;">Statut de Validation</th>
                    <th>Référence</th>
                  </tr>
                </thead>
                <tbody id="historyTableBody">
                  <tr>
                    <td colspan="7" style="text-align:center;padding:20px;">Chargement...</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div class="pagination-wrapper" id="historyPagination"></div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" onclick="closeHistoryModal()" type="button">Fermer</button>
          </div>
        </div>
      </div>

      <!-- SPINNER -->
      <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
        <div class="spinner"></div>
      </div>

      <!-- SCRIPTS -->
      <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/jspdf.umd.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/jspdf.plugin.autotable.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/xlsx.full.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/vfs_fonts.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
      <script>
        window.BASE_PATH = '<%= ResolveUrl("~/") %>';
      </script>
      <div id="toastContainer"></div>
    </form>
  </body>

  </html>
