﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="index.cs" Inherits="index" UICulture="Auto" Culture="Auto" %>
    <!DOCTYPE html>
    <html lang="fr">

    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>
            <%= LocalizationHelper.GetString("Dashboard") %> — Gestion de Stock
        </title>

        <link rel="stylesheet" href="../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../_assets/css/fontawesome.min.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="css/dashboard.css?v=<%=AuthHelper.Version %>">
        <link rel="stylesheet" href="../_assets/css/global.css?v=<%=AuthHelper.Version %>">
    </head>

    <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
        <form id="form1" runat="server">
            <asp:HiddenField ID="hfUserRole" runat="server" />
            <div class="wrapper">

                <!-- ═══ TOPBAR ═══ -->
                <%= AuthHelper.RenderTopBarHTML() %>

                    <!-- ═══ SIDEBAR AVEC GÉNÉRATION AUTOMATIQUE DES MENUS ═══ -->
                    <aside class="main-sidebar" id="sidebar">
                        <a href="#" class="brand-link" onclick="loadDashboard()">
                            <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='33' height='33' viewBox='0 0 33 33'%3E%3Ccircle cx='16.5' cy='16.5' r='16.5' fill='%23007bff'/%3E%3Ctext x='16.5' y='22' font-size='16' font-weight='bold' text-anchor='middle' fill='white'%3EGS%3C/text%3E%3C/svg%3E"
                                alt="Logo" class="brand-image">
                            <span class="brand-text">Gestion de Stock</span>
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
                                            <h1 id="dynPageTitle">Tableau de bord</h1>
                                        </div>
                                        <div class="col-lg-6">
                                            <ol class="breadcrumb" style="float: right;">
                                                <li class="breadcrumb-item">Accueil</li>
                                                <li class="breadcrumb-item active" id="dynBreadcrumb">Tableau de bord
                                                </li>
                                            </ol>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- ═══ ZONE DE CONTENU DYNAMIQUE ═══ -->
                            <section class="content">
                                <div class="container-fluid">

                                    <!-- KPI Row -->
                                    <div class="kpi-row">
                                        <div class="kpi-card" onclick="showKPIDetail('eleves')">
                                            <div class="kpi-accent" style="background:var(--primary)"></div>
                                            <div class="kpi-label">Total élèves</div>
                                            <div class="kpi-val" id="valEleves">—</div>
                                            <div class="kpi-sub"><span class="pill pill-up"
                                                    id="pillEleves">+0</span><span>depuis la rentrée</span></div>
                                        </div>
                                        <div class="kpi-card" onclick="showKPIDetail('classes')">
                                            <div class="kpi-accent" style="background:var(--success)"></div>
                                            <div class="kpi-label">Classes actives</div>
                                            <div class="kpi-val" id="valClasses">—</div>
                                            <div class="kpi-sub"><span class="pill pill-neu" id="pillClasses">Moy. —
                                                    élèves</span></div>
                                        </div>
                                        <div class="kpi-card" onclick="showKPIDetail('presence')">
                                            <div class="kpi-accent" style="background:var(--warning)"></div>
                                            <div class="kpi-label">Taux de présence</div>
                                            <div class="kpi-val"><span id="valPresence">—</span><span
                                                    class="kpi-unit">%</span></div>
                                            <div class="kpi-sub"><span class="pill pill-up"
                                                    id="pillPresence">+0%</span><span id="lblMoisPresence">ce
                                                    mois</span></div>
                                        </div>

                                        <!-- Frais impayés - visible uniquement avec permission -->
                                        <% if (AuthHelper.HasPermission("frais")) { %>
                                            <div class="kpi-card" onclick="showKPIDetail('impayes')">
                                                <div class="kpi-accent" style="background:var(--danger)"></div>
                                                <div class="kpi-label">Frais impayés</div>
                                                <div class="kpi-val" id="valImpayes">—</div>
                                                <div class="kpi-sub"><span class="pill pill-dn"
                                                        id="pillImpayes">0</span><span>vs mois dernier</span></div>
                                            </div>
                                            <% } %>
                                    </div>

                                    <!-- Présences + Répartition -->
                                    <div class="row mt-1">
                                        <div class="col-lg-10">
                                            <div class="dash-card">
                                                <div class="dash-card-head">
                                                    <span class="dash-card-title"><span
                                                            class="dot-terra"></span>Présences — 7 derniers jours</span>
                                                    <span class="dash-card-meta" id="lblMoisPresence2"></span>
                                                </div>
                                                <div class="dash-card-body3">

                                                    <div style="position:relative;height:200px;"><canvas
                                                            id="chartPresence"></canvas></div>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="col-lg-2">
                                            <div class="dash-card">
                                                <div class="dash-card-head"><span class="dash-card-title"><span
                                                            class="dot-terra"></span>Répartition par niveau</span></div>
                                                <div class="dash-card-body3">
                                                    <div
                                                        style="overflow-y: auto; max-height: 250px; display: flex; justify-content: center; width: 100%;">
                                                        <div class="donut-wrap"
                                                            style="display: flex; flex-direction: column; align-items: center; justify-content: center;">
                                                            <canvas id="chartDonut"
                                                                style="display: block; margin: 0 auto;"></canvas>
                                                            <div class="donut-legend" id="donutLegend"
                                                                style="margin-top: 15px; text-align: center;"></div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Réussite + Frais + Indicateurs -->
                                    <div class="row mt-4">
                                        <div class="col-lg-4">
                                            <div class="dash-card">
                                                <div class="dash-card-head"><span class="dash-card-title"><span
                                                            class="dot-terra"></span>Taux de réussite par classe</span>
                                                </div>
                                                <div style="overflow-y: auto; max-height: 250px;">
                                                    <div class="dash-card-body3" id="reussiteContainer">
                                                        <div style="position:relative;height:250px;">
                                                            <canvas id="chartReussite"></canvas>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>

                                        <!-- Frais scolaires mensuels - visible uniquement avec permission -->
                                        <% if (AuthHelper.HasPermission("frais")) { %>
                                            <div class="col-lg-4">
                                                <div class="dash-card">
                                                    <div class="dash-card-head"><span class="dash-card-title"><span
                                                                class="dot-terra"></span>Frais scolaires mensuels</span>
                                                    </div>
                                                    <div class="dash-card-body1">
                                                        <div style="position:relative;height:180px;"><canvas
                                                                id="chartFrais"></canvas></div>
                                                    </div>
                                                </div>
                                            </div>
                                            <% } %>

                                                <div class="col-lg-4">
                                                    <div class="dash-card">
                                                        <div class="dash-card-head"><span class="dash-card-title"><span
                                                                    class="dot-terra"></span>Indicateurs clés</span>
                                                        </div>
                                                        <div class="dash-card-body3">
                                                            <% if (AuthHelper.HasPermission("frais")) { %>
                                                                <div class="gauge-row" id="gaugeContainer"></div>
                                                                <div class="divider-line mt-3 mb-3"></div>
                                                                <% } %>
                                                                    <div class="prog-item">
                                                                        <div class="prog-head"><span
                                                                                class="prog-name">Garçons</span><span
                                                                                class="prog-pct"
                                                                                id="pctGarcons">—%</span></div>
                                                                        <div class="prog-track">
                                                                            <div class="prog-fill" id="fillGarcons"
                                                                                style="background: rgb(56, 150, 238)">
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                    <div class="prog-item">
                                                                        <div class="prog-head"><span
                                                                                class="prog-name">Filles</span><span
                                                                                class="prog-pct"
                                                                                id="pctFilles">—%</span></div>
                                                                        <div class="prog-track">
                                                                            <div class="prog-fill" id="fillFilles"
                                                                                style="background: rgb(253, 127, 148)">
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                        </div>
                                                    </div>
                                                </div>
                                    </div>

                                    <!-- Retards & Absences + Activité récente -->
                                    <div class="row mt-1">
                                        <div class="col-lg-6">
                                            <div class="dash-card">
                                                <div class="dash-card-head">
                                                    <span class="dash-card-title"><span class="dot-terra"></span>Élèves
                                                        — absences fréquentes</span>
                                                    <span class="dash-card-meta">Ce mois</span>
                                                </div>

                                                <div
                                                    style="overflow-y: auto; max-height: 250px; border: 1px solid #dee2e6;">
                                                    <table class="dash-table"
                                                        style="table-layout: fixed; max-width: 200px; min-width: 100%; border-collapse: collapse; ">

                                                        <thead>
                                                            <tr
                                                                style="background-color: #f8f9fa; text-align: center; position: sticky; top: 0; z-index: 10; padding-bottom: 10px;">
                                                                <th>Élève</th>
                                                                <th>Classe</th>
                                                                <th>Absences</th>
                                                                <th>Retards</th>
                                                                <th>Statut</th>
                                                            </tr>
                                                        </thead>
                                                        <tbody id="tbodyAbsences"></tbody>

                                                    </table>
                                                </div>

                                            </div>
                                        </div>

                                        <div class="col-lg-6">
                                            <div class="dash-card">
                                                <div class="dash-card-head"><span class="dash-card-title"><span
                                                            class="dot-terra"></span>Activité récente</span></div>
                                                <div style="overflow-y: auto; max-height: 250px;">
                                                    <div class="dash-card-body1" id="activityFeed"></div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Agenda scolaire (calendrier compact) -->
                                    <div class="row mt-1">
                                        <div class="col-12">
                                            <div class="dash-card">
                                                <!-- EN-TÊTE AVEC LE TITRE UNIQUEMENT -->
                                                <div class="dash-card-head">
                                                    <span class="dash-card-title">
                                                        <span class="dot-terra"></span>Agenda scolaire
                                                    </span>
                                                </div>

                                                <!-- CORPS AVEC CALENDRIER + LISTE ÉVÉNEMENTS -->
                                                <div class="dash-card-body2"
                                                    style="display:flex;gap:30px;align-items:flex-start;flex-wrap:wrap;">
                                                    <!-- PARTIE GAUCHE : CALENDRIER -->
                                                    <div style="flex:0 0 280px;max-width:280px;">
                                                        <!-- CONTROLES DE NAVIGATION AU-DESSUS DU CALENDRIER -->
                                                        <div class="cal-legend">
                                                            <button type="button"
                                                                class="btn btn-sm btn-outline-secondary"
                                                                onclick="prevMonth()" title="Mois précédent">
                                                                <i class="fas fa-chevron-left"></i>
                                                            </button>
                                                            <span id="calendarMonthTitle"
                                                                class="calendar-month-title">Janvier 2026</span>
                                                            <button type="button"
                                                                class="btn btn-sm btn-outline-secondary"
                                                                onclick="nextMonth()" title="Mois suivant">
                                                                <i class="fas fa-chevron-right"></i>
                                                            </button>
                                                            <button type="button"
                                                                class="btn btn-sm btn-outline-secondary"
                                                                onclick="todayMonth()" title="Aujourd'hui">
                                                                <i class="fas fa-calendar-day"></i>
                                                            </button>
                                                        </div>
                                                        <!-- GRILLE DU CALENDRIER -->
                                                        <div id="calendarGrid" class="mini-cal"></div>
                                                    </div>

                                                    <!-- PARTIE DROITE : LISTE DES ÉVÉNEMENTS -->
                                                    <div style="flex:1;min-width:200px;">
                                                        <div class="event-list" id="eventList">
                                                            <div class="event-empty">Chargement des événements...</div>
                                                        </div>
                                                    </div>
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

            <script>
                document.addEventListener('DOMContentLoaded', function () {
                    loadDashboard();
                });
                // À ajouter dans la page d'accueil (index.aspx)
                document.addEventListener('DOMContentLoaded', function () {
                    // Lire le toast stocké
                    var toastData = sessionStorage.getItem('loginToast');

                    if (toastData) {
                        // Supprimer immédiatement pour éviter les doublons
                        sessionStorage.removeItem('loginToast');

                        var parts = toastData.split('|');
                        var type = parts[0] || 'success';
                        var message = parts[1] || 'Authentification réussie';

                        // Afficher le toast après un léger délai
                        setTimeout(function () {
                            if (typeof showNotification === 'function') {
                                showNotification(message, type, 10000);
                            } else if (typeof showLoginSuccessNotification === 'function') {
                                showLoginSuccessNotification(message);
                            } else {
                                // 🔥 SUPPRIMÉ : alert(message);
                                // ✅ Fallback en DOM/CSS pur
                                createFallbackToast(message, type, 10000);
                            }
                        }, 500);
                    }
                });

                // ✅ Fonction fallback en DOM/CSS pur
                function createFallbackToast(message, type, duration) {
                    duration = duration || 5000;

                    var colors = {
                        success: '#28a745',
                        error: '#dc3545',
                        warning: '#ffc107',
                        info: '#17a2b8'
                    };
                    var color = colors[type] || colors.info;

                    // Conteneur
                    var container = document.getElementById('fallbackToastContainer');
                    if (!container) {
                        container = document.createElement('div');
                        container.id = 'fallbackToastContainer';
                        Object.assign(container.style, {
                            position: 'fixed',
                            top: '20px',
                            right: '20px',
                            zIndex: '99999',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: '10px',
                            maxWidth: '320px'
                        });
                        document.body.appendChild(container);
                    }

                    // Toast
                    var toast = document.createElement('div');
                    Object.assign(toast.style, {
                        background: color,
                        color: '#fff',
                        padding: '14px 18px',
                        borderRadius: '8px',
                        boxShadow: '0 4px 16px rgba(0,0,0,0.25)',
                        fontSize: '13px',
                        lineHeight: '1.4',
                        opacity: '0',
                        transform: 'translateX(20px)',
                        transition: 'opacity .3s ease, transform .3s ease',
                        fontFamily: 'sans-serif'
                    });
                    toast.textContent = message;

                    container.appendChild(toast);

                    // Animation entrée
                    requestAnimationFrame(() => {
                        toast.style.opacity = '1';
                        toast.style.transform = 'translateX(0)';
                    });

                    // Auto-suppression
                    setTimeout(() => {
                        toast.style.opacity = '0';
                        toast.style.transform = 'translateX(20px)';
                        setTimeout(() => toast.remove(), 300);
                    }, duration);
                }
            </script>
            <script src="../_assets/js/chart.umd.min.js?v=<%=AuthHelper.Version %>"></script>
            <script src="../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
            <script src="../_assets/js/sweetalert2.all.min.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/charts.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/kpi.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/calendar.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
            <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
        </form>
    </body>

    </html>
