﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="sorties.cs" Inherits="sorties" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title data-i18n="sorties.title">Bons de sortie — Gestion de Stock</title>
  <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%= AuthHelper.Version %>"
      data-user-role="<%= AuthHelper.GetUserRole(Context) %>">
<form id="sortieForm" runat="server">
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
                <i class="fas fa-truck" style="color:#dc3545;"></i>
                <span data-i18n="sorties.title">Bons de sortie</span>
              </h1>
            </div>
            <div class="col-lg-6">
              <ol class="breadcrumb" style="float:right;">
                <li class="breadcrumb-item" data-i18n="sorties.breadcrumb.stock">Stock</li>
                <li class="breadcrumb-item active" data-i18n="sorties.breadcrumb.sorties">Sorties</li>
              </ol>
            </div>
          </div>
        </div>
      </div>

      <section class="content" id="section-sorties">
        <!-- STATS -->
        <div class="row sorties-stats" id="sortiesStats">
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-total">
              <div class="stat-icon"><i class="fas fa-clipboard-list"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statTotal">0</span>
                <span class="stat-label" data-i18n="sorties.stat.total">Total bons</span>
              </div>
            </div>
          </div>
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-normal">
              <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statValide">0</span>
                <span class="stat-label" data-i18n="sorties.stat.valide">Validés</span>
              </div>
            </div>
          </div>
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-alerte">
              <div class="stat-icon"><i class="fas fa-pencil-alt"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statBrouillon">0</span>
                <span class="stat-label" data-i18n="sorties.stat.brouillon">QR vide et En cours</span>
              </div>
            </div>
          </div>
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-rupture">
              <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statAnnule">0</span>
                <span class="stat-label" data-i18n="sorties.stat.annule">Annulés</span>
              </div>
            </div>
          </div>
        </div>

        <div class="dash-card">
          <div class="dash-card-head">
            <span class="dash-card-title">
              <i class="fas fa-truck"></i>
              <span data-i18n="sorties.list_title">Liste des bons de sortie</span>
            </span>
            <div class="action-buttons">
              <button class="btn-modern btn-success" onclick="openAddSortieModal(event)" type="button">
                <i class="fas fa-plus"></i>
                <span data-i18n="sorties.btn.add">Nouveau bon</span>
              </button>
              <button class="btn-modern btn-outline-success" onclick="openImportModal(event)" type="button" disabled>
                <i class="fas fa-file-import"></i>
                <span data-i18n="sorties.btn.import">Importer</span>
              </button>
              <button class="btn-modern btn-primary" onclick="exportSortiesPDF()" type="button">
                <i class="fas fa-file-pdf"></i>
                <span data-i18n="sorties.btn.pdf">PDF</span>
              </button>
              <button class="btn-modern btn-outline-success" onclick="exportSortiesToExcelOnly()" type="button">
                <i class="fas fa-file-excel"></i>
                <span data-i18n="sorties.btn.excel">Excel</span>
              </button>
            </div>
          </div>

          <!-- FILTRES -->
          <div class="dash-card-toolbar">
            <div class="toolbar-search">
              <i class="fas fa-search"></i>
              <input type="text" id="search-filter" class="form-control"
                     data-i18n-attr="placeholder:sorties.search_placeholder"
                     placeholder="Rechercher par numéro, nom, destination…" autocomplete="off" />
            </div>
            <select id="statut-filter" class="form-control toolbar-select">
              <option value="" data-i18n="sorties.filter.all_statuts">Tous statuts</option>
              <option value="VIDE"      data-i18n="sorties.status.vide">QR vide</option>
              <option value="BROUILLON" data-i18n="sorties.status.brouillon">En cours</option>
              <option value="VALIDE"    data-i18n="sorties.status.valide">Validé</option>
              <option value="ANNULE"    data-i18n="sorties.status.annule">Annulé</option>
              <option value="TERMINE"   data-i18n="sorties.status.termine">Reçu</option>
            </select>
            <select id="rows-per-page-top" class="form-control toolbar-select">
              <option value="10"  data-i18n="sorties.rows_per_page.10">10 par page</option>
              <option value="25"  data-i18n="sorties.rows_per_page.25">25 par page</option>
              <option value="50"  data-i18n="sorties.rows_per_page.50">50 par page</option>
              <option value="100" data-i18n="sorties.rows_per_page.100">100 par page</option>
              <option value="all" data-i18n="sorties.rows_per_page.all">Tous</option>
            </select>
            <button class="btn-modern btn-ghost" id="btnResetFilters" onclick="resetFilters()" type="button"
                    data-i18n-attr="title:sorties.reset_filters" title="Réinitialiser les filtres">
              <i class="fas fa-undo"></i>
            </button>
            <span class="toolbar-counter" id="resultsCounter">0 bon(s)</span>
          </div>

          <div class="dash-card-body">
            <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
              <table class="dash-table"
                     style="table-layout:fixed; width:1450px; min-width:100%; border-collapse:collapse;">
                <thead>
                <tr style="background-color:#f8f9fa; text-align:left;">
                  <th onclick="sortData('NUMERO')" style="cursor:pointer; width:120px;">
                    <span data-i18n="sorties.table.numero">N°</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th onclick="sortData('DATE_SORTIE')" style="cursor:pointer; width:90px;">
                    <span data-i18n="sorties.table.date_sortie">DATE SORTIE</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th onclick="sortData('DATE_RECEPTION')" style="cursor:pointer; width:90px;">
                    <span data-i18n="sorties.table.date_reception">DATE RÉCEPTION</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th style="width:180px;" data-i18n="sorties.table.articles">ARTICLES</th>
                  <th style="width:110px; text-align:right;" data-i18n="sorties.table.qte_recue">QTÉ REÇUE</th>
                  <th onclick="sortData('NOM')" style="cursor:pointer; width:160px;">
                    <span data-i18n="sorties.table.beneficiaire">BÉNÉFICIAIRE</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th onclick="sortData('STATUT')" style="cursor:pointer; width:100px;">
                    <span data-i18n="sorties.table.statut">STATUT</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th style="width:110px;" data-i18n="sorties.table.actions">ACTIONS</th>
                </tr>
                </thead>
                <tbody id="sortiesTableBody">
                <tr>
                  <td colspan="8" style="text-align:center;padding:40px;">
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

  <!-- MODAL AJOUT / MODIFICATION / VISUALISATION -->
  <div id="sortieModal" class="modal">
    <input type="hidden" id="editingId" value="" />
    <div class="modal-content modal-article" style="max-width:900px;">
      <div class="modal-header">
        <h3 id="modalTitle">
          <i class="fas fa-truck"></i>
          <span data-i18n="sorties.modal.add_title">Nouveau bon de sortie</span>
        </h3>
        <span class="close" onclick="closeSortieModal()">&times;</span>
      </div>
      <div class="modal-body">
        <div class="row">
          <div class="col-md-4">
            <div class="form-group">
              <label>
                <span data-i18n="sorties.modal.numero_label">Numéro</span>
                <small class="text-muted" data-i18n="sorties.modal.numero_hint">(généré automatiquement)</small>
              </label>
              <input type="text" id="sortieNumero" class="form-control" placeholder="SOR-XXX-00001" readonly />
              <small class="field-error" id="err-sortieNumero"></small>
            </div>
          </div>
          <div class="col-md-4">
            <div class="form-group">
              <label>
                <span data-i18n="sorties.modal.date_label">Date</span>
                <span class="text-danger">*</span>
              </label>
              <input type="datetime-local" id="sortieDate" class="form-control" required>
              <small class="field-error" id="err-sortieDate"></small>
            </div>
          </div>
          <div class="col-md-4">
            <div class="form-group">
              <label>
                <span data-i18n="sorties.modal.destination_label">Destination</span>
                <span class="text-danger">*</span>
              </label>
              <input type="text" id="sortieDestination" class="form-control"
                     data-i18n-attr="placeholder:sorties.modal.destination_placeholder"
                     placeholder="Service, atelier…" required>
              <small class="field-error" id="err-sortieDestination"></small>
            </div>
          </div>
        </div>
        <div class="row">
          <div class="col-md-4">
            <div class="form-group">
              <label data-i18n="sorties.modal.nom_label">Bénéficiaire</label>
              <input type="text" id="sortieNom" class="form-control"
                     data-i18n-attr="placeholder:sorties.modal.nom_placeholder"
                     placeholder="Nom du bénéficiaire" />
            </div>
          </div>
          <div class="col-md-4">
            <div class="form-group">
              <label data-i18n="sorties.modal.fonction_label">Fonction</label>
              <input type="text" id="sortieFonction" class="form-control"
                     data-i18n-attr="placeholder:sorties.modal.fonction_placeholder"
                     placeholder="Fonction" />
            </div>
          </div>
          <div class="col-md-4">
            <div class="form-group">
              <label data-i18n="sorties.modal.notes_label">Notes</label>
              <input type="text" id="sortieNotes" class="form-control"
                     data-i18n-attr="placeholder:sorties.modal.notes_placeholder"
                     placeholder="Remarques…" />
            </div>
          </div>
        </div>

        <hr />
        <h5>
          <i class="fas fa-list"></i>
          <span data-i18n="sorties.modal.lignes_title">Lignes d'articles</span>
        </h5>
        <div class="table-responsive lignes-table-container"
             style="max-height:300px; overflow-y:visible; border:1px solid #ddd; border-radius:6px;">
          <table class="table table-bordered table-sm" id="lignesTable" style="margin-bottom:0;">
            <thead style="background:#f1f1f1; position:sticky; top:0; z-index:1;">
            <tr>
              <th style="width:40px;">#</th>
              <th style="min-width:180px;" data-i18n="sorties.modal.lignes_article">Article</th>
              <th style="width:120px;" data-i18n="sorties.modal.lignes_qte_d">Qté Demandée</th>
              <th style="width:120px;" data-i18n="sorties.modal.lignes_qte_r">Qté Reçue</th>
              <th style="min-width:282px;" data-i18n="sorties.modal.lignes_obs">Observations</th>
              <th style="width:50px;">
                <button type="button" class="btn-icon btn-success" onclick="ajouterLigne()"
                        title="Ajouter une ligne">
                  <i class="fas fa-plus"></i>
                </button>
              </th>
            </tr>
            </thead>
            <tbody id="lignesBody"></tbody>
          </table>
        </div>
        <small class="text-muted">
          <span data-i18n="sorties.modal.lignes_hint_prefix">Cliquez sur</span>
          <i class="fas fa-plus"></i>
          <span data-i18n="sorties.modal.lignes_hint">pour ajouter une ligne.</span>
        </small>
      </div>
      <div class="modal-footer">
        <button class="btn-modern btn-primary" id="btnSaveSortie" onclick="saveSortie(event)" type="button">
          <i class="fas fa-save"></i>
          <span data-i18n="sorties.modal.save">Enregistrer</span>
        </button>
        <button class="btn-modern btn-danger" id="btnAnnulerSortie" onclick="closeSortieModal()" type="button">
          <i class="fas fa-times"></i>
          <span data-i18n="sorties.modal.cancel">Annuler</span>
        </button>
      </div>
    </div>
  </div>

  <!-- MODAL IMPORT -->
  <div id="modalImport" class="modal">
    <div class="modal-content" style="max-width:500px;">
      <div class="modal-header">
        <h3>
          <i class="fas fa-file-import"></i>
          <span data-i18n="sorties.msg.import_title">Importer des bons</span>
        </h3>
        <span class="close" onclick="closeImportModal()">&times;</span>
      </div>
      <div class="modal-body">
        <p class="text-muted" data-i18n="sorties.msg.import_desc">Sélectionnez un fichier Excel (.xlsx) ...</p>
        <div class="form-group">
          <label class="btn-modern btn-outline-success" for="excelFile" style="width:100%;">
            <i class="fas fa-upload"></i>
            <span data-i18n="sorties.msg.import_choose">Choisir un fichier</span>
          </label>
          <input type="file" id="excelFile" accept=".xlsx,.xls" style="display:none;" onchange="updateFileName()">
          <input type="text" id="fileNameDisplay" class="form-control text-center mt-2" readonly
                 data-i18n-attr="placeholder:sorties.msg.import_none"
                 placeholder="Aucun fichier sélectionné">
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn-modern btn-primary" id="btnLaunchImport" onclick="launchImport()" type="button" disabled>
          <i class="fas fa-check"></i>
          <span data-i18n="sorties.msg.import_launch">Lancer l'import</span>
        </button>
        <button class="btn-modern btn-danger" onclick="closeImportModal()" type="button">
          <i class="fas fa-times"></i>
          <span data-i18n="sorties.modal.cancel">Annuler</span>
        </button>
      </div>
    </div>
  </div>

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
  <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/article-picker.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
  <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
  <div id="toastContainer"></div>
</form>
</body>
</html>
