<%@ Page Language="C#" AutoEventWireup="true" CodeFile="unites.aspx.cs" Inherits="unites" %>
  <!DOCTYPE html>
  <html lang="fr">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Unités — Gestion de Stock</title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="uniteForm" runat="server">
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
                      <h1><i class="fas fa-ruler" style="color:#007bff;"></i> Unités de mesure</h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float:right;">
                        <li class="breadcrumb-item">Stock</li>
                        <li class="breadcrumb-item active">Unités</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content" id="section-unites">

                <!-- CARTES DE SYNTHÈSE (optionnelles) -->
                <div class="row unites-stats" id="unitesStats">
                  <div class="col-lg-4 col-6">
                    <div class="stat-card stat-card-total">
                      <div class="stat-icon"><i class="fas fa-ruler"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statTotal">0</span>
                        <span class="stat-label">Unités totales</span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-4 col-6">
                    <div class="stat-card stat-card-normal">
                      <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statActives">0</span>
                        <span class="stat-label">Unités actives</span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-4 col-6">
                    <div class="stat-card stat-card-inactive">
                      <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statInactives">0</span>
                        <span class="stat-label">Unités inactives</span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title"><i class="fas fa-ruler"></i> Liste des unités</span>
                    <div class="action-buttons">
                      <button class="btn btn-success btn-sm" onclick="openAddUniteModal(event)" type="button">
                        <i class="fas fa-plus"></i> Ajouter
                      </button>
                      <button class="btn btn-primary btn-sm" onclick="exportUnitesPDF()" type="button">
                        <i class="fas fa-file-pdf"></i> PDF
                      </button>
                      <button class="btn btn-outline-success btn-sm" onclick="exportUnitesToExcelOnly()" type="button">
                        <i class="fas fa-file-excel"></i> Excel
                      </button>
                    </div>
                  </div>

                  <!-- BARRE DE FILTRES -->
                  <div class="dash-card-toolbar">
                    <div class="toolbar-search">
                      <i class="fas fa-search"></i>
                      <input type="text" id="search-filter" class="form-control"
                        placeholder="Rechercher par code ou nom…" autocomplete="off" />
                    </div>
                    <select id="status-filter" class="form-control toolbar-select">
                      <option value="">Tous statuts</option>
                      <option value="1">Actif</option>
                      <option value="0">Inactif</option>
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
                    <span class="toolbar-counter" id="resultsCounter">0 unité(s)</span>
                  </div>

                  <div class="dash-card-body">
                    <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                      <table class="dash-table"
                        style="table-layout:fixed; width:100%; min-width:600px; border-collapse:collapse;">
                        <thead>
                          <tr style="background-color:#f8f9fa; text-align:left;">
                            <th onclick="sortData('CODE')" style="cursor:pointer; width:120px;">CODE <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('NOM')" style="cursor:pointer; width:200px;">NOM <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('ACTIVE')" style="cursor:pointer; width:100px;">STATUT <i
                                class="fas fa-sort ml-1"></i></th>
                            <th style="width:130px;">ACTIONS</th>
                          </tr>
                        </thead>
                        <tbody id="unitesTableBody">
                          <tr>
                            <td colspan="4" style="text-align:center;padding:40px;">
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

      <!-- MODALE AJOUT / MODIFICATION UNITÉ -->
      <div id="uniteModal" class="modal">
        <input type="hidden" id="editingId" value="" />
        <div class="modal-content modal-unite" style="max-width:600px;">
          <div class="modal-header">
            <h3 id="modalTitle"><i class="fas fa-ruler"></i> Ajouter une unité</h3>
            <span class="close" onclick="closeUniteModal()">&times;</span>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Code <small class="text-muted">(généré automatiquement)</small></label>
              <input type="text" id="uniteCode" class="form-control" placeholder="UNT-XXX-00001" readonly />
              <small class="field-error" id="err-uniteCode"></small>
            </div>
            <div class="form-group">
              <label>Nom <span class="text-danger">*</span></label>
              <input type="text" id="uniteNom" class="form-control" placeholder="Ex: Kilogramme" required />
              <small class="field-error" id="err-uniteNom"></small>
            </div>
            <div class="form-group">
              <label>Actif <span class="text-danger">*</span></label>
              <select id="uniteActif" class="form-control">
                <option value="1">Oui</option>
                <option value="0">Non</option>
              </select>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" id="btnSaveUnite" onclick="saveUnite(event)" type="button">
              <i class="fas fa-save"></i> Enregistrer
            </button>
            <button class="btn btn-danger" onclick="closeUniteModal()" type="button">
              <i class="fas fa-times"></i> Annuler
            </button>
          </div>
        </div>
      </div>

      <!-- SPINNER -->
      <div id="spinnerOverlays" aria-hidden="true" style="display:none;visibility:hidden;">
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
      <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
      <script>
        window.BASE_PATH = '<%= ResolveUrl("~/") %>';
      </script>
      <div id="toastContainer"></div>
    </form>
  </body>

  </html>
