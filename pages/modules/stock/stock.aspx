<%@ Page Language="C#" AutoEventWireup="true" CodeFile="stock.aspx.cs" Inherits="stock" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title data-i18n="stock.title">Stock — Gestion de Stock</title>
  <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>"
      data-user-role="<%= AuthHelper.GetUserRole(Context) %>">
<form id="stockForm" runat="server">
  <div class="wrapper">
    <%= AuthHelper.RenderTopBarHTML() %>

    <aside class="main-sidebar" id="sidebar">
      <div class="sidebar"><%= AuthHelper.RenderMenuHTML() %></div>
    </aside>

    <%= AuthHelper.RenderControlSidebarHTML() %>

    <div class="content-wrapper" id="contentWrapper">
      <div class="content-header">
        <div class="container-fluid">
          <div class="row">
            <div class="col-lg-6">
              <h1>
                <i class="fas fa-cubes" style="color:#007bff;"></i>
                <span data-i18n="stock.title">Stock</span>
              </h1>
            </div>
            <div class="col-lg-6">
              <ol class="breadcrumb" style="float:right;">
                <li class="breadcrumb-item" data-i18n="stock.breadcrumb.stock">Stock</li>
                <li class="breadcrumb-item active" data-i18n="stock.breadcrumb.active">Stock</li>
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
                <span class="stat-label" data-i18n="stock.stat.total_articles">Articles en stock</span>
              </div>
            </div>
          </div>
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-normal">
              <div class="stat-icon"><i class="fas fa-warehouse"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statTotalQuantite">0</span>
                <span class="stat-label" data-i18n="stock.stat.total_quantite">Quantité totale</span>
              </div>
            </div>
          </div>
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-alerte">
              <div class="stat-icon"><i class="fas fa-exclamation-triangle"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statSousSeuil">0</span>
                <span class="stat-label" data-i18n="stock.stat.sous_seuil">Sous seuil d'alerte</span>
              </div>
            </div>
          </div>
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-rupture">
              <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statRupture">0</span>
                <span class="stat-label" data-i18n="stock.stat.rupture">En rupture (0)</span>
              </div>
            </div>
          </div>
        </div>

        <div class="dash-card">
          <div class="dash-card-head">
            <span class="dash-card-title">
              <i class="fas fa-cubes"></i>
              <span data-i18n="stock.list_title">État du stock</span>
            </span>
            <div class="action-buttons">
              <button class="btn btn-primary btn-sm" onclick="exportStockPDF()" type="button">
                <i class="fas fa-file-pdf"></i>
                <span data-i18n="stock.btn.pdf">PDF</span>
              </button>
              <button class="btn btn-outline-success btn-sm" onclick="exportStockToExcelOnly()" type="button">
                <i class="fas fa-file-excel"></i>
                <span data-i18n="stock.btn.excel">Excel</span>
              </button>
            </div>
          </div>

          <!-- BARRE DE FILTRES -->
          <div class="dash-card-toolbar">
            <div class="toolbar-search">
              <i class="fas fa-search"></i>
              <input type="text" id="search-filter" class="form-control"
                     data-i18n-attr="placeholder:stock.search_placeholder"
                     placeholder="Rechercher par article ou code…" autocomplete="off" />
            </div>
            <select id="article-filter" class="form-control toolbar-select">
              <option value="" data-i18n="stock.filter.all_articles">Tous articles</option>
            </select>
            <select id="emplacement-filter" class="form-control toolbar-select">
              <option value="" data-i18n="stock.filter.all_emplacements">Tous emplacements</option>
            </select>
            <select id="statut-filter" class="form-control toolbar-select">
              <option value="" data-i18n="stock.filter.all_statuts">Tous les statuts</option>
              <option value="NORMAL"  data-i18n="stock.filter.statut.normal">Normal</option>
              <option value="ALERTE"  data-i18n="stock.filter.statut.alerte">Alerte</option>
              <option value="RUPTURE" data-i18n="stock.filter.statut.rupture">Rupture</option>
            </select>
            <select id="rows-per-page-top" class="form-control toolbar-select">
              <option value="10"  data-i18n="stock.rows_per_page.10">10 par page</option>
              <option value="25"  data-i18n="stock.rows_per_page.25">25 par page</option>
              <option value="50"  data-i18n="stock.rows_per_page.50">50 par page</option>
              <option value="100" data-i18n="stock.rows_per_page.100">100 par page</option>
              <option value="all" data-i18n="stock.rows_per_page.all">Tous</option>
            </select>
            <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                    data-i18n-attr="title:stock.reset_filters" title="Réinitialiser les filtres">
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
                  <th onclick="sortData('ARTICLE_NOM')" style="cursor:pointer; width:260px;">
                    <span data-i18n="stock.table.article">ARTICLE</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th onclick="sortData('ENTREE')" style="cursor:pointer; width:110px;">
                    <span data-i18n="stock.table.entree">ENTRÉE</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th onclick="sortData('SORTIE')" style="cursor:pointer; width:110px;">
                    <span data-i18n="stock.table.sortie">SORTIE</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th onclick="sortData('DISPONIBLE')" style="cursor:pointer; width:120px;">
                    <span data-i18n="stock.table.disponible">DISPONIBLE</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th style="width:120px;" data-i18n="stock.table.seuil">SEUIL D'ALERTE</th>
                  <th onclick="sortData('STATUT')" style="cursor:pointer; width:150px;">
                    <span data-i18n="stock.table.statut">STATUT</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th style="width:150px;" data-i18n="stock.table.actions">ACTIONS</th>
                </tr>
                </thead>
                <tbody id="stockTableBody">
                <tr>
                  <td colspan="7" style="text-align:center;padding:40px;">
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
        <h3 id="modalTitle">
          <i class="fas fa-exchange-alt"></i>
          <span data-i18n="stock.adjust.title">Ajuster le stock</span>
        </h3>
        <span class="close" onclick="closeAdjustModal()">&times;</span>
      </div>
      <div class="modal-body">
        <div class="form-group">
          <label>
            <span data-i18n="stock.adjust.article_label">Article</span>
            <span class="text-danger">*</span>
          </label>
          <select id="adjustArticle" class="form-control">
            <option value="" data-i18n="stock.msg.select_placeholder">-- Sélectionner --</option>
          </select>
          <small class="field-error" id="err-adjustArticle"></small>
        </div>
        <div class="form-group">
          <label>
            <span data-i18n="stock.adjust.emplacement_label">Emplacement</span>
            <span class="text-danger">*</span>
          </label>
          <select id="adjustEmplacement" class="form-control">
            <option value="" data-i18n="stock.msg.select_placeholder">-- Sélectionner --</option>
          </select>
          <small class="field-error" id="err-adjustEmplacement"></small>
        </div>
        <div class="form-group">
          <label>
            <span data-i18n="stock.adjust.type_label">Type de mouvement</span>
            <span class="text-danger">*</span>
          </label>
          <select id="adjustType" class="form-control">
            <option value="ENTREE" data-i18n="stock.adjust.type.entree">Entrée</option>
            <option value="SORTIE" data-i18n="stock.adjust.type.sortie">Sortie</option>
          </select>
        </div>
        <div class="form-group">
          <label>
            <span data-i18n="stock.adjust.quantite_label">Quantité</span>
            <span class="text-danger">*</span>
          </label>
          <input type="number" id="adjustQuantite" class="form-control" step="0.01" min="0.01" />
          <small class="field-error" id="err-adjustQuantite"></small>
        </div>
        <div class="form-group">
          <label data-i18n="stock.adjust.motif_label">Motif</label>
          <input type="text" id="adjustMotif" class="form-control"
                 data-i18n-attr="placeholder:stock.adjust.motif_placeholder"
                 placeholder="Ex: Réapprovisionnement, cassé, etc." />
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-primary" id="btnSaveAdjust" onclick="saveAdjust(event)" type="button">
          <i class="fas fa-save"></i>
          <span data-i18n="stock.adjust.save">Enregistrer</span>
        </button>
        <button class="btn btn-danger" onclick="closeAdjustModal()" type="button">
          <i class="fas fa-times"></i>
          <span data-i18n="stock.adjust.cancel">Annuler</span>
        </button>
      </div>
    </div>
  </div>

  <!-- MODALE HISTORIQUE -->
  <div id="historyModal" class="modal">
    <div class="modal-content" style="max-width:800px;">
      <div class="modal-header">
        <h3>
          <i class="fas fa-history"></i>
          <span data-i18n="stock.history.title">Historique des mouvements</span>
        </h3>
        <span class="close" onclick="closeHistoryModal()">&times;</span>
      </div>
      <div class="modal-body">
        <div style="overflow-x:auto;">
          <table class="dash-table" style="width:100%; border-collapse:collapse;">
            <thead>
            <tr style="background-color:#f8f9fa; text-align:left;">
              <th data-i18n="stock.history.date">Date</th>
              <th data-i18n="stock.history.type">Type</th>
              <th data-i18n="stock.history.quantite">Quantité</th>
              <th data-i18n="stock.history.avant">Avant</th>
              <th data-i18n="stock.history.apres">Après</th>
              <th style="width:150px;" data-i18n="stock.history.statut_validation">Statut de Validation</th>
              <th data-i18n="stock.history.reference">Référence</th>
            </tr>
            </thead>
            <tbody id="historyTableBody">
            <tr>
              <td colspan="7" style="text-align:center;padding:20px;"
                  data-i18n="stock.msg.history_loading">Chargement...</td>
            </tr>
            </tbody>
          </table>
        </div>
        <div class="pagination-wrapper" id="historyPagination"></div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" onclick="closeHistoryModal()" type="button"
                data-i18n="stock.history.close">Fermer</button>
      </div>
    </div>
  </div>

  <div id="spinnerOverlays" aria-hidden="true" style="display:none;visibility:hidden;">
    <div style="display:flex;flex-direction:column;align-items:center;gap:12px;">
      <div class="spinner"></div>
      <div id="spinnerMessage" style="color:#fff;font-size:14px;font-weight:500;text-align:center;
            background:rgba(0,0,0,0.35);padding:6px 14px;border-radius:20px;
            display:none;max-width:280px;">
      </div>
    </div>
  </div>

  <!-- SCRIPTS -->
  <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/jspdf.umd.min.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/jspdf.plugin.autotable.min.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/xlsx.full.min.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/vfs_fonts.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
  <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
  <div id="toastContainer"></div>
</form>
</body>
</html>
