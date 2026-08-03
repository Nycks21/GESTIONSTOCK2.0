<%@ Page Language="C#" AutoEventWireup="true" CodeFile="utilitaires.cs" Inherits="utilitaires" %>
    <!DOCTYPE html>
    <html lang="fr">

    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Utilitaires — Gestion Scolaire</title>

        <!-- Font Awesome -->
        <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../../_assets/css/fontawesome.min.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>">
    </head>

    <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
        <form id="form1" runat="server">
            <div class="wrapper">

                <!-- ═══ TOPBAR ═══ -->
                <%= AuthHelper.RenderTopBarHTML() %>

                <!-- ═══ SIDEBAR ═══ -->
                <aside class="main-sidebar" id="sidebar">
                    <a href="#" class="brand-link">
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
                                    <h1><i class="fas fa-tools" style="color:#007bff;"></i> Utilitaires</h1>
                                </div>
                                <div class="col-lg-6">
                                    <ol class="breadcrumb" style="float:right;">
                                        <li class="breadcrumb-item">Administrations</li>
                                        <li class="breadcrumb-item active">Utilitaires</li>
                                    </ol>
                                </div>
                            </div>
                        </div>
                    </div>

                    <section class="content">
                    <div class="container-fluid">
                    <div class="dash-card" style="padding:28px;">

                        <!-- TITRE + BOUTON MODÈLE -->
                        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:24px;flex-wrap:wrap;gap:10px;">
                            <div>
                                <h4 style="margin:0;font-weight:700;">
                                    <i class="fas fa-file-import" style="color:#28a745;"></i>
                                    Importation des élèves via Excel
                                </h4>
                                <small style="color:#6c757d;">Suivez les 4 étapes pour importer vos données depuis un fichier Excel.</small>
                            </div>
                            <button class="btn-imp btn-imp-tpl" onclick="downloadTemplate()" type="button">
                                <i class="fas fa-download"></i> Télécharger le modèle Excel
                            </button>
                        </div>

                        <!-- BARRE DE PROGRESSION -->
                        <div class="imp-wizard">
                            <div class="imp-step" id="imp-step-1">
                                <div class="imp-step-circle">1</div>
                                <div class="imp-step-label">Dépôt<br>du fichier</div>
                            </div>
                            <div class="imp-step" id="imp-step-2">
                                <div class="imp-step-circle">2</div>
                                <div class="imp-step-label">Mappage<br>des colonnes</div>
                            </div>
                            <div class="imp-step" id="imp-step-3">
                                <div class="imp-step-circle">3</div>
                                <div class="imp-step-label">Aperçu<br>& vérification</div>
                            </div>
                            <div class="imp-step" id="imp-step-4">
                                <div class="imp-step-circle">4</div>
                                <div class="imp-step-label">Résultat<br>intégration</div>
                            </div>
                        </div>

                        <!-- ══ ÉTAPE 1 : DÉPÔT ══ -->
                        <div id="imp-panel-1" style="display:none;">
                            <div class="imp-dropzone" id="imp-dropzone"
                                 onclick="document.getElementById('imp-file-input').click()">
                                <i class="fas fa-cloud-upload-alt"></i>
                                <p style="font-size:16px;font-weight:600;margin:8px 0 4px;">
                                    Glissez-déposez votre fichier Excel ici
                                </p>
                                <p style="color:#6c757d;font-size:13px;margin:0 0 14px;">
                                    Formats acceptés : .xlsx, .xls
                                </p>
                                <button type="button" class="btn-imp btn-imp-next"
                                        style="pointer-events:none;">
                                    <i class="fas fa-file-excel"></i> Parcourir
                                </button>
                                <input type="file" id="imp-file-input"
                                       accept=".xlsx,.xls" style="display:none;">
                            </div>
                            <div style="margin-top:14px;display:flex;align-items:center;gap:12px;">
                                <i class="fas fa-file-excel" style="font-size:28px;color:#28a745;"></i>
                                <div>
                                    <div id="imp-file-name" style="font-weight:600;color:#212529;">
                                        Aucun fichier sélectionné
                                    </div>
                                    <div id="imp-file-status" style="font-size:13px;"></div>
                                </div>
                            </div>
                            <div id="imp-columns-preview"></div>
                        </div>

                        <!-- ══ ÉTAPE 2 : MAPPAGE ══ -->
                        <div id="imp-panel-2" style="display:none;">
                            <p style="color:#6c757d;font-size:13px;margin-bottom:14px;">
                                <i class="fas fa-info-circle"></i>
                                Associez chaque champ de la base de données à la colonne Excel correspondante.
                                Les champs marqués <span style="color:#dc3545;">*</span> sont obligatoires.
                            </p>
                            <div class="imp-scroll-table">
                                <table class="imp-mapping-table">
                                    <thead>
                                        <tr>
                                            <th style="width:220px;">Champ base de données</th>
                                            <th>Colonne Excel</th>
                                            <th style="width:200px;">Aperçu (1ère ligne)</th>
                                        </tr>
                                    </thead>
                                    <tbody id="imp-mapping-body"></tbody>
                                </table>
                            </div>
                        </div>

                        <!-- ══ ÉTAPE 3 : APERÇU ══ -->
                        <div id="imp-panel-3" style="display:none;">
                            <div class="imp-stats-bar" id="imp-preview-stats"></div>
                            <div id="imp-preview-table"></div>
                        </div>

                        <!-- ══ ÉTAPE 4 : RÉSULTAT ══ -->
                        <div id="imp-panel-4" style="display:none;">
                            <div id="imp-result-body"></div>
                            <div style="margin-top:20px;display:flex;gap:10px;flex-wrap:wrap;">
                                <button type="button" id="imp-btn-definitif"
                                        class="btn-imp btn-imp-launch" disabled
                                        onclick="confirmerIntegrationDefinitive()">
                                    <i class="fas fa-check-double"></i> Redirection vers la page Elèves
                                </button>
                                <button type="button" class="btn-imp btn-imp-reset" onclick="resetImport()">
                                    <i class="fas fa-redo"></i> Nouvel import
                                </button>
                            </div>
                        </div>

                        <!-- NAVIGATION -->
                        <div class="imp-nav">
                            <button type="button" id="imp-btn-prev"
                                    class="btn-imp btn-imp-prev" onclick="prevStep()" style="display:none;">
                                <i class="fas fa-arrow-left"></i> Précédent
                            </button>
                            <div></div>
                            <div style="display:flex;gap:10px;">
                                <button type="button" id="imp-btn-next"
                                        class="btn-imp btn-imp-next" onclick="nextStep()" style="display:none;">
                                    Suivant <i class="fas fa-arrow-right"></i>
                                </button>
                                <button type="button" id="imp-btn-launch"
                                        class="btn-imp btn-imp-launch" onclick="launchImport()" style="display:none;">
                                    <i class="fas fa-database"></i> Lancer importation
                                </button>
                            </div>
                        </div>

                    </div><!-- /dash-card -->
                    </div><!-- /container-fluid -->
                    </section>

                </div><!-- /content-wrapper -->

                <!-- Modal depot fichier importation -->
                <div class="modal fade" id="modalUploadTemplate" tabindex="-1" role="dialog"
                    aria-labelledby="modalUploadLabel" aria-hidden="true">
                    <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
                        <div class="modal-content">

                            <div class="modal-header bg-primary">
                                <h5 class="modal-title text-white" id="modalUploadLabel">
                                    <i class="fas fa-upload mr-2"></i>Mon template RTF personnel
                                </h5>
                                <button type="button" class="close text-white" data-dismiss="modal">
                                    <span aria-hidden="true">&times;</span>
                                </button>
                            </div>

                            <div class="modal-body">
                                <div class="alert alert-light border mb-3">
                                    <p class="mb-2">
                                        <strong><i class="fas fa-info-circle text-info mr-1"></i>
                                            Déposer votre modèle.</strong>
                                    </p>
                                </div>

                                <div id="dropZone" class="border rounded p-4 text-center mb-3"
                                    style="border: 2px dashed #17a2b8 !important; cursor:pointer;">
                                    <i class="fas fa-cloud-upload-alt fa-3x text-info mb-2 d-block"></i>
                                    <p class="mb-1 font-weight-bold">Glissez-déposez votre fichier .rtf ici</p>
                                    <button type="button" class="btn btn-sm btn-outline-info"
                                        id="btnParcourir">Parcourir…</button>
                                    <p id="nomFichierSelectionne" class="mt-2 mb-0 text-success small font-weight-bold">
                                    </p>
                                </div>
                            </div>

                            <div class="modal-footer">
                                <button type="button" class="btn btn-secondary" data-dismiss="modal">Annuler</button>
                                <button type="button" id="btnValiderUpload" class="btn btn-info" disabled>Uploader le
                                    template</button>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- ═══ SPINNER ═══ -->
                <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
                    <div class="spinner"></div>
                </div>

                <!-- ═══ SCRIPTS ═══ -->
                <!-- SheetJS pour lecture Excel côté client -->
                <script src="../../_assets/js/xlsx.min.js?v=<%=AuthHelper.Version %>"></script>
                <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
                <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
                <script src="js/utilitaire.js?v=<%=AuthHelper.Version %>"></script>
                <div id="toastContainer"></div>
        </form>
    </body>

    </html>