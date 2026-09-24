﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="articles.aspx.cs" Inherits="articles" UICulture="Auto"
  Culture="Auto" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>
      <%= LocalizationHelper.GetString("articles.title") %> — <%= LocalizationHelper.GetString("app.name") %>
    </title>
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
                      <button class="btn btn-outline-success btn-sm" onclick="exportArticlesToExcelOnly()"
                        type="button">
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
                  <label>
                    <span data-i18n="articles.modal.categorie_label"></span>
                    <span class="text-danger">*</span>
                  </label>
                  <select id="articleCategorie" class="form-control" required>
                    <option value="" data-i18n="articles.modal.categorie_select"></option>
                  </select>
                  <small class="field-error" id="err-articleCategorie"></small>
                </div>
              </div>
              <div class="col-md-6">
                <div class="form-group">
                  <label>
                    <span data-i18n="articles.modal.fournisseur_label"></span>
                    <span class="text-danger">*</span>
                  </label>
                  <select id="articleFournisseur" class="form-control" required>
                    <option value="" data-i18n="articles.modal.fournisseur_none"></option>
                  </select>
                  <small class="field-error" id="err-articleFournisseur"></small>
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
                  <label>
                    <span data-i18n="articles.modal.seuil_label"></span>
                    <span class="text-danger">*</span>
                  </label>
                  <input type="number" id="articleSeuilAlerte" class="form-control" step="0.01" min="0" required />
                  <small class="field-error" id="err-articleSeuilAlerte"></small>
                </div>
              </div>
            </div>

            <!-- ═══ PÉRISSABLE + DATE DE PÉREMPTION (conditionnelle) ═══ -->
            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="articles.modal.perissable_label"></label>
                  <select id="articleEstPerissable" class="form-control" onchange="toggleDatePeremption()">
                    <option value="0" data-i18n="button.no"></option>
                    <option value="1" data-i18n="button.yes"></option>
                  </select>
                </div>
              </div>
              <div class="col-md-6" id="articleDatePeremptionGroup" style="display:none;">
                <div class="form-group">
                  <label>
                    <span data-i18n="articles.modal.date_peremption_label"></span>
                    <span class="text-danger">*</span>
                  </label>
                  <input type="date" id="articleDatePeremption" class="form-control" />
                  <small class="field-error" id="err-articleDatePeremption"></small>
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

      <!-- MODAL IMPORTATION EXCEL — WIZARD PLEIN ÉCRAN -->
      <div id="modalImport" class="modal">
        <div class="modal-content modal-import">
          <div class="modal-header">
            <h3>
              <i class="fas fa-file-import"></i>
              <span data-i18n="articles.import.title"></span>
            </h3>
            <span class="close" onclick="closeImportModal()">&times;</span>
          </div>

          <div class="modal-body">

            <!-- WIZARD -->
            <div class="ai-wizard">
              <div class="ai-step" id="ai-step-1">
                <div class="ai-step-circle">1</div>
                <div class="ai-step-label" data-i18n="articles.import.step.file"></div>
              </div>
              <div class="ai-step" id="ai-step-2">
                <div class="ai-step-circle">2</div>
                <div class="ai-step-label" data-i18n="articles.import.step.mapping"></div>
              </div>
              <div class="ai-step" id="ai-step-3">
                <div class="ai-step-circle">3</div>
                <div class="ai-step-label" data-i18n="articles.import.step.preview"></div>
              </div>
              <div class="ai-step" id="ai-step-4">
                <div class="ai-step-circle">4</div>
                <div class="ai-step-label" data-i18n="articles.import.step.result"></div>
              </div>
            </div>

            <!-- ÉTAPE 1 : FICHIER -->
            <div id="ai-panel-1" class="ai-panel">
              <div class="ai-dropzone" id="ai-dropzone" onclick="document.getElementById('ai-file-input').click()">
                <i class="fas fa-cloud-upload-alt"></i>
                <p style="font-size:16px;font-weight:600;" data-i18n="articles.import.dropzone.title"></p>
                <p style="color:#6c757d;font-size:13px;" data-i18n="articles.import.dropzone.hint"></p>
                <button type="button" class="btn btn-success btn-sm" style="pointer-events:none;">
                  <i class="fas fa-file-excel"></i> <span data-i18n="articles.import.dropzone.browse"></span>
                </button>
                <input type="file" id="ai-file-input" accept=".xlsx,.xls" style="display:none;" />
              </div>

              <div class="ai-file-info">
                <i class="fas fa-file-excel"></i>
                <div>
                  <div id="ai-file-name" class="ai-file-name" data-i18n="articles.import.file.none"></div>
                  <div id="ai-file-status" class="ai-file-status"></div>
                </div>
              </div>

              <div id="ai-columns-preview" class="ai-cols-preview"></div>

              <div style="margin-top:16px;">
                <button type="button" class="btn btn-outline-secondary btn-sm" onclick="downloadArticlesTemplate()">
                  <i class="fas fa-download"></i> <span data-i18n="articles.import.template"></span>
                </button>
              </div>
            </div>

            <!-- ÉTAPE 2 : MAPPAGE -->
            <div id="ai-panel-2" class="ai-panel" style="display:none;">
              <p class="ai-help">
                <i class="fas fa-info-circle"></i>
                <span data-i18n="articles.import.mapping.help"></span>
              </p>
              <div class="ai-scroll-table">
                <table class="ai-mapping-table">
                  <thead>
                    <tr>
                      <th style="width:220px;" data-i18n="articles.import.mapping.field"></th>
                      <th data-i18n="articles.import.mapping.column"></th>
                      <th style="width:220px;" data-i18n="articles.import.mapping.preview"></th>
                    </tr>
                  </thead>
                  <tbody id="ai-mapping-body"></tbody>
                </table>
              </div>
            </div>

            <!-- ÉTAPE 3 : APERÇU -->
            <div id="ai-panel-3" class="ai-panel" style="display:none;">
              <div class="ai-stats-bar" id="ai-preview-stats"></div>
              <div id="ai-preview-table"></div>
            </div>

            <!-- ÉTAPE 4 : RÉSULTAT -->
            <div id="ai-panel-4" class="ai-panel" style="display:none;">
              <div id="ai-result-body"></div>
            </div>

          </div>

          <div class="modal-footer">
            <button type="button" class="btn btn-outline-secondary" id="ai-btn-prev" onclick="aiPrevStep()"
              style="display:none;">
              <i class="fas fa-arrow-left"></i> <span data-i18n="articles.import.btn.prev"></span>
            </button>
            <div style="flex:1;"></div>

            <button type="button" class="btn btn-primary" id="ai-btn-next" onclick="aiNextStep()" style="display:none;">
              <span data-i18n="articles.import.btn.next"></span> <i class="fas fa-arrow-right"></i>
            </button>

            <button type="button" class="btn btn-success" id="ai-btn-launch" onclick="aiLaunchImport()"
              style="display:none;">
              <i class="fas fa-database"></i> <span data-i18n="articles.import.btn.launch"></span>
            </button>

            <button type="button" class="btn btn-danger" id="ai-btn-close" onclick="closeImportModal()">
              <i class="fas fa-times"></i> <span data-i18n="articles.import.btn.close"></span>
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
      <script src="../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
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
      <script src="js/import.js?v=<%=AuthHelper.Version %>"></script>
      <div id="toastContainer"></div>
    </form>
  </body>

  </html>
