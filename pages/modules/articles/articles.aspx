<%@ Page Language="C#" AutoEventWireup="true" CodeFile="articles.aspx.cs" Inherits="articles" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">

<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title><%= LocalizationHelper.GetString("articles.title") %> — <%= LocalizationHelper.GetString("app.name") %></title>
  <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
  <form id="articleForm" runat="server">
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
                  <i class="fas fa-boxes" style="color:#007bff;"></i>
                  <span data-i18n="articles.title"></span>
                </h1>
              </div>
              <div class="col-lg-6">
                <ol class="breadcrumb" style="float:right;">
                  <li class="breadcrumb-item" data-i18n="menu.stock"></li>
                  <li class="breadcrumb-item active" data-i18n="menu.articles"></li>
                </ol>
              </div>
            </div>
          </div>
        </div>

        <section class="content" id="section-articles">
          <!-- Cartes de synthèse -->
          <div class="row articles-stats" id="articlesStats">
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-total">
                <div class="stat-icon"><i class="fas fa-boxes"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statTotal">0</span>
                  <span class="stat-label" data-i18n="articles.stat.total"></span>
                </div>
              </div>
            </div>
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-normal">
                <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statNormal">0</span>
                  <span class="stat-label" data-i18n="articles.stat.normal"></span>
                </div>
              </div>
            </div>
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-alerte">
                <div class="stat-icon"><i class="fas fa-exclamation-triangle"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statAlerte">0</span>
                  <span class="stat-label" data-i18n="articles.stat.alerte"></span>
                </div>
              </div>
            </div>
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-rupture">
                <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statRupture">0</span>
                  <span class="stat-label" data-i18n="articles.stat.rupture"></span>
                </div>
              </div>
            </div>
          </div>

          <div class="dash-card">
            <div class="dash-card-head">
              <span class="dash-card-title">
                <i class="fas fa-boxes"></i>
                <span data-i18n="articles.list_title"></span>
              </span>
              <div class="action-buttons">
                <button class="btn btn-success btn-sm" onclick="openAddArticleModal(event)" type="button">
                  <i class="fas fa-plus"></i> <span data-i18n="articles.btn.add"></span>
                </button>
                <button class="btn btn-outline-secondary btn-sm" onclick="openImportModal(event)" type="button">
                  <i class="fas fa-file-import"></i> <span data-i18n="articles.btn.import"></span>
                </button>
                <button class="btn btn-primary btn-sm" onclick="exportArticlesPDF()" type="button">
                  <i class="fas fa-file-pdf"></i> <span data-i18n="articles.btn.pdf"></span>
                </button>
                <button class="btn btn-outline-success btn-sm" onclick="exportArticlesToExcelOnly()" type="button">
                  <i class="fas fa-file-excel"></i> <span data-i18n="articles.btn.excel"></span>
                </button>
              </div>
            </div>

            <!-- Barre de filtres persistante -->
            <div class="dash-card-toolbar">
              <div class="toolbar-search">
                <i class="fas fa-search"></i>
                <input type="text" id="search-filter" class="form-control"
                  data-i18n-attr="placeholder:articles.search_placeholder" autocomplete="off" />
              </div>
              <select id="category-filter" class="form-control toolbar-select">
                <option value="" data-i18n="articles.filter.all_categories"></option>
              </select>
              <select id="status-filter" class="form-control toolbar-select">
                <option value="" data-i18n="articles.filter.all_statuses"></option>
                <option value="normal" data-i18n="articles.status.normal"></option>
                <option value="alerte" data-i18n="articles.status.alerte"></option>
                <option value="rupture" data-i18n="articles.status.rupture"></option>
              </select>
              <select id="rows-per-page-top" class="form-control toolbar-select">
                <option value="10" data-i18n="articles.rows_per_page.10"></option>
                <option value="25" data-i18n="articles.rows_per_page.25"></option>
                <option value="50" data-i18n="articles.rows_per_page.50"></option>
                <option value="100" data-i18n="articles.rows_per_page.100"></option>
                <option value="all" data-i18n="articles.rows_per_page.all"></option>
              </select>
              <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                data-i18n-attr="title:articles.reset_filters">
                <i class="fas fa-undo"></i>
              </button>
              <span class="toolbar-counter" id="resultsCounter" data-i18n="articles.counter.zero"></span>
            </div>

            <div class="dash-card-body">
              <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                <table class="dash-table"
                  style="table-layout:fixed; width:1300px; min-width:100%; border-collapse:collapse;">
                  <thead>
                    <tr style="background-color:#f8f9fa; text-align:left;">
                      <th onclick="sortData('CODE')" style="cursor:pointer; width:140px;">
                        <span data-i18n="articles.table.code"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('NOM')" style="cursor:pointer; width:160px;">
                        <span data-i18n="articles.table.nom"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('CATEGORIE_NOM')" style="cursor:pointer; width:130px;">
                        <span data-i18n="articles.table.categorie"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('FOURNISSEUR_NOM')" style="cursor:pointer; width:130px;">
                        <span data-i18n="articles.table.fournisseur"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('UNITE_SYMBOLE')" style="cursor:pointer; width:80px;">
                        <span data-i18n="articles.table.unite"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('STOCK_TOTAL')" style="cursor:pointer; width:100px;">
                        <span data-i18n="articles.table.stock"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('SEUIL_ALERTE')" style="cursor:pointer; width:90px;">
                        <span data-i18n="articles.table.seuil"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('STATUT_STOCK')" style="cursor:pointer; width:100px;">
                        <span data-i18n="articles.table.statut"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th style="width:130px;">
                        <span data-i18n="articles.table.actions"></span>
                      </th>
                    </tr>
                  </thead>
                  <tbody id="articlesTableBody">
                    <tr>
                      <td colspan="9" style="text-align:center;padding:40px;">
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
    <div id="articleModal" class="modal">
      <input type="hidden" id="editingId" value="" />
      <div class="modal-content modal-article" style="max-width:750px;">
        <div class="modal-header">
          <h3 id="modalTitle">
            <i class="fas fa-box"></i>
            <span data-i18n="articles.modal.add_title"></span>
          </h3>
          <span class="close" onclick="closeArticleModal()">&times;</span>
        </div>
        <div class="modal-body">
          <div class="row">
            <div class="col-md-6">
              <div class="form-group">
                <label>
                  <span data-i18n="articles.modal.code_label"></span>
                  <small class="text-muted" data-i18n="articles.modal.code_hint"></small>
                </label>
                <input type="text" id="articleCode" class="form-control"
                  data-i18n-attr="placeholder:articles.modal.code_placeholder" readonly />
                <small class="field-error" id="err-articleCode"></small>
              </div>
            </div>
            <div class="col-md-6">
              <div class="form-group">
                <label>
                  <span data-i18n="articles.modal.nom_label"></span>
                  <span class="text-danger">*</span>
                </label>
                <input type="text" id="articleNom" class="form-control"
                  data-i18n-attr="placeholder:articles.modal.nom_placeholder" required />
                <small class="field-error" id="err-articleNom"></small>
              </div>
            </div>
          </div>
          <div class="form-group">
            <label data-i18n="articles.modal.description_label"></label>
            <textarea id="articleDescription" class="form-control" rows="2"
              data-i18n-attr="placeholder:articles.modal.description_placeholder"
              style="resize: vertical;"></textarea>
          </div>
          <div class="row">
            <div class="col-md-6">
              <div class="form-group">
                <label data-i18n="articles.modal.categorie_label"></label>
                <select id="articleCategorie" class="form-control">
                  <option value="" data-i18n="articles.modal.categorie_select"></option>
                </select>
              </div>
            </div>
            <div class="col-md-6">
              <div class="form-group">
                <label data-i18n="articles.modal.fournisseur_label"></label>
                <select id="articleFournisseur" class="form-control">
                  <option value="" data-i18n="articles.modal.fournisseur_none"></option>
                </select>
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col-md-6">
              <div class="form-group">
                <label>
                  <span data-i18n="articles.modal.unite_label"></span>
                  <span class="text-danger">*</span>
                </label>
                <select id="articleUnite" class="form-control" required>
                  <option value="" data-i18n="articles.modal.unite_select"></option>
                </select>
                <small class="field-error" id="err-articleUnite"></small>
              </div>
            </div>
            <div class="col-md-6">
              <div class="form-group">
                <label>
                  <span data-i18n="articles.modal.emplacement_label"></span>
                  <span class="text-danger">*</span>
                </label>
                <select id="articleEmplacement" class="form-control" required>
                  <option value="" data-i18n="articles.modal.emplacement_select"></option>
                </select>
                <small class="field-error" id="err-articleEmplacement"></small>
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col-md-12">
              <div class="form-group">
                <label data-i18n="articles.modal.seuil_label"></label>
                <input type="number" id="articleSeuilAlerte" class="form-control" step="0.01" value="0" />
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col-md-6">
              <div class="form-group">
                <label data-i18n="articles.modal.actif_label"></label>
                <select id="articleActif" class="form-control">
                  <option value="1" data-i18n="button.yes"></option>
                  <option value="0" data-i18n="button.no"></option>
                </select>
              </div>
            </div>
            <div class="col-md-6">
              <div class="form-group">
                <label data-i18n="articles.modal.service_label"></label>
                <select id="articleEstService" class="form-control">
                  <option value="0" data-i18n="button.no"></option>
                  <option value="1" data-i18n="button.yes"></option>
                </select>
              </div>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-primary" id="btnSaveArticle" onclick="saveArticle(event)" type="button">
            <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
          </button>
          <button class="btn btn-danger" onclick="closeArticleModal()" type="button">
            <i class="fas fa-times"></i> <span data-i18n="button.cancel"></span>
          </button>
        </div>
      </div>
    </div>

    <!-- MODAL IMPORTATION EXCEL -->
    <div id="modalImport" class="modal">
      <div class="modal-content" style="max-width:500px;">
        <div class="modal-header">
          <h3>
            <i class="fas fa-file-import"></i>
            <span data-i18n="articles.import.title"></span>
          </h3>
          <span class="close" onclick="closeImportModal()">&times;</span>
        </div>
        <div class="modal-body">
          <p class="text-muted" data-i18n="articles.import.help"></p>
          <div class="form-group">
            <label class="btn btn-outline-primary btn-block" for="excelFile">
              <i class="fas fa-upload"></i> <span data-i18n="articles.import.choose"></span>
            </label>
            <input type="file" id="excelFile" accept=".xlsx,.xls" style="display:none;" />
            <input type="text" id="fileNameDisplay" class="form-control text-center mt-2" readonly
              data-i18n-attr="placeholder:articles.import.no_file" />
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-primary" id="btnLaunchImport" onclick="launchImport()" type="button" disabled>
            <i class="fas fa-check"></i> <span data-i18n="articles.import.launch"></span>
          </button>
          <button class="btn btn-danger" onclick="closeImportModal()" type="button">
            <i class="fas fa-times"></i> <span data-i18n="button.cancel"></span>
          </button>
        </div>
      </div>
    </div>

    <!-- MODAL AJUSTEMENT STOCK -->
    <div id="adjustModal" class="modal">
      <div class="modal-content" style="max-width:500px;">
        <div class="modal-header">
          <h3>
            <i class="fas fa-exchange-alt"></i>
            <span data-i18n="articles.adjust.title"></span>
          </h3>
          <span class="close" onclick="closeAdjustModal()">&times;</span>
        </div>
        <div class="modal-body">
          <input type="hidden" id="adjustArticle" />
          <input type="hidden" id="adjustEmplacement" />
          <div class="form-group">
            <label>
              <span data-i18n="articles.adjust.type_label"></span>
              <span class="text-danger">*</span>
            </label>
            <select id="adjustType" class="form-control">
              <option value="ENTREE" data-i18n="articles.adjust.type_entry"></option>
              <option value="SORTIE" data-i18n="articles.adjust.type_exit"></option>
            </select>
          </div>
          <div class="form-group">
            <label>
              <span data-i18n="articles.adjust.qty_label"></span>
              <span class="text-danger">*</span>
            </label>
            <input type="number" id="adjustQuantite" class="form-control" step="0.01" min="0.01"
              data-i18n-attr="placeholder:articles.adjust.qty_placeholder" />
            <small class="field-error" id="err-adjustQuantite"></small>
          </div>
          <div class="form-group">
            <label data-i18n="articles.adjust.motif_label"></label>
            <input type="text" id="adjustMotif" class="form-control"
              data-i18n-attr="placeholder:articles.adjust.motif_placeholder" />
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-primary" onclick="saveAdjust(event)" type="button">
            <i class="fas fa-save"></i> <span data-i18n="button.validate"></span>
          </button>
          <button class="btn btn-danger" onclick="closeAdjustModal()" type="button">
            <i class="fas fa-times"></i> <span data-i18n="button.cancel"></span>
          </button>
        </div>
      </div>
    </div>

    <!-- MODAL HISTORIQUE -->
    <div id="historyModal" class="modal">
      <div class="modal-content" style="max-width:800px;">
        <div class="modal-header">
          <h3>
            <i class="fas fa-history"></i>
            <span data-i18n="articles.history.title"></span>
          </h3>
          <span class="close" onclick="closeHistoryModal()">&times;</span>
        </div>
        <div class="modal-body">
          <div style="overflow-x:auto;">
            <table class="dash-table" style="width:100%; text-align: left;">
              <thead>
                <tr>
                  <th data-i18n="articles.history.date"></th>
                  <th data-i18n="articles.history.type"></th>
                  <th data-i18n="articles.history.qty"></th>
                  <th data-i18n="articles.history.before"></th>
                  <th data-i18n="articles.history.after"></th>
                  <th style="width:150px;" data-i18n="articles.history.motif"></th>
                  <th data-i18n="articles.history.reference"></th>
                </tr>
              </thead>
              <tbody id="historyTableBody">
                <tr>
                  <td colspan="7" style="text-align:center;" data-i18n="articles.history.no_data"></td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="pagination-wrapper" id="historyPagination"></div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-danger" onclick="closeHistoryModal()" type="button">
            <i class="fas fa-times"></i> <span data-i18n="button.close"></span>
          </button>
        </div>
      </div>
    </div>

    <!-- SPINNER -->
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
