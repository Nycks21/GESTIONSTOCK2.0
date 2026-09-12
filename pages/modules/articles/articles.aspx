<%@ Page Language="C#" AutoEventWireup="true" CodeFile="articles.aspx.cs" Inherits="articles" %>

  <!DOCTYPE html>
  <html lang="fr">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Articles — Gestion de Stock</title>
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

          <%= AuthHelper.RenderControlSidebarHTML() %>

            <div class="content-wrapper" id="contentWrapper">
              <div class="content-header">
                <div class="container-fluid">
                  <div class="row">
                    <div class="col-lg-6">
                      <h1><i class="fas fa-boxes" style="color:#007bff;"></i> Articles</h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float:right;">
                        <li class="breadcrumb-item">Stock</li>
                        <li class="breadcrumb-item active">Articles</li>
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
                        <span class="stat-label">Articles actifs</span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-normal">
                      <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statNormal">0</span>
                        <span class="stat-label">Stock normal</span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-alerte">
                      <div class="stat-icon"><i class="fas fa-exclamation-triangle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statAlerte">0</span>
                        <span class="stat-label">En alerte</span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-rupture">
                      <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statRupture">0</span>
                        <span class="stat-label">En rupture</span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title"><i class="fas fa-boxes"></i> Liste des articles</span>
                    <div class="action-buttons">
                      <button class="btn btn-success btn-sm" onclick="openAddArticleModal(event)" type="button">
                        <i class="fas fa-plus"></i> Ajouter
                      </button>
                      <button class="btn btn-outline-secondary btn-sm" onclick="openImportModal(event)" type="button"
                        disabled>
                        <i class="fas fa-file-import"></i> Importer
                      </button>
                      <button class="btn btn-primary btn-sm" onclick="exportArticlesPDF()" type="button">
                        <i class="fas fa-file-pdf"></i> PDF
                      </button>
                      <button class="btn btn-outline-success btn-sm" onclick="exportArticlesToExcelOnly()"
                        type="button">
                        <i class="fas fa-file-excel"></i> Excel
                      </button>
                    </div>
                  </div>

                  <!-- Barre de filtres persistante -->
                  <div class="dash-card-toolbar">
                    <div class="toolbar-search">
                      <i class="fas fa-search"></i>
                      <input type="text" id="search-filter" class="form-control"
                        placeholder="Rechercher par code, nom ou description…" autocomplete="off" />
                    </div>
                    <select id="category-filter" class="form-control toolbar-select">
                      <option value="">Toutes catégories</option>
                    </select>
                    <select id="status-filter" class="form-control toolbar-select">
                      <option value="">Tous statuts</option>
                      <option value="normal">Normal</option>
                      <option value="alerte">Alerte</option>
                      <option value="rupture">Rupture</option>
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
                    <span class="toolbar-counter" id="resultsCounter">0 article(s)</span>
                  </div>

                  <div class="dash-card-body">
                    <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                      <table class="dash-table"
                        style="table-layout:fixed; width:1300px; min-width:100%; border-collapse:collapse;">
                        <thead>
                          <tr style="background-color:#f8f9fa; text-align:left;">
                            <th onclick="sortData('CODE')" style="cursor:pointer; width:100px;">CODE <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('NOM')" style="cursor:pointer; width:180px;">NOM <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('CATEGORIE_NOM')" style="cursor:pointer; width:130px;">CATÉGORIE <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('FOURNISSEUR_NOM')" style="cursor:pointer; width:130px;">FOURNISSEUR
                              <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('UNITE_SYMBOLE')" style="cursor:pointer; width:80px;">UNITÉ <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('STOCK_TOTAL')" style="cursor:pointer; width:100px;">STOCK DISPONIBLE
                              <i class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('SEUIL_MIN')" style="cursor:pointer; width:90px;">SEUIL MIN <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('SEUIL_ALERTE')" style="cursor:pointer; width:90px;">SEUIL ALERTE <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('STATUT_STOCK')" style="cursor:pointer; width:100px;">STATUT <i
                                class="fas fa-sort ml-1"></i></th>
                            <th style="width:130px;">ACTIONS</th>
                          </tr>
                        </thead>
                        <tbody id="articlesTableBody">
                          <tr>
                            <td colspan="9" style="text-align:center;padding:40px;"><i class="fas fa-spinner fa-spin"
                                style="font-size:24px;color:#ccc;"></i></td>
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
            <h3 id="modalTitle"><i class="fas fa-box"></i> Ajouter un article</h3>
            <span class="close" onclick="closeArticleModal()">&times;</span>
          </div>
          <div class="modal-body">
            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label>Code <small class="text-muted">(généré automatiquement)</small></label>
                  <input type="text" id="articleCode" class="form-control" placeholder="ART-XXX-00001" readonly />
                  <small class="field-error" id="err-articleCode"></small>
                </div>
              </div>
              <div class="col-md-6">
                <div class="form-group">
                  <label>Nom <span class="text-danger">*</span></label>
                  <input type="text" id="articleNom" class="form-control" placeholder="Nom de l'article" required />
                  <small class="field-error" id="err-articleNom"></small>
                </div>
              </div>
            </div>
            <div class="form-group">
              <label>Description</label>
              <textarea id="articleDescription" class="form-control" rows="2" placeholder="Description..."
                style="resize: vertical;"></textarea>
            </div>
            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label>Catégorie</label>
                  <select id="articleCategorie" class="form-control">
                    <option value="">-- Sélectionner Catégorie --</option>
                  </select>
                </div>
              </div>
              <div class="col-md-6">
                <div class="form-group">
                  <label>Fournisseur</label>
                  <select id="articleFournisseur" class="form-control">
                    <option value="">-- Aucun --</option>
                  </select>
                </div>
              </div>
            </div>
            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label>Unité de mesure <span class="text-danger">*</span></label>
                  <select id="articleUnite" class="form-control" required>
                    <option value="">-- Sélectionner Unité --</option>
                  </select>
                  <small class="field-error" id="err-articleUnite"></small>
                </div>
              </div>
              <div class="col-md-6">
                <div class="form-group">
                  <label>Emplacement par défaut <span class="text-danger">*</span></label>
                  <select id="articleEmplacement" class="form-control" required>
                    <option value="">-- Sélectionner Emplacement --</option>
                  </select>
                  <small class="field-error" id="err-articleEmplacement"></small>
                </div>
              </div>
            </div>
            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label>Seuil minimum</label>
                  <input type="number" id="articleSeuilMin" class="form-control" step="0.01" value="0" />
                </div>
              </div>
              <div class="col-md-6">
                <div class="form-group">
                  <label>Seuil d'alerte</label>
                  <input type="number" id="articleSeuilAlerte" class="form-control" step="0.01" value="0" />
                </div>
              </div>
            </div>
            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label>Actif</label>
                  <select id="articleActif" class="form-control">
                    <option value="1">Oui</option>
                    <option value="0">Non</option>
                  </select>
                </div>
              </div>
              <div class="col-md-6">
                <div class="form-group">
                  <label>Article de service</label>
                  <select id="articleEstService" class="form-control">
                    <option value="0">Non</option>
                    <option value="1">Oui</option>
                  </select>
                </div>
              </div>
            </div>
            <!-- champs optionnels supplémentaires (poids, volume, etc.) peuvent être ajoutés ici -->
          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" id="btnSaveArticle" onclick="saveArticle(event)" type="button">
              <i class="fas fa-save"></i> Enregistrer
            </button>
            <button class="btn btn-danger" onclick="closeArticleModal()" type="button">
              <i class="fas fa-times"></i> Annuler
            </button>
          </div>
        </div>
      </div>

      <!-- MODAL IMPORTATION EXCEL -->
      <div id="modalImport" class="modal">
        <div class="modal-content" style="max-width:500px;">
          <div class="modal-header">
            <h3><i class="fas fa-file-import"></i> Importer des articles</h3>
            <span class="close" onclick="closeImportModal()">&times;</span>
          </div>
          <div class="modal-body">
            <p class="text-muted">Sélectionnez un fichier Excel (.xlsx) contenant les colonnes CODE, NOM, CATEGORIE,
              UNITE, SEUIL_ALERTE, STOCK_INITIAL.</p>
            <div class="form-group">
              <label class="btn btn-outline-primary btn-block" for="excelFile">
                <i class="fas fa-upload"></i> Choisir un fichier
              </label>
              <input type="file" id="excelFile" accept=".xlsx,.xls" style="display:none;" onchange="updateFileName()" />
              <input type="text" id="fileNameDisplay" class="form-control text-center mt-2" readonly
                placeholder="Aucun fichier sélectionné" />
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" id="btnLaunchImport" onclick="launchImport()" type="button" disabled>
              <i class="fas fa-check"></i> Lancer l'import
            </button>
            <button class="btn btn-danger" onclick="closeImportModal()" type="button">
              <i class="fas fa-times"></i> Annuler
            </button>
          </div>
        </div>
      </div>

      <!-- MODAL AJUSTEMENT STOCK -->
      <div id="adjustModal" class="modal">
        <div class="modal-content" style="max-width:500px;">
          <div class="modal-header">
            <h3><i class="fas fa-exchange-alt"></i> Ajuster le stock</h3>
            <span class="close" onclick="closeAdjustModal()">&times;</span>
          </div>
          <div class="modal-body">
            <input type="hidden" id="adjustArticle" />
            <input type="hidden" id="adjustEmplacement" />
            <div class="form-group">
              <label>Type de mouvement <span class="text-danger">*</span></label>
              <select id="adjustType" class="form-control">
                <option value="ENTREE">Entrée</option>
                <option value="SORTIE">Sortie</option>
              </select>
            </div>
            <div class="form-group">
              <label>Quantité <span class="text-danger">*</span></label>
              <input type="number" id="adjustQuantite" class="form-control" step="0.01" min="0.01" placeholder="0.00" />
              <small class="field-error" id="err-adjustQuantite"></small>
            </div>
            <div class="form-group">
              <label>Motif</label>
              <input type="text" id="adjustMotif" class="form-control" placeholder="Motif de l'ajustement" />
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" onclick="saveAdjust(event)" type="button"><i class="fas fa-save"></i>
              Valider</button>
            <button class="btn btn-danger" onclick="closeAdjustModal()" type="button"><i class="fas fa-times"></i>
              Annuler</button>
          </div>
        </div>
      </div>

      <!-- MODAL HISTORIQUE -->
      <div id="historyModal" class="modal">
        <div class="modal-content" style="max-width:800px;">
          <div class="modal-header">
            <h3><i class="fas fa-history"></i> Historique des mouvements</h3>
            <span class="close" onclick="closeHistoryModal()">&times;</span>
          </div>
          <div class="modal-body">
            <div style="overflow-x:auto;">
              <table class="dash-table" style="width:100%; text-align: left;">
                <thead>
                  <tr>
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
                    <td colspan="7" style="text-align:center;">Aucun mouvement</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div class="pagination-wrapper" id="historyPagination"></div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-danger" onclick="closeHistoryModal()" type="button"><i class="fas fa-times"></i>
              Fermer</button>
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
