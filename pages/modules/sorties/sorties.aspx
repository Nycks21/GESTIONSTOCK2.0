<%@ Page Language="C#" AutoEventWireup="true" CodeFile="sorties.cs" Inherits="sorties" %>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Bons de sortie — Gestion de Stock</title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>
<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="sortieForm" runat="server">
        <div class="wrapper">
            <%= AuthHelper.RenderTopBarHTML() %>
            <aside class="main-sidebar" id="sidebar">
                <a href="#" class="brand-link" onclick="loadDashboard()">
                    <img src="data:image/svg+xml,..." alt="Logo" class="brand-image" />
                    <span class="brand-text">Gestion de Stock</span>
                </a>
                <div class="sidebar"><%= AuthHelper.RenderMenuHTML() %></div>
            </aside>
            <%= AuthHelper.RenderControlSidebarHTML() %>

            <div class="content-wrapper" id="contentWrapper">
                <div class="content-header">
                    <div class="container-fluid">
                        <div class="row">
                            <div class="col-lg-6"><h1><i class="fas fa-truck" style="color:#dc3545;"></i> Bons de sortie</h1></div>
                            <div class="col-lg-6">
                                <ol class="breadcrumb" style="float:right;">
                                    <li class="breadcrumb-item">Stock</li>
                                    <li class="breadcrumb-item active">Sorties</li>
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
                                    <span class="stat-label">Total bons</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-6">
                            <div class="stat-card stat-card-normal">
                                <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                                <div class="stat-body">
                                    <span class="stat-value" id="statValide">0</span>
                                    <span class="stat-label">Validés</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-6">
                            <div class="stat-card stat-card-alerte">
                                <div class="stat-icon"><i class="fas fa-pencil-alt"></i></div>
                                <div class="stat-body">
                                    <span class="stat-value" id="statBrouillon">0</span>
                                    <span class="stat-label">En cours</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-3 col-6">
                            <div class="stat-card stat-card-rupture">
                                <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                                <div class="stat-body">
                                    <span class="stat-value" id="statAnnule">0</span>
                                    <span class="stat-label">Annulés</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="dash-card">
                        <div class="dash-card-head">
                            <span class="dash-card-title"><i class="fas fa-truck"></i> Liste des bons de sortie</span>
                            <div class="action-buttons">
                                <button class="btn btn-success btn-sm" onclick="openAddSortieModal(event)" type="button"><i class="fas fa-plus"></i> Nouveau bon</button>
                                <button class="btn btn-outline-secondary btn-sm" onclick="openImportModal(event)" type="button" disabled><i class="fas fa-file-import"></i> Importer</button>
                                <button class="btn btn-primary btn-sm" onclick="exportSortiesPDF()" type="button"><i class="fas fa-file-pdf"></i> PDF</button>
                                <button class="btn btn-outline-success btn-sm" onclick="exportSortiesToExcelOnly()" type="button"><i class="fas fa-file-excel"></i> Excel</button>
                            </div>
                        </div>

                        <!-- FILTRES -->
                        <div class="dash-card-toolbar">
                            <div class="toolbar-search">
                                <i class="fas fa-search"></i>
                                <input type="text" id="search-filter" class="form-control" placeholder="Rechercher par numéro, nom, destination…" autocomplete="off" />
                            </div>
                            <select id="statut-filter" class="form-control toolbar-select">
                                <option value="">Tous statuts</option>
                                <option value="VIDE">QR vide</option>
                                <option value="BROUILLON">En cours</option>
                                <option value="VALIDE">Validé</option>
                                <option value="ANNULE">Annulé</option>
                            </select>
                            <select id="rows-per-page-top" class="form-control toolbar-select">
                                <option value="10">10 par page</option>
                                <option value="25">25 par page</option>
                                <option value="50">50 par page</option>
                                <option value="100">100 par page</option>
                                <option value="all">Tous</option>
                            </select>
                            <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button" title="Réinitialiser les filtres"><i class="fas fa-undo"></i></button>
                            <span class="toolbar-counter" id="resultsCounter">0 bon(s)</span>
                        </div>

                        <div class="dash-card-body">
                            <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                                <table class="dash-table" style="table-layout:fixed; width:1300px; min-width:100%; border-collapse:collapse;">
                                    <thead>
                                        <tr style="background-color:#f8f9fa; text-align:left;">
                                            <th onclick="sortData('NUMERO')" style="cursor:pointer; width:100px;">N° <i class="fas fa-sort ml-1"></i></th>
                                            <th onclick="sortData('DATE_SORTIE')" style="cursor:pointer; width:130px;">Date <i class="fas fa-sort ml-1"></i></th>
                                            <th style="width:280px;">Articles</th>
                                            <th style="width:110px; text-align:right;">Quantité reçu</th>
                                            <th onclick="sortData('NOM')" style="cursor:pointer; width:120px;">Bénéficiaire <i class="fas fa-sort ml-1"></i></th>
                                            <th onclick="sortData('STATUT')" style="cursor:pointer; width:100px;">Statut <i class="fas fa-sort ml-1"></i></th>
                                            <th style="width:160px;">Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody id="sortiesTableBody">
                                        <tr><td colspan="8" style="text-align:center;padding:40px;"><i class="fas fa-spinner fa-spin" style="font-size:24px;color:#ccc;"></i></td></tr>
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
        <div id="sortieModal" class="modal">
            <input type="hidden" id="editingId" value="" />
            <div class="modal-content modal-article" style="max-width:900px;">
                <div class="modal-header">
                    <h3 id="modalTitle"><i class="fas fa-truck"></i> Nouveau bon de sortie</h3>
                    <span class="close" onclick="closeSortieModal()">&times;</span>
                </div>
                <div class="modal-body">
                    <div class="row">
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Numéro <span class="text-danger">*</span></label>
                                <input type="text" id="sortieNumero" class="form-control" placeholder="SORT-2025-001" required>
                                <small class="field-error" id="err-sortieNumero"></small>
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Date <span class="text-danger">*</span></label>
                                <input type="datetime-local" id="sortieDate" class="form-control" required>
                                <small class="field-error" id="err-sortieDate"></small>
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Destination <span class="text-danger">*</span></label>
                                <input type="text" id="sortieDestination" class="form-control" placeholder="Service, atelier…" required>
                                <small class="field-error" id="err-sortieDestination"></small>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Bénéficiaire</label>
                                <input type="text" id="sortieNom" class="form-control" placeholder="Nom du bénéficiaire" />
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Fonction</label>
                                <input type="text" id="sortieFonction" class="form-control" placeholder="Fonction" />
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Notes</label>
                                <input type="text" id="sortieNotes" class="form-control" placeholder="Remarques…" />
                            </div>
                        </div>
                    </div>

                    <hr />
                    <h5><i class="fas fa-list"></i> Lignes d'articles</h5>
                    <div class="table-responsive lignes-table-container" style="max-height:300px; overflow-y:visible; border:1px solid #ddd; border-radius:6px;">
                        <table class="table table-bordered table-sm" id="lignesTable" style="margin-bottom:0;">
                            <thead style="background:#f1f1f1; position:sticky; top:0; z-index:1;">
                                <tr>
                                    <th style="width:40px;">#</th>
                                    <th style="min-width:180px;">Article</th>
                                    <th style="width:120px;">Qté Demandée</th>
                                    <th style="width:120px;">Qté Reçue</th>
                                    <th style="min-width:282px;">Observations</th>
                                    <th style="width:50px;"><button type="button" class="btn btn-sm btn-success" onclick="ajouterLigne()"><i class="fas fa-plus"></i></button></th>
                                </tr>
                            </thead>
                            <tbody id="lignesBody"></tbody>
                        </table>
                    </div>
                    <small class="text-muted">Cliquez sur <i class="fas fa-plus"></i> pour ajouter une ligne.</small>
                </div>
                <div class="modal-footer">
                    <button class="btn btn-primary" id="btnSaveSortie" onclick="saveSortie(event)" type="button"><i class="fas fa-save"></i> Enregistrer</button>
                    <button class="btn btn-danger" id="btnAnnulerSortie" onclick="closeSortieModal()" type="button"><i class="fas fa-times"></i> Annuler</button>
                </div>
            </div>
        </div>

        <!-- MODAL IMPORT -->
        <div id="modalImport" class="modal">
            <div class="modal-content" style="max-width:500px;">
                <div class="modal-header">
                    <h3><i class="fas fa-file-import"></i> Importer des bons</h3>
                    <span class="close" onclick="closeImportModal()">&times;</span>
                </div>
                <div class="modal-body">
                    <p class="text-muted">Sélectionnez un fichier Excel (.xlsx) ...</p>
                    <div class="form-group">
                        <label class="btn btn-outline-primary btn-block" for="excelFile"><i class="fas fa-upload"></i> Choisir un fichier</label>
                        <input type="file" id="excelFile" accept=".xlsx,.xls" style="display:none;" onchange="updateFileName()">
                        <input type="text" id="fileNameDisplay" class="form-control text-center mt-2" readonly placeholder="Aucun fichier sélectionné">
                    </div>
                </div>
                <div class="modal-footer">
                    <button class="btn btn-primary" id="btnLaunchImport" onclick="launchImport()" type="button" disabled><i class="fas fa-check"></i> Lancer l'import</button>
                    <button class="btn btn-danger" onclick="closeImportModal()" type="button"><i class="fas fa-times"></i> Annuler</button>
                </div>
            </div>
        </div>

        <!-- SPINNER -->
        <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;"><div class="spinner"></div></div>

        <!-- SCRIPTS -->
        <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/jspdf.umd.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/jspdf.plugin.autotable.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/xlsx.full.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/vfs_fonts.js?v=<%=AuthHelper.Version %>"></script>
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
