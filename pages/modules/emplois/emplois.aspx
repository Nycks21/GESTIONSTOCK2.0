﻿﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="emplois.cs" Inherits="emplois" %>
<!DOCTYPE html>
<html lang="fr">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Emploi du temps — Gestion Scolaire</title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="css/emplois.css?v=<%=AuthHelper.Version %>">
    <style>
        /* Styles spécifiques non présents dans emplois.css */
        .spinner-overlay {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(255, 255, 255, 0.7);
            align-items: center;
            justify-content: center;
            z-index: 9999;
        }
        .spinner {
            width: 40px;
            height: 40px;
            border: 4px solid #f3f3f3;
            border-top: 4px solid #007bff;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .toast-container {
            position: fixed;
            bottom: 24px;
            right: 24px;
            display: flex;
            flex-direction: column;
            gap: 10px;
            z-index: 9999;
        }
        td[data-day] {
            transition: background-color 0.2s;
        }
        td[data-day].drag-over {
            background-color: #cfe2ff !important;
        }
    </style>
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="form1" runat="server">
        <input type="hidden" id="hfUserRole" value="<%= AuthHelper.GetUserRole(HttpContext.Current) %>" />
        <div class="wrapper">
            <!-- TOPBAR & SIDEBAR -->
            <%= AuthHelper.RenderTopBarHTML() %>
            <aside class="main-sidebar" id="sidebar">
                <a href="#" class="brand-link" onclick="loadDashboard()">
                    <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='33' height='33' viewBox='0 0 33 33'%3E%3Ccircle cx='16.5' cy='16.5' r='16.5' fill='%23007bff'/%3E%3Ctext x='16.5' y='22' font-size='16' font-weight='bold' text-anchor='middle' fill='white'%3EGS%3C/text%3E%3C/svg%3E" alt="Logo" class="brand-image">
                    <span class="brand-text">Gestion Scolaire</span>
                </a>
                <div class="sidebar">
                    <%= AuthHelper.RenderMenuHTML() %>
                </div>
            </aside>
            <%= AuthHelper.RenderControlSidebarHTML() %>

            <!-- CONTENT WRAPPER -->
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
                    <div class="row">
                        <div class="col-md-12">
                            <div class="dash-card">
                                <div class="dash-card-head">
                                    <span class="dash-card-title"><i class="fas fa-clock"></i> Planning hebdomadaire</span>
                                    <div class="action-buttons btn-group">
                                        <button type="button" class="btn btn-success btn-sm" id="btnAddEmploi">
                                            <i class="fas fa-plus"></i> Ajouter
                                        </button>
                                        <button type="button" class="btn btn-primary btn-sm" id="btnRefresh">
                                            <i class="fas fa-sync-alt"></i> Actualiser
                                        </button>
                                        <button type="button" class="btn btn-secondary btn-sm" onclick="printEmploi()">
                                            <i class="fas fa-print"></i> Imprimer
                                        </button>
                                    </div>
                                </div>
                                <div class="dash-card-body">
                                    <!-- Filtre classe + mode d'affichage -->
                                    <div class="emploi-filters">
                                        <div class="filter-group">
                                            <label for="classeFilter">Classe</label>
                                            <select id="classeFilter" class="form-control">
                                                <option value="">-- Choisir une classe --</option>
                                            </select>
                                        </div>
                                        <div class="filter-group">
                                            <label for="displayMode">Mode d'affichage</label>
                                            <select id="displayMode" class="form-control"></select>
                                        </div>
                                        <div class="filter-group" id="professeurFilterGroup" style="display:none;">
                                            <label for="professeurFilter">Professeur</label>
                                            <select id="professeurFilter" class="form-control">
                                                <option value="">-- Sélectionner un professeur --</option>
                                            </select>
                                        </div>
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
                        </div>
                    </div>
                </section>
            </div>

            <!-- SPINNER -->
            <div id="spinnerOverlay" class="spinner-overlay">
                <div class="spinner"></div>
            </div>

            <!-- TOAST CONTAINER -->
            <div id="toastContainer" class="toast-container"></div>
        </div>

        <!-- ═══ MODAL ÉDITION ENRICHIE (2 colonnes) ═══ -->
        <div id="editModal" class="modal-overlay">
            <div class="modal-container">
                <div class="modal-header">
                    <h3 id="editModalTitle"><i class="fas fa-pencil-alt"></i> Paramétrer l'emploi du temps</h3>
                    <button type="button" class="modal-close" onclick="closeEditModal()">&times;</button>
                </div>
                <div class="modal-body">
                    <form id="editForm">
                        <!-- Ligne 1 : Classe + Jour -->
                        <div class="row">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>Classe</label>
                                    <select id="editClasse" class="form-control" onchange="loadMatieresForSelectedClasse()">
                                        <option value="">-- Sélectionner --</option>
                                    </select>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>Jour</label>
                                    <select id="editJour" class="form-control">
                                        <option value="1">Lundi</option>
                                        <option value="2">Mardi</option>
                                        <option value="3">Mercredi</option>
                                        <option value="4">Jeudi</option>
                                        <option value="5">Vendredi</option>
                                        <option value="6">Samedi</option>
                                    </select>
                                </div>
                            </div>
                        </div>

                        <!-- Ligne 2 : Heure début + Heure fin -->
                        <div class="row">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>Heure début</label>
                                    <input type="time" id="editHeureDebut" class="form-control" step="1800">
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>Heure fin</label>
                                    <input type="time" id="editHeureFin" class="form-control" step="1800">
                                </div>
                            </div>
                        </div>

                        <!-- Ligne 3 : Matière + Enseignant -->
                        <div class="row">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>Matière</label>
                                    <select id="editMatiere" class="form-control">
                                        <option value="">-- Sélectionner --</option>
                                    </select>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>Enseignant</label>
                                    <input type="text" id="editEnseignant" class="form-control" placeholder="Nom du professeur">
                                </div>
                            </div>
                        </div>

                        <!-- Ligne 4 : Salle + Couleur -->
                        <div class="row">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>Salle</label>
                                    <input type="text" id="editSalle" class="form-control" placeholder="Salle">
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>Couleur</label>
                                    <input type="color" id="editCouleur" class="form-control" value="#007bff" style="height:40px; padding:2px;">
                                </div>
                            </div>
                        </div>

                        <!-- Ligne 5 : Type + URL -->
                        <div class="row">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>Type</label>
                                    <select id="editType" class="form-control">
                                        <option value="cours">Cours</option>
                                        <option value="td">TD</option>
                                        <option value="tp">TP</option>
                                        <option value="examen">Examen</option>
                                        <option value="autre">Autre</option>
                                    </select>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label>URL (lien)</label>
                                    <input type="url" id="editUrl" class="form-control" placeholder="https://exemple.com">
                                </div>
                            </div>
                        </div>

                        <!-- Ligne 6 : Description (pleine largeur) -->
                        <div class="row">
                            <div class="col-md-12">
                                <div class="form-group">
                                    <label>Description</label>
                                    <textarea id="editDescription" class="form-control" rows="3" placeholder="Description du cours"></textarea>
                                </div>
                            </div>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" onclick="closeEditModal()">Annuler</button>
                    <button type="button" class="btn btn-danger" id="btnDeleteEmploi" style="display:none;" onclick="deleteCell()">
                        <i class="fas fa-trash"></i> Supprimer
                    </button>
                    <button type="button" class="btn btn-primary" onclick="saveCell()">
                        <i class="fas fa-save"></i> Enregistrer
                    </button>
                </div>
            </div>
        </div>

        <!-- ═══ SCRIPTS ═══ -->
        <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>

        <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/events.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>

        <script>
            // Fonctions globales pour les onclick
            window.loadEmploi = function () { Emploi.loaders.loadEmploi(); };
            window.openEditModal = function () { Emploi.events.openEdit(null, null); };
            window.saveCell = function () { Emploi.crud.saveCell(); };
            window.deleteCell = function () { Emploi.crud.deleteCell(); };
            window.printEmploi = function () { Emploi.events.print(); };
            window.closeEditModal = function () { Emploi.utils.closeModal('editModal'); };
            window.loadMatieresForSelectedClasse = function () {
                var classeId = document.getElementById('editClasse').value;
                if (classeId) {
                    Emploi.loaders.loadMatieresForClasse(classeId);
                } else {
                    var sel = document.getElementById('editMatiere');
                    if (sel) {
                        sel.innerHTML = '<option value="">-- Sélectionner d\'abord une classe --</option>';
                    }
                }
            };
        </script>
    </form>
</body>

</html>