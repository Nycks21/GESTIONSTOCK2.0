<%@ Page Language="C#" AutoEventWireup="true" CodeFile="salles.cs" Inherits="salles" %>
    <!DOCTYPE html>
    <html lang="fr">

    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="csrf-token" content="<%= GetCsrfToken() %>" />
        <title>Salles — Gestion Scolaire</title>
        <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../../_assets/css/fontawesome.min.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">
    </head>

    <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
        <form id="form1" runat="server">
            <input type="hidden" id="csrfTokenField" name="csrfTokenField" value="<%= GetCsrfToken() %>" />
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

                            <div class="content-header">
                                <div class="container-fluid">
                                    <div class="row">
                                        <div class="col-lg-6">
                                            <h1><i class="fas fa-door-open" style="color:#007bff;"></i> Salles de classe
                                            </h1>
                                        </div>
                                        <div class="col-lg-6">
                                            <ol class="breadcrumb" style="float:right;">
                                                <li class="breadcrumb-item">Paramètres</li>
                                                <li class="breadcrumb-item active">Salles</li>
                                            </ol>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- ═══ SECTION SALLES ═══ -->
                            <section class="content" id="section-salles">

                                <div class="dash-card">
                                    <div class="dash-card-head">
                                        <span class="dash-card-title"><i class="fas fa-door-open"></i> Liste des
                                            salles</span>
                                        <div class="action-buttons">
                                            <button type="button" class="btn btn-success btn-sm"
                                                onclick="openAddSalleModal()">
                                                <i class="fas fa-plus"></i> Ajouter une salle
                                            </button>
                                            <button type="button" class="btn btn-primary btn-sm"
                                                onclick="exportSalles()">
                                                <i class="fas fa-download"></i> Exporter
                                            </button>
                                        </div>
                                    </div>

                                    <div class="dash-card-body">

                                        <!-- Stats -->
                                        <div class="absence-stats"
                                            style="grid-template-columns:repeat(auto-fit,minmax(150px,1fr));margin-bottom:20px;"
                                            id="sallesStatsContainer"></div>

                                        <!-- Tableau -->
                                        <div
                                            style="overflow-x: auto; width: 100%; border: 1px solid #dee2e6; border-radius: 8px;">
                                            <table class="dash-table"
                                                style="table-layout: fixed; width: 1200px; min-width: 100%; border-collapse: collapse;">
                                                <thead>
                                                    <tr style="background-color: #f8f9fa; text-align: center;">
                                                        <th style="width: 20px;">#</th>
                                                        <th style="width: 120px;">Numéro de salle</th>
                                                        <th style="width: 120px;">Capacité</th>
                                                        <th style="width: 120px;">Statut</th>
                                                        <th style="width: 120px;">Créé le</th>
                                                        <th style="width: 120px;">Actions</th>
                                                    </tr>
                                                </thead>
                                                <tbody id="sallesTableBody"></tbody>
                                            </table>
                                        </div>
                                    </div>
                                </div>

                            </section>
                        </div><!-- /.content-wrapper -->
            </div><!-- /.wrapper -->

            <!-- ═══ MODAL SALLE ═══ -->
            <div id="addSalleModal" class="modal" role="dialog" aria-modal="true" aria-labelledby="salleModalTitle">
                <div class="modal-content" style="max-width:450px;">
                    <div class="modal-header">
                        <h3 id="salleModalTitle"><i class="fas fa-door-open"></i> Ajouter une salle</h3>
                        <button type="button" class="btn-close-modal" onclick="closeAddSalleModal()"
                            aria-label="Fermer">&times;</button>
                    </div>
                    <div class="modal-body">
                        <input type="hidden" id="salleEditId">
                        <div class="form-group">
                            <label for="salleNumero">Numéro de salle *</label>
                            <input type="text" id="salleNumero" class="form-control" placeholder="Ex : Salle 101"
                                maxlength="50">
                        </div>
                        <div class="form-group">
                            <label for="salleCapacite">Capacité (élèves)</label>
                            <input type="number" id="salleCapacite" class="form-control" value="30" min="1" max="200">
                        </div>
                        <div class="form-group">
                            <label for="salleStatut">Statut</label>
                            <select id="salleStatut" class="form-control">
                                <option value="1">Disponible</option>
                                <option value="0">Indisponible</option>
                            </select>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-primary" onclick="saveSalle()">
                            <i class="fas fa-save"></i> Enregistrer
                        </button>
                        <button type="button" class="btn btn-danger" onclick="closeAddSalleModal()">Annuler</button>
                    </div>
                </div>
            </div>

            <!-- ═══ SPINNER ═══ -->
            <div id="spinnerOverlay">
                <div class="spinner"></div>
            </div>

            <!-- ═══ SCRIPTS ═══ -->
            <script src="../../_assets/js/sweetalert2.all.min.js?v=<%=AuthHelper.Version %>"></script>
            <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/stats.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/main.js?v=<%=AuthHelper.Version %>"></script>
            <script type="text/javascript">
                (function () {
                    var meta = document.querySelector('meta[name="csrf-token"]');
                    var token = meta ? meta.getAttribute('content') : null;
                    if (!token || token === 'SESSION EXPIRE') {
                        var input = document.getElementById('csrfTokenField');
                        if (input && input.value) token = input.value;
                    }
                    if (token && token !== 'SESSION EXPIRE' && token.length > 10) {
                        sessionStorage.setItem('CSRF_TOKEN', token);
                        console.log('✅ Token CSRF chargé');
                    } else {
                        console.warn('⚠️ Token CSRF invalide ou manquant');
                    }
                })();
            </script>

        </form>
    </body>

    </html>