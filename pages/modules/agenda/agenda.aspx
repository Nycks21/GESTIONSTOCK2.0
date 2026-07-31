<%@ Page Language="C#" AutoEventWireup="true" CodeFile="agenda.cs" Inherits="agenda" %>
<!DOCTYPE html>
<html lang="fr">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Agenda — Gestion Scolaire</title>

    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/fontawesome.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">

    <!-- FullCalendar CSS -->
    <link rel="stylesheet" href="css/main.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="css/agenda.css?v=<%=AuthHelper.Version %>">
</head>

<script>
    document.addEventListener('DOMContentLoaded', function() {
        // ✅ Activer manuellement le menu Agenda
        var menuLinks = document.querySelectorAll('.nav-link[data-menu="agenda"]');
        menuLinks.forEach(function(link) {
            link.classList.add('active');
        });
    });
</script>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="form1" runat="server">

        <!-- ✅ Champs cachés pour les permissions -->
    <asp:HiddenField ID="hfUserRole" runat="server" Value="" />
    <asp:HiddenField ID="hfUserName" runat="server" Value="" />
    <asp:HiddenField ID="hfProfesseurId" runat="server" Value="" />
    <asp:HiddenField ID="hfClassesAutorisees" runat="server" Value="" />
    <asp:HiddenField ID="hfMatieresAutorisees" runat="server" Value="" />

        <div class="wrapper">

            <!-- ═══ TOPBAR ═══ -->
            <%= AuthHelper.RenderTopBarHTML() %>

            <!-- ═══ SIDEBAR ═══ -->
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

            <!-- ═══ CONTROL SIDEBAR ═══ -->
            <%= AuthHelper.RenderControlSidebarHTML() %>

            <!-- ═══ CONTENT WRAPPER ═══ -->
            <div class="content-wrapper" id="contentWrapper">

                <div class="content-header">
                    <div class="container-fluid">
                        <div class="row">
                            <div class="col-lg-6">
                                <h1 id="dynPageTitle">📆 Agenda</h1>
                            </div>
                            <div class="col-lg-6">
                                <ol class="breadcrumb" style="float: right;">
                                    <li class="breadcrumb-item">Modules</li>
                                    <li class="breadcrumb-item active" id="dynBreadcrumb">Agenda</li>
                                </ol>
                            </div>
                        </div>
                    </div>
                </div>

                <section class="content" id="section-agenda">
                    <div class="row">
                        <div class="col-md-3">
                            <div class="sticky-top mb-3">
                                <!-- Événements à venir -->
                                <div class="card-list">
                                    <div class="card-header">
                                        <h4 class="card-title"><i class="fas fa-clock"></i> À venir</h4>
                                    </div>
                                    <div class="card-body-list" id="upcomingEvents"
                                        style="max-height:470px; overflow-y:auto;">
                                        <div class="text-center text-muted">Chargement...</div>
                                    </div>
                                </div>

                                <!-- Statistiques rapides -->
                                <div class="card">
                                    <div class="card-header">
                                        <h4 class="card-title"><i class="fas fa-chart-pie"></i> Statistiques</h4>
                                    </div>
                                    <div class="card-body" style="padding:10px 14px;">
                                        <div style="display:flex; justify-content:space-between; padding:4px 0;">
                                            <span style="font-size:12px; color:#6c757d;">Terminé</span>
                                            <span id="statPast" style="font-size:13px; font-weight:600; color:#dc3545;">0</span>
                                        </div>
                                        <div style="display:flex; justify-content:space-between; padding:4px 0; border-bottom:1px solid #f0f0f0;">
                                            <span style="font-size:12px; color:#6c757d;">Ce mois</span>
                                            <span id="statMonthEvents" style="font-size:13px; font-weight:600; color:#1e3a2f;">0</span>
                                        </div>
                                        <div style="display:flex; justify-content:space-between; padding:4px 0;">
                                            <span style="font-size:12px; color:#6c757d;">A venir</span>
                                            <span id="statUpcoming" style="font-size:13px; font-weight:600; color:#28a745;">0</span>
                                        </div>
                                    </div>
                                </div>

                            </div>
                        </div>
                        <!-- /.col -->

                        <div class="col-md-9">
                            <div class="card card-primary">
                                <div class="card-header">
                                    <div class="d-flex justify-content-between align-items-center">
                                        <h3 class="card-title"><i class="fas fa-calendar-alt"></i> Calendrier</h3>
                                        <div class="btn-group">
                                            <button type="button" class="btn btn-success btn-sm" id="btnAddEvent">
                                                <i class="fas fa-plus"></i> Ajouter
                                            </button>
                                            <button type="button" class="btn btn-secondary btn-sm" id="btnRefresh">
                                                <i class="fas fa-sync-alt"></i> Rafraîchir
                                            </button>
                                        </div>
                                    </div>
                                </div>
                                <div class="card-body p-0">
                                    <div id="calendar"></div>
                                </div>
                            </div>
                        </div>
                        <!-- /.col -->
                    </div>
                </section>
            </div>

            <div id="spinnerOverlay">
                <div class="spinner"></div>
            </div>

        </div>

        <!-- ═══ MODAL AJOUT/MODIFICATION ═══ -->
        <div id="eventModal" class="modal-overlay" style="display:none;">
            <div class="modal-container modal-lg">
                <div class="modal-header">
                    <h3 id="eventModalTitle">Ajouter un événement</h3>
                    <button type="button" class="modal-close" onclick="closeEventModal()">&times;</button>
                </div>
                <div class="modal-body">
                    <form id="eventForm">
                        <input type="hidden" id="eventId" value="">
                        <div class="form-row">
                            <div class="form-group col-8">
                                <label>Titre *</label>
                                <input type="text" id="eventTitle" class="form-control" required
                                    placeholder="Titre de l'événement">
                            </div>
                            <div class="form-group col-4">
                                <label>Type</label>
                                <select id="eventType" class="form-control">
                                    <option value="cours">Cours</option>
                                    <option value="examen">Examen</option>
                                    <option value="reunion">Réunion</option>
                                    <option value="reunion_parents">Réunion Parents</option>
                                    <option value="vacances">Vacances</option>
                                    <option value="ferie">Jour férié</option>
                                    <option value="autre">Autre</option>
                                </select>
                            </div>
                        </div>
                        <div class="form-row">
                            <div class="form-group col-6">
                                <label>Date début *</label>
                                <input type="datetime-local" id="eventStart" class="form-control" required>
                            </div>
                            <div class="form-group col-6">
                                <label>Date fin</label>
                                <input type="datetime-local" id="eventEnd" class="form-control">
                            </div>
                        </div>
                        <div class="form-row">
                            <div class="form-group">
                                <label>Description</label>
                                <textarea id="eventDescription" class="form-control" rows="3"
                                    placeholder="Description de l'événement"></textarea>
                            </div>
                        </div>
                        <div class="form-row">
                            <div class="form-group col-4">
                                <label>Couleur</label>
                                <input type="color" id="eventColor" class="form-control" value="#6f42c1"
                                    style="height:40px; padding:2px;">
                            </div>
                            <div class="form-group col-4">
                                <label>Lieu</label>
                                <input type="text" id="eventLocation" class="form-control"
                                    placeholder="Lieu de l'événement">
                            </div>
                            <div class="form-group col-4">
                                <label>Public</label>
                                <select id="eventAudience" class="form-control">
                                    <option value="all">Tous</option>
                                    <option value="eleves">Élèves</option>
                                    <option value="parents">Parents</option>
                                    <option value="enseignants">Enseignants</option>
                                    <option value="personnel">Personnel</option>
                                </select>
                            </div>
                        </div>
                        <div class="form-row">
                            <div class="form-group">
                                <label>Lien (URL)</label>
                                <input type="url" id="eventUrl" class="form-control"
                                    placeholder="https://exemple.com">
                            </div>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" onclick="closeEventModal()">Annuler</button>
                    <button type="button" class="btn btn-danger" id="btnDeleteEvent" style="display:none;"
                        onclick="deleteEvent()">
                        <i class="fas fa-trash"></i> Supprimer
                    </button>
                    <button type="button" class="btn btn-primary" id="btnSaveEvent" onclick="saveEvent()">
                        <i class="fas fa-save"></i> Enregistrer
                    </button>
                </div>
            </div>
        </div>

        <!-- ═══ MODAL DÉTAILS ═══ -->
        <div id="detailModal" class="modal-overlay" style="display:none;">
            <div class="modal-container">
                <div class="modal-header">
                    <h3 id="detailTitle">Détails de l'événement</h3>
                    <button type="button" class="modal-close" onclick="closeDetailModal()">&times;</button>
                </div>
                <div class="modal-body" id="detailBody"></div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" onclick="closeDetailModal()">Fermer</button>
                    <button type="button" class="btn btn-primary" id="btnEditDetail" onclick="editDetail()">
                        <i class="fas fa-edit"></i> Modifier
                    </button>
                </div>
            </div>
        </div>

        <!-- ═══ MODAL CONFIRMATION SUPPRESSION ═══ -->
        <div id="confirmDeleteModal" class="modal-overlay" style="display:none;">
            <div class="modal-container" style="max-width:400px;">
                <div class="modal-header">
                    <h3 style="color:#dc3545; margin:0; display:flex; align-items:center; gap:10px;">
                        <i class="fas fa-exclamation-triangle"></i> Confirmation
                    </h3>
                    <button type="button" class="modal-close" onclick="closeConfirmDeleteModal()"
                        style="background:none; border:none; font-size:28px; cursor:pointer; color:#adb5bd;">&times;</button>
                </div>
                <div class="modal-body">
                    <p id="confirmDeleteMessage" style="margin:0; font-size:15px; line-height:1.6; color:#495057;">
                        Voulez-vous vraiment supprimer cet événement ?
                    </p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" onclick="closeConfirmDeleteModal()">Annuler</button>
                    <button type="button" class="btn btn-danger" id="confirmDeleteBtn">Supprimer</button>
                </div>
            </div>
        </div>

        <div id="toastContainer"
            style="position:fixed; bottom:24px; right:24px; display:flex; flex-direction:column; gap:10px; z-index:9999;">
        </div>

        <!-- ═══ SCRIPTS ═══ -->
        <script src="../../_assets/js/jquery.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/bootstrap.bundle.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/jquery-ui.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/sweetalert2.all.min.js?v=<%=AuthHelper.Version %>"></script>
        <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/main.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/locales/fr.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/calendar.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/templates.js?v=<%=AuthHelper.Version %>"></script>
        <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>

    </form>
</body>

</html>