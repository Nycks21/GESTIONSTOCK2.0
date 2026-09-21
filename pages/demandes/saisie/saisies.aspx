<%@ Page Language="C#" AutoEventWireup="true" CodeFile="saisies.cs" Inherits="saisies" %>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title data-i18n="saisies.pageTitle">Mes demandes de sortie — Gestion de Stock</title>
  <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
<form id="saisieForm" runat="server">
  <asp:HiddenField ID="hfUserRole" runat="server" />
  <asp:HiddenField ID="hfUserNom"  runat="server" />

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
                <i class="fas fa-pencil-alt" style="color:#17a2b8;"></i>
                <span data-i18n="saisies.title">Saisie de demande</span>
              </h1>
            </div>
            <div class="col-lg-6">
              <ol class="breadcrumb" style="float:right;">
                <li class="breadcrumb-item" data-i18n="saisies.breadcrumb.stock">Stock</li>
                <li class="breadcrumb-item active" data-i18n="saisies.breadcrumb.saisie">Saisie</li>
              </ol>
            </div>
          </div>
        </div>
      </div>

      <section class="content">
        <!-- CARTES DE SYNTHÈSE -->
        <div class="row sorties-stats" id="saisieStats">
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-total">
              <div class="stat-icon"><i class="fas fa-clipboard-list"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statTotal">0</span>
                <span class="stat-label" data-i18n="saisies.stat.total">Total demandes</span>
              </div>
            </div>
          </div>
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-normal">
              <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statValide">0</span>
                <span class="stat-label" data-i18n="saisies.stat.valide">Validées</span>
              </div>
            </div>
          </div>
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-alerte">
              <div class="stat-icon"><i class="fas fa-pencil-alt"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statBrouillon">0</span>
                <span class="stat-label" data-i18n="saisies.stat.brouillon">En cours</span>
              </div>
            </div>
          </div>
          <div class="col-lg-3 col-6">
            <div class="stat-card stat-card-rupture">
              <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
              <div class="stat-body">
                <span class="stat-value" id="statAnnule">0</span>
                <span class="stat-label" data-i18n="saisies.stat.annule">Annulées</span>
              </div>
            </div>
          </div>
        </div>

        <div class="dash-card">
          <div class="dash-card-head">
            <span class="dash-card-title">
              <i class="fas fa-list"></i>
              <span data-i18n="saisies.list_title">Mes demandes</span>
            </span>
            <div class="action-buttons">
              <button class="btn btn-success btn-sm" onclick="openModalSaisie(event)" type="button">
                <i class="fas fa-plus"></i>
                <span data-i18n="saisies.btn.add">Nouvelle demande</span>
              </button>
            </div>
          </div>

          <!-- FILTRES -->
          <div class="dash-card-toolbar">
            <div class="toolbar-search">
              <input type="text" id="search-filter" class="form-control"
                     data-i18n-attr="placeholder:saisies.search_placeholder"
                     placeholder="Rechercher par numéro, destination…" autocomplete="off" />
            </div>
            <select id="statut-filter" class="form-control toolbar-select">
              <option value=""          data-i18n="saisies.filter.all_statuts">Tous statuts</option>
              <option value="BROUILLON" data-i18n="saisies.status.brouillon">En cours</option>
              <option value="VALIDE"    data-i18n="saisies.status.valide">Validé</option>
              <option value="ANNULE"    data-i18n="saisies.status.annule">Annulé</option>
            </select>
            <select id="rows-per-page-top" class="form-control toolbar-select">
              <option value="10"  data-i18n="saisies.rows_per_page.10">10 par page</option>
              <option value="25"  data-i18n="saisies.rows_per_page.25">25 par page</option>
              <option value="50"  data-i18n="saisies.rows_per_page.50">50 par page</option>
              <option value="100" data-i18n="saisies.rows_per_page.100">100 par page</option>
              <option value="all" data-i18n="saisies.rows_per_page.all">Tous</option>
            </select>
            <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                    data-i18n-attr="title:saisies.reset_filters" title="Réinitialiser">
              <i class="fas fa-undo"></i>
            </button>
            <span class="toolbar-counter" id="resultsCounter">0 demande(s)</span>
          </div>

          <div class="dash-card-body">
            <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
              <table class="dash-table"
                     style="table-layout:fixed; width:1200px; min-width:100%; border-collapse:collapse;">
                <thead>
                <tr style="background-color:#f8f9fa; text-align:left;">
                  <th onclick="sortData('NUMERO')" style="cursor:pointer; width:120px;">
                    <span data-i18n="saisies.table.numero">N°</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th onclick="sortData('DATE_SORTIE')" style="cursor:pointer; width:130px;">
                    <span data-i18n="saisies.table.date">Date</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th onclick="sortData('ARTICLES')" style="cursor:pointer; width:160px;"
                      data-i18n="saisies.table.articles">Articles</th>
                  <th style="width:110px; text-align:right;"
                      data-i18n="saisies.table.qte_demandee">Qté demandée</th>
                  <th onclick="sortData('DESTINATION')" style="cursor:pointer; width:140px;">
                    <span data-i18n="saisies.table.destination">Destination</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th onclick="sortData('STATUT')" style="cursor:pointer; width:100px;">
                    <span data-i18n="saisies.table.statut">Statut</span> <i class="fas fa-sort ml-1"></i>
                  </th>
                  <th style="width:110px;" data-i18n="saisies.table.actions">Actions</th>
                </tr>
                </thead>
                <tbody id="saisieTableBody">
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

  <!-- MODAL : Nouvelle demande de sortie -->
  <div id="saisieModal" class="modal">
    <div class="modal-content modal-article" style="max-width:900px;">
      <div class="modal-header">
        <h3 id="modalTitle">
          <i class="fas fa-truck"></i>
          <span data-i18n="saisies.modal.add_title">Nouvelle demande de sortie</span>
        </h3>
        <span class="close" onclick="closeModalSaisie()">&times;</span>
      </div>
      <div class="modal-body">
        <!-- Informations générales -->
        <div class="row">
          <div class="col-md-4">
            <div class="form-group">
              <label>
                <span data-i18n="saisies.modal.numero_label">Numéro</span>
                <small class="text-muted" data-i18n="saisies.modal.numero_hint">(généré automatiquement)</small>
              </label>
              <input type="text" id="sortieNumero" class="form-control"
                     data-i18n-attr="placeholder:saisies.modal.numero_placeholder"
                     placeholder="SOR-XXX-00001" readonly />
              <small class="field-error" id="err-sortieNumero"></small>
            </div>
          </div>
          <div class="col-md-4">
            <div class="form-group">
              <label>
                <span data-i18n="saisies.modal.date_label">Date</span>
                <span class="text-danger">*</span>
              </label>
              <input type="datetime-local" id="sortieDate" class="form-control" required>
              <small class="field-error" id="err-sortieDate"></small>
            </div>
          </div>
          <div class="col-md-4">
            <div class="form-group">
              <label>
                <span data-i18n="saisies.modal.destination_label">Destination</span>
                <span class="text-danger">*</span>
              </label>
              <input type="text" id="sortieDestination" class="form-control"
                     data-i18n-attr="placeholder:saisies.modal.destination_placeholder"
                     placeholder="Service, atelier…" required>
              <small class="field-error" id="err-sortieDestination"></small>
            </div>
          </div>
        </div>
        <div class="row">
          <div class="col-md-4">
            <div class="form-group">
              <label for="sortieNom">
                <span data-i18n="saisies.modal.beneficiaire_label">Bénéficiaire</span>
                <i class="fas fa-lock" style="color:#6c757d;font-size:11px;margin-left:4px;"
                   data-i18n-attr="title:saisies.modal.beneficiaire_hint"
                   title="Rempli automatiquement avec votre nom"></i>
              </label>
              <div style="position:relative;">
                <input type="text" id="sortieNom" class="form-control" readonly
                       data-i18n-attr="placeholder:saisies.modal.beneficiaire_placeholder"
                       placeholder="Rempli automatiquement"
                       style="background-color:#e9ecef;cursor:not-allowed;font-weight:600;
                              color:#495057;padding-right:38px;" />
                <i class="fas fa-user-check" style="position:absolute;right:12px;top:50%;
                   transform:translateY(-50%);color:#28a745;font-size:14px;pointer-events:none;"
                   title="Utilisateur connecté"></i>
              </div>
              <small style="display:block;margin-top:6px;font-size:12px;color:#17a2b8;line-height:1.4;">
                <i class="fas fa-info-circle"></i>
                <span data-i18n="saisies.modal.beneficiaire_info">
                  Rempli automatiquement avec <strong>votre nom</strong>.
                  Ce nom sera enregistré comme bénéficiaire de la demande.
                </span>
              </small>
            </div>
          </div>
          <div class="col-md-4">
            <div class="form-group">
              <label data-i18n="saisies.modal.fonction_label">Fonction</label>
              <input type="text" id="sortieFonction" class="form-control"
                     data-i18n-attr="placeholder:saisies.modal.fonction_placeholder"
                     placeholder="Fonction" />
            </div>
          </div>
          <div class="col-md-4">
            <div class="form-group">
              <label data-i18n="saisies.modal.notes_label">Notes</label>
              <input type="text" id="sortieNotes" class="form-control"
                     data-i18n-attr="placeholder:saisies.modal.notes_placeholder"
                     placeholder="Remarques…" />
            </div>
          </div>
        </div>

        <hr class="mb-1" />
        <h5>
          <i class="fas fa-list mb-1"></i>
          <span data-i18n="saisies.modal.lignes_title">Articles demandés</span>
        </h5>
        <div class="table-responsive lignes-table-container"
             style="max-height:300px; overflow-y:auto; border:1px solid #ddd; border-radius:6px;">
          <table class="table table-bordered table-sm" id="lignesTable" style="margin-bottom:0;">
            <thead style="background:#f1f1f1; position:sticky; top:0; z-index:1;">
            <tr>
              <th style="width:40px;">#</th>
              <th style="min-width:180px;" data-i18n="saisies.modal.lignes_article">Article</th>
              <th style="width:120px; text-align:right;"
                  data-i18n="saisies.modal.lignes_qte_d">Qté Demandée</th>
              <th style="min-width:300px;" data-i18n="saisies.modal.lignes_obs">Observations</th>
              <th style="width:50px;">
                <button type="button" class="btn btn-sm btn-success" onclick="ajouterLigne()">
                  <i class="fas fa-plus"></i>
                </button>
              </th>
            </tr>
            </thead>
            <tbody id="lignesBody"></tbody>
          </table>
        </div>
        <small class="text-muted">
          <span data-i18n="saisies.modal.lignes_hint_prefix">Cliquez sur</span>
          <i class="fas fa-plus"></i>
          <span data-i18n="saisies.modal.lignes_hint">pour ajouter une ligne.</span>
        </small>
      </div>
      <div class="modal-footer">
        <button class="btn btn-primary" id="btnSaveSaisie" onclick="saveSaisie(event)" type="button">
          <i class="fas fa-save"></i>
          <span data-i18n="saisies.modal.btn.send">Envoyer la demande</span>
        </button>
        <button class="btn btn-secondary" id="btnResetSaisie" onclick="resetFormSaisie()" type="button">
          <i class="fas fa-undo"></i>
          <span data-i18n="saisies.modal.btn.reset">Réinitialiser</span>
        </button>
        <button type="button" class="btn-modern btn-danger" onclick="closeModal('saisieModal')"
                id="btnAnnulerDemande" data-keep-active="true">
          <i class="fas fa-times"></i>
          <span data-i18n="saisies.modal.btn.cancel">Annuler</span>
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
  <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/article-picker.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
  <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
  <div id="toastContainer"></div>
</form>
</body>
</html>
