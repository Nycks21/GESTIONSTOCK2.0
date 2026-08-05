<%@ Page Language="C#" AutoEventWireup="true" CodeFile="classes.cs" Inherits="classes" %>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Classes — Gestion Scolaire</title>
    <!-- Font Awesome -->
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">
</head>
<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="form1" runat="server">
        <div class="wrapper">
            <!-- TOPBAR -->
            <%= AuthHelper.RenderTopBarHTML() %>

            <!-- SIDEBAR -->
            <aside class="main-sidebar" id="sidebar">
                <a href="#" class="brand-link" onclick="loadDashboard()">
                    <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='33' height='33' viewBox='0 0 33 33'%3E%3Ccircle cx='16.5' cy='16.5' r='16.5' fill='%23007bff'/%3E%3Ctext x='16.5' y='22' font-size='16' font-weight='bold' text-anchor='middle' fill='white'%3EGS%3C/text%3E%3C/svg%3E"
                        alt="Logo" class="brand-image">
                    <span class="brand-text">Gestion Scolaire</span>
                </a>
                <div class="sidebar">
                    <%= AuthHelper.RenderMenuHTML() %>
                </div>
            </aside>

            <!-- CONTROL SIDEBAR -->
            <%= AuthHelper.RenderControlSidebarHTML() %>

            <!-- CONTENT WRAPPER -->
            <div class="content-wrapper" id="contentWrapper">
                <div class="content-header">
                    <div class="container-fluid">
                        <div class="row">
                            <div class="col-lg-6">
                                <h1><i class="fas fa-folder" style="color:#007bff;"></i> Gestion des classes</h1>
                            </div>
                            <div class="col-lg-6">
                                <ol class="breadcrumb" style="float:right;">
                                    <li class="breadcrumb-item">Paramètres</li>
                                    <li class="breadcrumb-item active">Classes</li>
                                </ol>
                            </div>
                        </div>
                    </div>
                </div>

                <section class="content">
                    <div class="dash-card">
                        <div class="dash-card-head">
                            <span class="dash-card-title"><i class="fas fa-folder"></i> Liste des classes</span>
                            <div class="action-buttons">
                                <button type="button" class="btn btn-success btn-sm" onclick="openAddClasseModal()">
                                    <i class="fas fa-plus"></i> Ajouter
                                </button>
                                <button type="button" class="btn btn-primary btn-sm" onclick="exportClasses()">
                                    <i class="fas fa-download"></i> Imprimer
                                </button>
                            </div>
                        </div>

                        <div class="dash-card-body">
                            <!-- Statistiques -->
                            <div class="absence-stats" style="grid-template-columns:repeat(auto-fit,minmax(150px,1fr));margin-bottom:20px;" id="ClassesStatsContainer"></div>

                            <!-- Tableau -->
                            <div style="overflow-x:auto;width:100%;border:1px solid #dee2e6;border-radius:8px;">
                                <table class="dash-table" style="table-layout:fixed;width:1200px;min-width:100%;border-collapse:collapse;">
                                    <thead>
                                        <tr style="background-color:#f8f9fa;text-align:center;">
                                            <th style="width:50px;">ID</th>
                                            <th style="width:120px;">Classe</th>
                                            <th style="width:120px;">Niveau</th>
                                            <th style="width:120px;">Effectif</th>
                                            <th style="width:120px;">Titulaire</th>
                                            <th style="width:120px;">Salle</th>
                                            <th style="width:120px;">Statut</th>
                                            <th style="width:120px;">Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody id="ClassesTableBody"></tbody>
                                </table>
                            </div>
                            <!-- Pagination (générée par JS) -->
                        </div>
                    </div>
                </section>
            </div>
        </div>

        <!-- MODAL AJOUT / MODIFICATION CLASSE -->
        <div id="addClasseModal" class="modal" role="dialog" aria-modal="true" aria-labelledby="classeModalTitle">
            <div class="modal-content" style="max-width:550px;">
                <div class="modal-header">
                    <h3 id="classeModalTitle"><i class="fas fa-book-medical"></i> Ajouter une classe</h3>
                    <span class="close" onclick="closeAddClasseModal()">&times;</span>
                </div>
                <div class="modal-body">
                    <input type="hidden" id="classeEditId">
                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Nom de la classe <span class="text-danger">*</span></label>
                                <input type="text" id="ClasseNom" class="form-control" placeholder="Ex: 6ème A">
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Niveau <span class="text-danger">*</span></label>
                                <select id="ClasseNiveau" class="form-control">
                                    <option value="">-- Sélectionner --</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Titulaire (Enseignant) <span class="text-danger">*</span></label>
                                <select id="ClasseUser" class="form-control">
                                    <option value="">-- Sélectionner --</option>
                                </select>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Salle <span class="text-danger">*</span></label>
                                <select id="ClasseSalle" class="form-control">
                                    <option value="">-- Sélectionner --</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Effectif</label>
                                <input type="number" id="ClasseEffectif" class="form-control" value="0">
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Statut</label>
                                <select id="ClasseStatut" class="form-control">
                                    <option value="Actif">Actif</option>
                                    <option value="Inactif">Inactif</option>
                                </select>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" onclick="saveClasse()">
                        <i class="fas fa-save"></i> Enregistrer
                    </button>
                    <button type="button" class="btn btn-danger" onclick="closeAddClasseModal()">Annuler</button>
                </div>
            </div>
        </div>

        <!-- SPINNER -->
        <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
            <div class="spinner"></div>
        </div>

        <!-- TOAST CONTAINER -->
        <div id="toastContainer"></div>

        <!-- SCRIPTS -->
        <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/stats.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
    </form>
</body>
</html>