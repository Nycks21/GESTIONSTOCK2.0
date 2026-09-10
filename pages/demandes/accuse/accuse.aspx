<%@ Page Language="C#" AutoEventWireup="true" CodeFile="accuse.cs" Inherits="accuse" %>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Accusés de réception — Gestion de Stock</title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>
<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="accuseForm" runat="server">
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
                            <div class="col-lg-6">
                                <h1><i class="fas fa-check-circle" style="color:#28a745;"></i> Accusés de réception</h1>
                            </div>
                            <div class="col-lg-6">
                                <ol class="breadcrumb" style="float:right;">
                                    <li class="breadcrumb-item">Stock</li>
                                    <li class="breadcrumb-item active">Accusés</li>
                                </ol>
                            </div>
                        </div>
                    </div>
                </div>

                <section class="content" id="section-accuse">
                    <!-- STATS (optionnelles) -->
                    <div class="row accuse-stats" id="accuseStats">
                        <div class="col-lg-4 col-6">
                            <div class="stat-card stat-card-total">
                                <div class="stat-icon"><i class="fas fa-clipboard-list"></i></div>
                                <div class="stat-body">
                                    <span class="stat-value" id="statTotal">0</span>
                                    <span class="stat-label">Total accusés</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-4 col-6">
                            <div class="stat-card stat-card-normal">
                                <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                                <div class="stat-body">
                                    <span class="stat-value" id="statValide">0</span>
                                    <span class="stat-label">Validés</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-4 col-6">
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
                            <span class="dash-card-title"><i class="fas fa-check-circle"></i> Bons de sortie validés</span>
                            <div class="action-buttons">
                                <button class="btn btn-primary btn-sm" onclick="exportAccusePDF()" type="button">
                                    <i class="fas fa-file-pdf"></i> PDF
                                </button>
                                <button class="btn btn-outline-success btn-sm" onclick="exportAccuseToExcelOnly()" type="button">
                                    <i class="fas fa-file-excel"></i> Excel
                                </button>
                            </div>
                        </div>

                        <!-- FILTRES -->
                        <div class="dash-card-toolbar">
                            <div class="toolbar-search">
                                <i class="fas fa-search"></i>
                                <input type="text" id="search-filter" class="form-control"
                                       placeholder="Rechercher par numéro, destination…" autocomplete="off" />
                            </div>
                            <select id="destination-filter" class="form-control toolbar-select">
                                <option value="">Toutes destinations</option>
                            </select>
                            <select id="rows-per-page-top" class="form-control toolbar-select">
                                <option value="10">10 par page</option>
                                <option value="25">25 par page</option>
                                <option value="50">50 par page</option>
                                <option value="100">100 par page</option>
                                <option value="all">Tous</option>
                            </select>
                            <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button" title="Réinitialiser les filtres">
                                <i class="fas fa-undo"></i>
                            </button>
                            <span class="toolbar-counter" id="resultsCounter">0 bon(s)</span>
                        </div>

                        <div class="dash-card-body">
                            <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                                <table class="dash-table" style="table-layout:fixed; width:1200px; min-width:100%; border-collapse:collapse;">
                                    <thead>
                                        <tr style="background-color:#f8f9fa;">
                                            <th onclick="sortData('NUMERO')" style="cursor:pointer; width:120px; text-align:left;">N° <i class="fas fa-sort ml-1"></i></th>
                                            <th onclick="sortData('DATE_SORTIE')" style="cursor:pointer; width:130px; text-align:left;">Date <i class="fas fa-sort ml-1"></i></th>
                                            <th style="width:260px; text-align:left;">Articles</th>
                                            <th style="width:110px; text-align:right;">Qté reçue</th>
                                            <th onclick="sortData('DESTINATION')" style="cursor:pointer; width:150px; text-align:left;">Destination <i class="fas fa-sort ml-1"></i></th>
                                            <th onclick="sortData('STATUT')" style="cursor:pointer; width:100px; text-align:left;">Statut <i class="fas fa-sort ml-1"></i></th>
                                            <th style="width:80px; text-align:left;">Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody id="accuseTableBody">
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

        <!-- MODAL VISUALISATION (réutilisé depuis SORTIE) -->
        <div id="accuseModal" class="modal">
            <input type="hidden" id="editingId" value="" />
            <div class="modal-content modal-article" style="max-width:900px;">
                <div class="modal-header">
                    <h3 id="modalTitle"><i class="fas fa-eye"></i> Détails du bon de sortie</h3>
                    <span class="close" onclick="closeAccuseModal()">&times;</span>
                </div>
                <div class="modal-body">
                    <!-- Informations générales -->
                    <div class="row">
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Numéro</label>
                                <input type="text" id="accuseNumero" class="form-control" disabled />
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Date</label>
                                <input type="datetime-local" id="accuseDate" class="form-control" disabled />
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Destination</label>
                                <input type="text" id="accuseDestination" class="form-control" disabled />
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Bénéficiaire</label>
                                <input type="text" id="accuseNom" class="form-control" disabled />
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Fonction</label>
                                <input type="text" id="accuseFonction" class="form-control" disabled />
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="form-group">
                                <label>Notes</label>
                                <input type="text" id="accuseNotes" class="form-control" disabled />
                            </div>
                        </div>
                    </div>

                    <hr />
                    <h5><i class="fas fa-list"></i> Articles reçus</h5>
                    <div class="table-responsive" style="max-height:300px; overflow-y:auto; border:1px solid #ddd; border-radius:6px;">
                        <table class="table table-bordered table-sm" style="margin-bottom:0;">
                            <thead style="background:#f1f1f1; position:sticky; top:0; z-index:1;">
                                <tr>
                                    <th style="width:40px;">#</th>
                                    <th style="width:120px; text-align:left;">Article</th>
                                    <th style="width:120px; text-align:right;">Qté Demandée</th>
                                    <th style="width:120px; text-align:right;">Qté Reçue</th>
                                    <th>Observations</th>
                                </tr>
                            </thead>
                            <tbody id="accuseLignesBody">
                                <!-- Lignes chargées dynamiquement -->
                            </tbody>
                        </table>
                    </div>
                </div>
                <div class="modal-footer">
                    <button class="btn btn-danger" onclick="closeAccuseModal()" type="button">
                        <i class="fas fa-times"></i> Fermer
                    </button>
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
        <script src="../../_assets/js/article-picker.js?v=<%=AuthHelper.Version %>"></script>
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
