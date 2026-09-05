<%@ Page Language="C#" AutoEventWireup="true" CodeFile="emplois.cs" Inherits="emplois" %>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Emploi du temps — Gestion de Stock</title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="css/emplois.css?v=<%=AuthHelper.Version %>">
    <style>
        /* Styles complémentaires si nécessaire */
    </style>
</head>
<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="form1" runat="server">
        <div class="wrapper">
            <!-- TOPBAR & SIDEBAR (inclus via helpers) -->
            <%= AuthHelper.RenderTopBarHTML() %>
            <aside class="main-sidebar" id="sidebar">
                <a href="#" class="brand-link" onclick="loadDashboard()">
                    <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='33' height='33' viewBox='0 0 33 33'%3E%3Ccircle cx='16.5' cy='16.5' r='16.5' fill='%23007bff'/%3E%3Ctext x='16.5' y='22' font-size='16' font-weight='bold' text-anchor='middle' fill='white'%3EGS%3C/text%3E%3C/svg%3E" alt="Logo" class="brand-image">
                    <span class="brand-text">Gestion de Stock</span>
                </a>
                <div class="sidebar">
                    <%= AuthHelper.RenderMenuHTML() %>
                </div>
            </aside>
            <%= AuthHelper.RenderControlSidebarHTML() %>

            <!-- CONTENT -->
            <div class="content-wrapper" id="contentWrapper">
                <div class="content-header">
                    <div class="container-fluid">
                        <div class="row">
                            <div class="col-lg-6">
                                <h1><i class="fas fa-calendar-alt" style="color:#007bff;"></i> Emploi du temps</h1>
                            </div>
                            <div class="col-lg-6">
                                <ol class="breadcrumb" style="float: right;">
                                    <li class="breadcrumb-item">Modules</li>
                                    <li class="breadcrumb-item active">Emploi du temps</li>
                                </ol>
                            </div>
                        </div>
                    </div>
                </div>

                <section class="content" id="section-emplois">
                    <div class="dash-card">
                        <div class="dash-card-head">
                            <span class="dash-card-title"><i class="fas fa-clock"></i> Planning hebdomadaire</span>
                            <div class="action-buttons">
                                <button type="button" class="btn btn-success btn-sm" onclick="openEditModal()">
                                    <i class="fas fa-plus"></i> Paramétrer
                                </button>
                                <button type="button" class="btn btn-primary btn-sm" onclick="saveAll()">
                                    <i class="fas fa-save"></i> Sauvegarder
                                </button>
                                <button type="button" class="btn btn-secondary btn-sm" onclick="printEmploi()">
                                    <i class="fas fa-print"></i> Imprimer
                                </button>
                            </div>
                        </div>
                        <div class="dash-card-body">
                            <!-- Filtre classe -->
                            <div class="emploi-filters">
                                <div class="filter-group">
                                    <label for="classeFilter">Classe</label>
                                    <select id="classeFilter" class="form-control" onchange="loadEmploi()">
                                        <option value="">-- Choisir une classe --</option>
                                    </select>
                                </div>
                                <div class="filter-group">
                                    <label for="semaineFilter">Semaine</label>
                                    <input type="week" id="semaineFilter" class="form-control" onchange="loadEmploi()">
                                </div>
                                <button type="button" class="btn btn-info btn-sm" onclick="loadEmploi()">
                                    <i class="fas fa-sync-alt"></i> Actualiser
                                </button>
                            </div>

                            <!-- Tableau -->
                            <div class="table-responsive">
                                <table class="emploi-table" id="emploiTable">
                                    <thead>
                                        <tr>
                                            <th class="time-col">Horaire</th>
                                            <th data-day="1">Lundi</th>
                                            <th data-day="2">Mardi</th>
                                            <th data-day="3">Mercredi</th>
                                            <th data-day="4">Jeudi</th>
                                            <th data-day="5">Vendredi</th>
                                            <th data-day="6">Samedi</th>
                                        </tr>
                                    </thead>
                                    <tbody id="emploiBody">
                                        <!-- généré par JS -->
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </section>
            </div>

            <div id="spinnerOverlay"><div class="spinner"></div></div>
        </div>

        <!-- MODAL Paramétrage -->
        <div id="editModal" class="modal">
            <div class="modal-content" style="max-width:700px;">
                <div class="modal-header">
                    <h3><i class="fas fa-pencil-alt"></i> Paramétrer l'emploi du temps</h3>
                    <button type="button" onclick="closeEditModal()" style="background:none;border:none;font-size:24px;cursor:pointer;">&times;</button>
                </div>
                <div class="modal-body" style="max-height:70vh;overflow-y:auto;">
                    <div class="form-group">
                        <label>Classe</label>
                        <select id="editClasse" class="form-control" onchange="loadMatieresForClasse()"></select>
                    </div>
                    <div class="form-group">
                        <label>Jour</label>
                        <select id="editJour" class="form-control">
                            <option value="1">Lundi</option><option value="2">Mardi</option>
                            <option value="3">Mercredi</option><option value="4">Jeudi</option>
                            <option value="5">Vendredi</option><option value="6">Samedi</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Heure début</label>
                        <input type="time" id="editHeureDebut" class="form-control" step="1800">
                    </div>
                    <div class="form-group">
                        <label>Heure fin</label>
                        <input type="time" id="editHeureFin" class="form-control" step="1800">
                    </div>
                    <div class="form-group">
                        <label>Matière</label>
                        <select id="editMatiere" class="form-control">
                            <option value="">-- Sélectionner --</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Enseignant</label>
                        <input type="text" id="editEnseignant" class="form-control" placeholder="Nom du professeur">
                    </div>
                    <div class="form-group">
                        <label>Salle</label>
                        <input type="text" id="editSalle" class="form-control" placeholder="Salle">
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" onclick="saveCell()"><i class="fas fa-save"></i> Enregistrer</button>
                    <button type="button" class="btn btn-danger" onclick="deleteCell()"><i class="fas fa-trash"></i> Supprimer</button>
                    <button type="button" class="btn btn-secondary" onclick="closeEditModal()">Fermer</button>
                </div>
            </div>
        </div>

        <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/emplois-config.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/emplois.js?v=<%=AuthHelper.Version %>"></script>
    </form>
</body>
</html>
