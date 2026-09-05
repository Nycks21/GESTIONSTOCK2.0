<%@ Page Language="C#" AutoEventWireup="true" CodeFile="requetes.cs" Inherits="requetes" %>
    <!DOCTYPE html>
    <html lang="fr">

    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Utilisateur — Gestion de Stock</title>

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
                    <a href="#" class="brand-link">
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

                    <!-- En-tête dynamique -->
                    <div class="content-header">
                        <div class="container-fluid">
                            <div class="row">
                                <div class="col-lg-6">
                                    <h1 id="dynPageTitle"><i class="fas fa-database" style="color:#007bff;"></i> Requetes SQL</h1>
                                </div>
                                <div class="col-lg-6">
                                    <ol class="breadcrumb" style="float: right;">
                                        <li class="breadcrumb-item">Administration</li>
                                        <li class="breadcrumb-item active" id="dynBreadcrumb">Requetes</li>
                                    </ol>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- ═══════════════════════════════════════════════════════════
                    pages/utilisateur.html  —  Section Gestion des utilisateurs
                    ═══════════════════════════════════════════════════════════ -->
                    <section class="content" id="section-requetes">

                        <!-- 1. BLOC D'AUTHENTIFICATION (Toujours visible si non déverrouillé) -->
                        <div class="dash-card" id="card_auth" runat="server">
                            <div class="dash-card-head">
                                <span class="dash-card-title">
                                    <% if (Session["IsAdminUnlocked"] !=null && (bool)Session["IsAdminUnlocked"]) { %>
                                        <%-- État Déverrouillé : Icône ouverte et texte vert --%>
                                            <i class="fas fa-lock-open text-success"></i>
                                            <span class="text-success">Console SQL Active</span>
                                            <% } else { %>
                                                <%-- État Initial / Échec : Icône fermée et texte rouge --%>
                                                    <i class="fas fa-lock text-danger"></i>
                                                    <span class="text-danger">Accès Restreint</span>
                                                    <% } %>
                                </span>
                            </div>
                            <div class="dash-card-body">
                                <div class="alert alert-info">
                                    <i class="fas fa-key"></i> Veuillez saisir le mot de passe pour activer la console
                                    SQL. En cas d'oubli, contactez l'administrateur pour l'obtenir.
                                </div>
                                <div class="form-inline">
                                    <label class="mr-2">Mot de passe :</label>
                                    <asp:TextBox ID="txtPassword" runat="server" TextMode="Password"
                                        class="form-control" style="width:250px; display:inline-block;"
                                        placeholder="Entrez le code..."></asp:TextBox>

                                    <asp:Button ID="btnValider" runat="server" Text="Débloquer la console"
                                        OnClick="btnValider_Click" class="btn btn-primary" />
                                </div>
                            </div>
                        </div>

                        <!-- 2. BLOC CONSOLE SQL (Masqué par défaut via le code-behind) -->
                        <% if (Session["IsAdminUnlocked"] !=null && (bool)Session["IsAdminUnlocked"]) { %>
                            <div class="dash-card" id="card_console">
                                <div class="dash-card-head">
                                    <span class="dash-card-title"><i class="fas fa-terminal"></i> Console SQL</span>
                                </div>

                                <div class="dash-card-body">
                                    <div class="alert alert-danger">
                                        <i class="fas fa-exclamation-triangle"></i> <strong>Attention :</strong> Toute
                                        commande exécutée impacte directement la base de données de production.
                                    </div>

                                    <div class="mb-3">
                                        <button type="button" class="btn btn-danger" onclick="executeCustomSQL()">
                                            <i class="fas fa-play"></i> Exécuter la requête (Ctrl+Entrée)
                                        </button>
                                        <button type="button" class="btn btn-secondary"
                                            onclick="window.location.href=window.location.href;">
                                            <i class="fas fa-times"></i> Fermer Console
                                        </button>
                                    </div>

                                    <!-- Éditeur de texte style "Dark Mode" -->
                                    <textarea id="sqlConsole" class="form-control" rows="8"
                                        placeholder="Ex: SELECT * FROM NomTABLE"
                                        style="font-family:'Consolas',monospace; background:#1e1e1e; color:#d4d4d4; padding:15px; resize:vertical; min-height:150px; width:100%; box-sizing:border-box;"></textarea>

                                    <div class="mt-2 text-right">
                                        <small class="text-muted"><i class="fas fa-keyboard"></i> Raccourci : Ctrl +
                                            Entrée</small>
                                    </div>

                                    <!-- Zone de résultats (ID unique corrigé) -->
                                    <div id="sqlExecutionContainer"
                                        style="margin-top:20px; border:1px solid #dee2e6; border-radius:4px; background:#f8f9fa; min-height:100px;">
                                        <div id="sqlExecutionResult" style="overflow-x:auto; padding:15px;">
                                            <div style="text-align:center; color:#6c757d; padding:20px;">
                                                <i class="fas fa-info-circle"></i> Les résultats de la requête
                                                s'afficheront ici après l'exécution.
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <% } %>

                    </section>

                    <!-- ═══ SPINNER ═══ -->
                    <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
                        <div class="spinner"></div>
                    </div>

                    <!-- ═══ SCRIPTS ═══ -->
                    <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
                    <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
                    <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
                    <script src="js/script.js?v=<%=AuthHelper.Version %>"></script>
                    <div id="toastContainer"></div>
        </form>
    </body>

    </html>
