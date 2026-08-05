<%@ Page Language="C#" AutoEventWireup="true" CodeFile="matieres.cs" Inherits="matieres" %>
    <!DOCTYPE html>
    <html lang="fr">

    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Matières — Gestion Scolaire</title>

        <!-- Font Awesome -->
        <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../../_assets/css/fontawesome.min.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">
    </head>

    <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
        <form id="form1" runat="server">
            <div class="wrapper">

                <!-- ═══ TOPBAR ═══ -->
                <%= AuthHelper.RenderTopBarHTML() %>

                    <!-- ═══ SIDEBAR ═══ -->
                    <aside class="main-sidebar" id="sidebar">
                        <a href="../../accueil/dashboards/index.aspx" class="brand-link">
                            <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='33' height='33' viewBox='0 0 33 33'%3E%3Ccircle cx='16.5' cy='16.5' r='16.5' fill='%23007bff'/%3E%3Ctext x='16.5' y='22' font-size='16' font-weight='bold' text-anchor='middle' fill='white'%3EGS%3C/text%3E%3C/svg%3E"
                                alt="Logo" class="brand-image">
                            <span class="brand-text">Gestion Scolaire</span>
                        </a>

                        <div class="sidebar">
                            <!-- GÉNÉRATION AUTOMATIQUE DES MENUS -->
                            <%= AuthHelper.RenderMenuHTML() %>
                        </div>
                    </aside>

                    <!-- ═══ CONTROL SIDEBAR ═══ -->
                    <%= AuthHelper.RenderControlSidebarHTML() %>

                        <!-- ═══ CONTENT WRAPPER ═══ -->
                        <div class="content-wrapper" id="contentWrapper">

                            <!-- En-tête de page -->
                            <div class="content-header">
                                <div class="container-fluid">
                                    <div class="row">
                                        <div class="col-lg-6">
                                            <h1 id="dynPageTitle"><i class="fas fa-book" style="color:#007bff;"></i>
                                                Matières</h1>
                                        </div>
                                        <div class="col-lg-6">
                                            <ol class="breadcrumb" style="float:right;">
                                                <li class="breadcrumb-item">Paramètres</li>
                                                <li class="breadcrumb-item active" id="dynBreadcrumb">Matières</li>
                                            </ol>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- ═══ SECTION MATIÈRES ═══ -->
                            <section class="content" id="section-matieres">

                                <div class="dash-card">
                                    <div class="dash-card-head">
                                        <span class="dash-card-title"><i class="fas fa-book"></i> Matières
                                            enseignées</span>
                                        <div class="action-buttons">
                                            <button type="button" class="btn btn-success btn-sm"
                                                onclick="openAddMatiereModal()">
                                                <i class="fas fa-plus"></i> Ajouter une matière
                                            </button>
                                            <button type="button" class="btn btn-primary btn-sm"
                                                onclick="exportMatieres()">
                                                <i class="fas fa-download"></i> Exporter
                                            </button>
                                        </div>
                                    </div>

                                    <div class="dash-card-body">

                                        <!-- Stats -->
                                        <div class="absence-stats"
                                            style="grid-template-columns:repeat(auto-fit,minmax(150px,1fr));margin-bottom:20px;"
                                            id="matieresStatsContainer"></div>

                                        <!-- Tableau -->
                                        <div
                                            style="overflow-x: auto; width: 100%; border: 1px solid #dee2e6; border-radius: 8px;">
                                            <table class="dash-table"
                                                style="table-layout: fixed; width: 1200px; min-width: 100%; border-collapse: collapse;">
                                                <thead>
                                                    <tr style="background-color: #f8f9fa; text-align: center;">
                                                        <th style="width: 120px;">Matière</th>
                                                        <th style="width: 120px;">Enseignant</th>
                                                        <th style="width: 120px;">Classe</th>
                                                        <th style="width: 120px;">Coefficient</th>
                                                        <th style="width: 120px;">Heures/sem.</th>
                                                        <th style="width: 120px;">Créé le</th>
                                                        <th style="width: 120px;">Actions</th>
                                                    </tr>
                                                </thead>
                                                <tbody id="matieresTableBody"></tbody>
                                            </table>
                                        </div>

                                    </div>
                                </div>

                            </section>

                        </div><!-- /.content-wrapper -->

            </div><!-- /.wrapper -->

            <!-- ═══ MODAL MATIÈRE ═══ -->
            <div id="addMatiereModal" class="modal" role="dialog" aria-modal="true" aria-labelledby="matiereModalTitle">
                <div class="modal-content" style="max-width:550px;">
                    <div class="modal-header">
                        <h3 id="matiereModalTitle"><i class="fas fa-book-medical"></i> Ajouter une matière</h3>
                        <button type="button" class="btn-close-modal" onclick="closeAddMatiereModal()"
                            aria-label="Fermer">&times;</button>
                    </div>
                    <div class="modal-body">
                        <input type="hidden" id="matiereEditId">
                        <div class="form-group">
                            <label for="matiereNom">Nom de la matière *</label>
                            <input type="text" id="matiereNom" class="form-control" placeholder="Ex: Mathématiques"
                                maxlength="100">
                        </div>

                        <div class="form-group">
                            <label>Enseignant Responsable*</label>
                            <select id="matiereEnseignant" class="form-control">
                                <option value="">-- Sélectionner un enseignant --</option>
                            </select>
                        </div>

                        <div class="row">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="matiereCoeff">Coefficient</label>
                                    <input type="number" id="matiereCoeff" class="form-control" value="1" step="0.5"
                                        min="0.5" max="10">
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="matiereHeures">Heures / semaine</label>
                                    <input type="number" id="matiereHeures" class="form-control" value="3" min="1"
                                        max="20">
                                </div>
                            </div>
                        </div>

                        <div class="form-group">
                            <label>Classe</label>
                            <select id="matiereClasse" class="form-control">
                                <option value="">-- Sélectionner une classe --</option>
                            </select>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-primary" onclick="saveMatiere()">
                            <i class="fas fa-save"></i> Enregistrer
                        </button>
                        <button type="button" class="btn btn-danger" onclick="closeAddMatiereModal()">Annuler</button>
                    </div>
                </div>
            </div>

            <!-- ═══ SPINNER ═══ -->
            <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
                <div class="spinner"></div>
            </div>

            <!-- ═══ SCRIPTS ═══ -->
            <script src="../../_assets/js/sweetalert2.all.min.js?v=<%=AuthHelper.Version %>"></script>
            <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>

        </form>
    </body>

    </html>