﻿﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="frais.cs" Inherits="frais" %>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Frais scolaires — Gestion Scolaire</title>

    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/fontawesome.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>">
</head>
<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="form1" runat="server">
        <div class="wrapper">

            <!-- TOPBAR -->
            <%= AuthHelper.RenderTopBarHTML() %>

            <!-- SIDEBAR -->
            <aside class="main-sidebar" id="sidebar">
                <a href="#" class="brand-link" onclick="loadDashboard()">
                    <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='33' height='33' viewBox='0 0 33 33'%3E%3Ccircle cx='16.5' cy='16.5' r='16.5' fill='%23007bff'/%3E%3Ctext x='16.5' y='22' font-size='16' font-weight='bold' text-anchor='middle' fill='white'%3EGS%3C/text%3E%3C/svg%3E" alt="Logo" class="brand-image">
                    <span class="brand-text">Gestion Scolaire</span>
                </a>
                <div class="sidebar">
                    <%= AuthHelper.RenderMenuHTML() %>
                </div>
            </aside>

            <!-- ═══ CONTROL SIDEBAR ═══ -->
            <%= AuthHelper.RenderControlSidebarHTML() %>

            <!-- CONTENT WRAPPER -->
            <div class="content-wrapper" id="contentWrapper">
                <div class="content-header">
                    <div class="container-fluid">
                        <div class="row">
                            <div class="col-lg-6">
                                <h1 id="dynPageTitle"><i class="fas fa-money-bill" style="color:#007bff;"></i> Frais scolaires</h1>
                            </div>
                            <div class="col-lg-6">
                                <ol class="breadcrumb" style="float: right;">
                                    <li class="breadcrumb-item">Modules</li>
                                    <li class="breadcrumb-item active">Frais scolaires</li>
                                </ol>
                            </div>
                        </div>
                    </div>
                </div>

                <section class="content" id="section-frais">
                    <!-- Onglets -->
                    <div class="frais-tab-container">
                        <button type="button" class="frais-tab-btn active" onclick="switchFraisTab('paiements')">💰 Paiements</button>
                        <button type="button" class="frais-tab-btn" onclick="switchFraisTab('tarifs')">📋 Tarifs écolage</button>
                    </div>

                    <!-- SECTION PAIEMENTS -->
                    <div id="frais-tab-paiements" class="frais-tab-content active">
                        <div class="dash-card">
                            <div class="dash-card-head">
                                <span class="dash-card-title"><i class="fas fa-money-bill-wave"></i> Gestion des paiements</span>
                                <div class="action-buttons">
                                    <button type="button" class="btn btn-success btn-sm" onclick="openAddPaymentModal()"><i class="fas fa-plus"></i> Enregistrer un paiement</button>
                                    <button type="button" class="btn btn-info btn-sm" onclick="updateAllFrais()"><i class="fas fa-database"></i> Mettre à jour les frais</button>
                                    <button type="button" class="btn btn-warning btn-sm" onclick="recalculerFrais()"><i class="fas fa-sync-alt"></i> Recalculer frais</button>
                                    <button type="button" class="btn btn-primary btn-sm" onclick="exportFraisToExcel()"><i class="fas fa-download"></i> Exporter</button>
                                    <button type="button" class="btn btn-secondary btn-sm" onclick="printFraisReport()"><i class="fas fa-print"></i> Imprimer</button>
                                </div>
                            </div>
                            <div class="dash-card-body">
                                <!-- Stats -->
                                <div class="frais-stats" id="fraisStatsContainer">
                                    <div class="stat-card">
                                        <div class="stat-icon">💰</div>
                                        <div class="stat-value" id="statTotalFrais">—</div>
                                        <div class="stat-label">Total attendu</div>
                                    </div>
                                    <div class="stat-card">
                                        <div class="stat-icon" style="color:#28a745">✅</div>
                                        <div class="stat-value" id="statTotalPaye" style="color:#28a745">—</div>
                                        <div class="stat-label">Total payé</div>
                                    </div>
                                    <div class="stat-card">
                                        <div class="stat-icon" style="color:#dc3545">⚠️</div>
                                        <div class="stat-value" id="statTotalReste" style="color:#dc3545">—</div>
                                        <div class="stat-label">Total impayé</div>
                                    </div>
                                    <div class="stat-card">
                                        <div class="stat-icon">📊</div>
                                        <div class="stat-value" id="statTauxRecouvrement">—</div>
                                        <div class="stat-label">Taux recouvrement</div>
                                    </div>
                                </div>
                                <div id="frais-filter-container"></div>
                                <!-- Tableau responsive -->
                                <div class="table-responsive">
                                    <table class="dash-table frais-table-paiements" style="border-collapse: collapse;">
                                        <thead>
                                            <tr style="background-color: #f8f9fa;">
                                                <th style="cursor: pointer;text-align: left;width: 80px;" onclick="sortBy('MATRICULE')">Matricule <i class="fas fa-sort"></i></th>
                                                <th style="cursor: pointer;text-align: left;width: 200px;" onclick="sortBy('NOM')">Nom <i class="fas fa-sort"></i></th>
                                                <th style="cursor: pointer;text-align: left;width: 70px;" onclick="sortBy('CLASSE_NOM')">Classe <i class="fas fa-sort"></i></th>
                                                <th style="cursor: pointer;text-align: right;width: 100px;" onclick="sortBy('TOTAL')">Total <i class="fas fa-sort"></i></th>
                                                <th style="cursor: pointer;text-align: right;width: 100px;" onclick="sortBy('PAYE')">Payé <i class="fas fa-sort"></i></th>
                                                <th style="cursor: pointer;text-align: right;width: 100px;" onclick="sortBy('RESTE')">Reste <i class="fas fa-sort"></i></th>
                                                <th style="width: 150px;">Progression</th>
                                                <th style="cursor: pointer;text-align: left;width: 70px;" onclick="sortBy('STATUT')">Statut <i class="fas fa-sort"></i></th>
                                                <th style="cursor: pointer;text-align: left;width: 80px;">Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody id="fraisTableBody"></tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- SECTION TARIFS -->
                    <div id="frais-tab-tarifs" class="frais-tab-content">
                        <div class="dash-card">
                            <div class="dash-card-head">
                                <span class="dash-card-title"><i class="fas fa-tags"></i> Tarifs d'écolage par classe</span>
                                <div class="action-buttons">
                                    <button type="button" class="btn btn-success btn-sm" onclick="openTarifModal()"><i class="fas fa-plus"></i> Ajouter un tarif</button>
                                </div>
                            </div>
                            <div class="dash-card-body">
                                <!-- Filtres -->
                                <div class="frais-filters">
                                    <select class="form-control" id="tarifAnneeFilter" style="max-width:200px;">
                                        <option value="">Toutes les années</option>
                                    </select>
                                    <select class="form-control" id="tarifClasseFilter" style="max-width:200px;">
                                        <option value="">Toutes les classes</option>
                                    </select>
                                    <button type="button" class="btn btn-secondary btn-sm" onclick="filterTarifs()"><i class="fas fa-filter"></i> Filtrer</button>
                                    <button type="button" class="btn btn-secondary btn-sm" onclick="resetTarifFilters()"><i class="fas fa-undo-alt"></i> Réinitialiser</button>
                                </div>

                                <!-- Tableau des tarifs -->
                                <div class="table-responsive">
                                    <table class="dash-table frais-table-tarifs" style="border-collapse: collapse;">
                                        <thead>
                                            <tr style="background-color: #f8f9fa; text-align: center;">
                                                <th>Année scolaire</th>
                                                <th>Classe</th>
                                                <th>Montant (MGA)</th>
                                                <th>Description</th>
                                                <th>Statut</th>
                                                <th>Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody id="tarifsTableBody"></tbody>
                                    </table>
                                </div>

                                <!-- Pagination -->
                                <div style="display:flex;justify-content:space-between;align-items:center;margin-top:15px;flex-wrap:wrap;gap:10px;">
                                    <span id="tarifsPaginationInfo" style="color:#6c757d;font-size:13px;"></span>
                                    <div class="action-buttons">
                                        <button type="button" class="btn btn-sm btn-secondary" id="prevTarifPageBtn" disabled><i class="fas fa-chevron-left"></i> Précédent</button>
                                        <button type="button" class="btn btn-sm btn-secondary" id="nextTarifPageBtn">Suivant <i class="fas fa-chevron-right"></i></button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </section>
            </div>

            <div id="spinnerOverlay">
                <div class="spinner"></div>
            </div>
        </div>

        <!-- MODAL PAIEMENT -->
        <div id="paymentModal" class="modal">
            <div class="modal-content" style="max-width:500px;">
                <div class="modal-header">
                    <h3><i class="fas fa-money-bill-wave"></i> Enregistrer un paiement</h3>
                    <button type="button" onclick="closePaymentModal()" style="background:none; border:none; font-size:24px; cursor:pointer;">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="form-group">
                        <label>Élève <span style="color: red;">*</span></label>
                        <select id="paymentStudent" class="form-control" onchange="updatePaymentInfo()">
                            <option value="">-- Sélectionner un élève --</option>
                        </select>
                    </div>
                    <div id="paymentInfo" class="payment-detail" style="display: none;">
                        <p><strong>Informations du compte :</strong></p>
                        <p>Montant total: <span id="infoTotal">0</span> MGA</p>
                        <p>Déjà payé: <span id="infoPaye">0</span> MGA</p>
                        <p>Reste à payer: <span id="infoReste" style="font-weight: bold;">0</span> MGA</p>
                    </div>
                    <div class="form-group">
                        <label>Montant du paiement (MGA) <span style="color: red;">*</span></label>
                        <input type="number" id="paymentAmount" class="form-control" placeholder="Saisir le montant" step="1000" min="0">
                    </div>
                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Ecolage mois de <span style="color: red;">*</span></label>
                                <select id="paymentMonth" class="form-control" required>
                                    <option value="">-- Sélectionner le mois --</option>
                                    <option value="Janvier">Janvier</option>
                                    <option value="Février">Février</option>
                                    <option value="Mars">Mars</option>
                                    <option value="Avril">Avril</option>
                                    <option value="Mai">Mai</option>
                                    <option value="Juin">Juin</option>
                                    <option value="Juillet">Juillet</option>
                                    <option value="Aout">Aout</option>
                                    <option value="Septembre">Septembre</option>
                                    <option value="Octobre">Octobre</option>
                                    <option value="Novembre">Novembre</option>
                                    <option value="Décembre">Décembre</option>
                                </select>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Année <span style="color: red;">*</span></label>
                                <input type="text" id="paymentYear" class="form-control" placeholder="Année" required>
                            </div>
                        </div>
                    </div>
                    <div class="form-group">
                        <label>Date du paiement <span style="color: red;">*</span></label>
                        <input type="date" id="paymentDate" class="form-control">
                    </div>
                    <div class="form-group">
                        <label>Mode de paiement <span style="color: red;">*</span></label>
                        <select id="paymentMethod" class="form-control" required>
                            <option value=""></option>
                            <option value="Especes">Espèces</option>
                            <option value="Cheque">Chèque</option>
                            <option value="Virement">Virement bancaire</option>
                            <option value="MobileMoney">Mobile Money</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Référence / Numéro de reçu</label>
                        <input type="text" id="paymentRef" class="form-control" placeholder="Optionnel">
                    </div>
                    <div class="form-group">
                        <label>Commentaire</label>
                        <textarea id="paymentComment" class="form-control" rows="2" placeholder="Commentaire..."></textarea>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" onclick="savePayment()"><i class="fas fa-save"></i> Enregistrer</button>
                    <button type="button" class="btn btn-danger" onclick="closePaymentModal()"><i class="fas fa-times"></i> Annuler</button>
                </div>
            </div>
        </div>

        <!-- MODAL MODIFIER HISTORIQUE PAIEMENT -->
        <div id="editHistoriqueModal" class="modal">
            <div class="modal-content" style="max-width:500px;">
                <div class="modal-header">
                    <h3><i class="fas fa-edit"></i> Modifier le paiement</h3>
                    <button type="button" onclick="closeEditHistoriqueModal()" style="background:none; border:none; font-size:24px; cursor:pointer;">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="form-group">
                        <label>Élève</label>
                        <input type="text" id="editStudentName" class="form-control" readonly style="background:#e9ecef;">
                    </div>
                    <div class="form-group">
                        <label>Montant (MGA) <span style="color: red;">*</span></label>
                        <input type="number" id="editMontant" class="form-control" step="1000" min="0">
                    </div>
                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Ecolage mois de <span style="color: red;">*</span></label>
                                <select id="editPaymentMonth" class="form-control" required>
                                    <option value="">-- Sélectionner le mois --</option>
                                    <option value="Janvier">Janvier</option>
                                    <option value="Février">Février</option>
                                    <option value="Mars">Mars</option>
                                    <option value="Avril">Avril</option>
                                    <option value="Mai">Mai</option>
                                    <option value="Juin">Juin</option>
                                    <option value="Juillet">Juillet</option>
                                    <option value="Aout">Aout</option>
                                    <option value="Septembre">Septembre</option>
                                    <option value="Octobre">Octobre</option>
                                    <option value="Novembre">Novembre</option>
                                    <option value="Décembre">Décembre</option>
                                </select>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group">
                                <label>Année <span style="color: red;">*</span></label>
                                <input type="text" id="editPaymentYear" class="form-control" placeholder="Année">
                            </div>
                        </div>
                    </div>
                    <div class="form-group">
                        <label>Date du paiement <span style="color: red;">*</span></label>
                        <input type="datetime-local" id="editDatePaiement" class="form-control">
                    </div>
                    <div class="form-group">
                        <label>Mode de paiement <span style="color: red;">*</span></label>
                        <select id="editModePaiement" class="form-control">
                            <option value="Especes">Espèces</option>
                            <option value="Cheque">Chèque</option>
                            <option value="Virement">Virement bancaire</option>
                            <option value="MobileMoney">Mobile Money</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Référence</label>
                        <input type="text" id="editReference" class="form-control" placeholder="Optionnel">
                    </div>
                    <div class="form-group">
                        <label>Commentaire</label>
                        <textarea id="editCommentaire" class="form-control" rows="2" placeholder="Commentaire..."></textarea>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" onclick="confirmEditHistorique()"><i class="fas fa-save"></i> Enregistrer</button>
                    <button type="button" class="btn btn-danger" onclick="closeEditHistoriqueModal()"><i class="fas fa-times"></i> Annuler</button>
                </div>
            </div>
        </div>

        <!-- MODAL TARIF ECOLOGNE -->
        <div id="tarifModal" class="modal">
            <div class="modal-content" style="max-width:500px;">
                <div class="modal-header">
                    <h3 id="tarifModalTitle"><i class="fas fa-plus-circle"></i> Ajouter un tarif</h3>
                    <button type="button" onclick="closeTarifModal()" style="background:none; border:none; font-size:24px; cursor:pointer;">&times;</button>
                </div>
                <div class="modal-body">
                    <input type="hidden" id="tarifEditId">
                    <div class="form-group">
                        <label>Année scolaire *</label>
                        <select id="tarifAnnee" class="form-control">
                            <option value="">-- Sélectionner une année --</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Classe *</label>
                        <select id="tarifClasse" class="form-control">
                            <option value="">-- Sélectionner une classe --</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Montant (MGA) *</label>
                        <input type="number" id="tarifMontant" class="form-control" placeholder="Saisir le montant" step="1000" min="0">
                    </div>
                    <div class="form-group">
                        <label>Description</label>
                        <textarea id="tarifDescription" class="form-control" rows="3" placeholder="Description optionnelle..."></textarea>
                    </div>
                    <div class="form-group">
                        <label>Statut</label>
                        <select id="tarifStatut" class="form-control">
                            <option value="1">Actif</option>
                            <option value="0">Inactif</option>
                        </select>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" onclick="saveTarif()"><i class="fas fa-save"></i> Enregistrer</button>
                    <button type="button" class="btn btn-danger" onclick="closeTarifModal()">Annuler</button>
                </div>
            </div>
        </div>

        <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/payments.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/history.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/recalcul.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/tarifs.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
    </form>
</body>
</html>