<%@ Page Language="C#" AutoEventWireup="true" CodeFile="emplacement.aspx.cs" Inherits="emplacement" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">

<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title><%= LocalizationHelper.GetString("emplacements.title") %> — <%= LocalizationHelper.GetString("app.name") %></title>
  <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
  <form id="emplacementForm" runat="server">
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
                  <i class="fas fa-warehouse" style="color:#007bff;"></i>
                  <span data-i18n="emplacements.title"></span>
                </h1>
              </div>
              <div class="col-lg-6">
                <ol class="breadcrumb" style="float:right;">
                  <li class="breadcrumb-item" data-i18n="menu.stock"></li>
                  <li class="breadcrumb-item active" data-i18n="menu.emplacements"></li>
                </ol>
              </div>
            </div>
          </div>
        </div>

        <section class="content" id="section-emplacements">

          <!-- CARTES DE SYNTHÈSE -->
          <div class="row emplacements-stats" id="emplacementsStats">
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-total">
                <div class="stat-icon"><i class="fas fa-warehouse"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statTotal">0</span>
                  <span class="stat-label" data-i18n="emplacements.stat.total"></span>
                </div>
              </div>
            </div>
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-normal">
                <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statActifs">0</span>
                  <span class="stat-label" data-i18n="emplacements.stat.active"></span>
                </div>
              </div>
            </div>
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-rupture">
                <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statInactifs">0</span>
                  <span class="stat-label" data-i18n="emplacements.stat.inactive"></span>
                </div>
              </div>
            </div>
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-alerte">
                <div class="stat-icon"><i class="fas fa-sitemap"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statSousEmplacements">0</span>
                  <span class="stat-label" data-i18n="emplacements.stat.sub"></span>
                </div>
              </div>
            </div>
          </div>

          <div class="dash-card">
            <div class="dash-card-head">
              <span class="dash-card-title">
                <i class="fas fa-warehouse"></i>
                <span data-i18n="emplacements.list_title"></span>
              </span>
              <div class="action-buttons">
                <button class="btn btn-success btn-sm" onclick="openAddEmplacementModal(event)" type="button">
                  <i class="fas fa-plus"></i> <span data-i18n="emplacements.btn.add"></span>
                </button>
                <button class="btn btn-primary btn-sm" onclick="exportEmplacementsPDF()" type="button">
                  <i class="fas fa-file-pdf"></i> <span data-i18n="emplacements.btn.pdf"></span>
                </button>
                <button class="btn btn-outline-success btn-sm" onclick="exportEmplacementsToExcelOnly()" type="button">
                  <i class="fas fa-file-excel"></i> <span data-i18n="emplacements.btn.excel"></span>
                </button>
              </div>
            </div>

            <!-- BARRE DE FILTRES -->
            <div class="dash-card-toolbar">
              <div class="toolbar-search">
                <i class="fas fa-search"></i>
                <input type="text" id="search-filter" class="form-control"
                  data-i18n-attr="placeholder:emplacements.search_placeholder" autocomplete="off" />
              </div>
              <select id="type-filter" class="form-control toolbar-select">
                <option value="" data-i18n="emplacements.filter.all_types"></option>
              </select>
              <select id="parent-filter" class="form-control toolbar-select">
                <option value="" data-i18n="emplacements.filter.all_parents"></option>
              </select>
              <select id="rows-per-page-top" class="form-control toolbar-select">
                <option value="10" data-i18n="emplacements.rows_per_page.10"></option>
                <option value="25" data-i18n="emplacements.rows_per_page.25"></option>
                <option value="50" data-i18n="emplacements.rows_per_page.50"></option>
                <option value="100" data-i18n="emplacements.rows_per_page.100"></option>
                <option value="all" data-i18n="emplacements.rows_per_page.all"></option>
              </select>
              <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                data-i18n-attr="title:emplacements.reset_filters">
                <i class="fas fa-undo"></i>
              </button>
              <span class="toolbar-counter" id="resultsCounter" data-i18n="emplacements.counter.zero"></span>
            </div>

            <div class="dash-card-body">
              <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                <table class="dash-table"
                  style="table-layout:fixed; width:100%; min-width:800px; border-collapse:collapse;">
                  <thead>
                    <tr style="background-color:#f8f9fa; text-align:left;">
                      <th onclick="sortData('CODE')" style="cursor:pointer; width:120px;">
                        <span data-i18n="emplacements.table.code"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('NOM')" style="cursor:pointer; width:180px;">
                        <span data-i18n="emplacements.table.nom"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('TYPE')" style="cursor:pointer; width:120px;">
                        <span data-i18n="emplacements.table.type"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('PARENT_NOM')" style="cursor:pointer; width:150px;">
                        <span data-i18n="emplacements.table.parent"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('ACTIVE')" style="cursor:pointer; width:90px;">
                        <span data-i18n="emplacements.table.statut"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th style="width:130px;">
                        <span data-i18n="emplacements.table.actions"></span>
                      </th>
                    </tr>
                  </thead>
                  <tbody id="emplacementsTableBody">
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

    <!-- MODAL AJOUT / MODIFICATION -->
    <div id="emplacementModal" class="modal">
      <input type="hidden" id="editingId" value="" />
      <div class="modal-content modal-emplacement" style="max-width:600px;">
        <div class="modal-header">
          <h3 id="modalTitle">
            <i class="fas fa-warehouse"></i>
            <span data-i18n="emplacements.modal.add_title"></span>
          </h3>
          <span class="close" onclick="closeEmplacementModal()">&times;</span>
        </div>
        <div class="modal-body">
          <div class="row">
            <div class="col-md-12">
              <div class="form-group">
                <label>
                  <span data-i18n="emplacements.modal.code_label"></span>
                  <small class="text-muted" data-i18n="emplacements.modal.code_hint"></small>
                </label>
                <input type="text" id="emplacementCode" class="form-control"
                  data-i18n-attr="placeholder:emplacements.modal.code_placeholder" readonly />
                <small class="field-error" id="err-emplacementCode"></small>
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col-md-12">
              <div class="form-group">
                <label>
                  <span data-i18n="emplacements.modal.nom_label"></span>
                  <span class="text-danger">*</span>
                </label>
                <input type="text" id="emplacementNom" class="form-control"
                  data-i18n-attr="placeholder:emplacements.modal.nom_placeholder" required>
                <small class="field-error" id="err-emplacementNom"></small>
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col-md-6">
              <div class="form-group">
                <label>
                  <span data-i18n="emplacements.modal.type_label"></span>
                  <span class="text-danger">*</span>
                </label>
                <select id="emplacementType" class="form-control">
                  <option value="" data-i18n="emplacements.modal.type_select"></option>
                </select>
                <small class="field-error" id="err-emplacementType"></small>
              </div>
            </div>
            <div class="col-md-6">
              <div class="form-group">
                <label data-i18n="emplacements.modal.parent_label"></label>
                <select id="emplacementParent" class="form-control">
                  <option value="" data-i18n="emplacements.modal.parent_none"></option>
                </select>
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col-md-6">
              <div class="form-group">
                <label>
                  <span data-i18n="emplacements.modal.actif_label"></span>
                  <span class="text-danger">*</span>
                </label>
                <select id="emplacementActif" class="form-control">
                  <option value="1" data-i18n="button.yes"></option>
                  <option value="0" data-i18n="button.no"></option>
                </select>
              </div>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-primary" id="btnSaveEmplacement" onclick="saveEmplacement(event)" type="button">
            <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
          </button>
          <button class="btn btn-danger" onclick="closeEmplacementModal()" type="button">
            <i class="fas fa-times"></i> <span data-i18n="button.cancel"></span>
          </button>
        </div>
      </div>
    </div>

    <div id="spinnerOverlays" aria-hidden="true" style="display:none;visibility:hidden;">
      <div class="spinner"></div>
    </div>

    <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/jspdf.umd.min.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/jspdf.plugin.autotable.min.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/xlsx.full.min.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/vfs_fonts.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
    <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
    <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
    <div id="toastContainer"></div>
  </form>
</body>

</html>
