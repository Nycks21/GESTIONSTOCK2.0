<%@ Page Language="C#" AutoEventWireup="true" CodeFile="utilisateurs.cs" Inherits="utilisateurs" %>
  <!DOCTYPE html>
  <html lang="fr">

  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Utilisateur — Gestion Stock</title>

    <!-- Font Awesome -->
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/fontawesome.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>">
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="form1" runat="server">
      <asp:HiddenField ID="hfUserRole" runat="server" />
      <div class="wrapper">

        <!-- ═══ TOPBAR ═══ -->
        <%= AuthHelper.RenderTopBarHTML() %>

          <!-- ═══ SIDEBAR ═══ -->
          <aside class="main-sidebar" id="sidebar">
            <a href="#" class="brand-link">
              <img
                src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='33' height='33' viewBox='0 0 33 33'%3E%3Ccircle cx='16.5' cy='16.5' r='16.5' fill='%23007bff'/%3E%3Ctext x='16.5' y='22' font-size='16' font-weight='bold' text-anchor='middle' fill='white'%3EGS%3C/text%3E%3C/svg%3E"
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
            <div class="content-wrapper md" id="contentWrapper">

              <!-- En-tête dynamique -->
              <div class="content-header">
                <div class="container-fluid">
                  <div class="row">
                    <div class="col-lg-6">
                      <h1 id="dynPageTitle"><i class="fas fa-users" style="color:#007bff;"></i>
                        Liste des utilisateurs</h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float: right;">
                        <li class="breadcrumb-item">Administration</li>
                        <li class="breadcrumb-item active" id="dynBreadcrumb">Utilisateur</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <!-- ═══════════════════════════════════════════════════════════
                    pages/utilisateur.html  —  Section Gestion des utilisateurs
                    ═══════════════════════════════════════════════════════════ -->
              <section class="content" id="section-utilisateur">

                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title"><i class="fas fa-users-cog"></i> Gestion des
                      utilisateurs</span>
                    <div class="action-buttons">
                      <button class="btn btn-success btn-sm" onclick="openAddUserModal()" data-i18n="common.ajouter">
                        <i class="fas fa-plus"></i> Ajouter
                      </button>
                      <button class="btn btn-primary btn-sm" onclick="exportUsersToExcelOnly()">
                        <i class="fas fa-file-excel"></i> Excel
                      </button>
                    </div>
                  </div>

                  <div class="dash-card-body">
                    <!-- Tableau -->
                    <div style="overflow-x: auto; width: 100%; border: 1px solid #dee2e6; border-radius: 8px;">
                      <table class="dash-table"
                        style="table-layout: fixed; width: 1200px; min-width: 100%; border-collapse: collapse;">
                        <thead>
                          <tr style="background-color: #f8f9fa; text-align: left;">
                            <th onclick="sortData('USERNAME')" style="cursor:pointer; width: 100px;">Nom d'utilisateur
                              <i class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('NOM')" style="cursor:pointer; width: 180px;">Nom complet <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('EMAIL')" style="cursor:pointer; width: 180px;">Email <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('ROLEID')" style="cursor:pointer; width: 100px;">Rôle <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('TELEPHONE')" style="cursor:pointer; width: 80px;">Téléphone <i
                                class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('DATECREATION')" style="cursor:pointer; width: 80px;">Date de création
                              <i class="fas fa-sort ml-1"></i></th>
                            <th onclick="sortData('STATUT')" style="cursor:pointer; width: 80px;">Statut <i
                                class="fas fa-sort ml-1"></i></th>
                            <th style="width: 80px;">Actions</th>
                          </tr>
                        </thead>
                        <tbody id="usersTableBody"></tbody>
                      </table>
                    </div>
                  </div>
                </div>
              </section>
            </div>
      </div>

      <!-- MODAL UTILISATEUR -->
      <div id="addUserModal" class="modal">
        <div class="modal-content" style="max-width:550px;">
          <div class="modal-header">
            <h3 id="userModalTitle"><i class="fas fa-user-plus"></i> Ajouter un utilisateur</h3>
          </div>
          <div class="modal-body">
            <input type="hidden" id="userEditEmail">
            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label>Nom d'utilisateur *</label>
                  <input type="text" id="username" class="form-control" placeholder="Nom d'utilisateur">
                </div>
              </div>
            </div>
            <div class="row">
              <div class="col-md-12">
                <div class="form-group">
                  <label>Nom complet *</label>
                  <input type="text" id="Nom" class="form-control" placeholder="Nom et prénom">
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label>Email *</label>
                  <input type="email" id="userEmail" class="form-control" placeholder="email@ecole.com">
                </div>
              </div>

              <div class="col-md-6">
                <div class="form-group">
                  <label>Rôle</label>
                  <select id="userRole" class="form-control">
                    <% if (AuthHelper.IsSuperAdmin()) { %>
                    <option value="0">SuperAdmin</option>
                    <% }%>
                    <option value="1">Administrateur</option>
                    <option value="2">User</option>
                    <option value="3">Logisticien</option>
                    <option value="4">Comptable</option>
                  </select>
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-12">
                <div class="form-group">
                  <label>Mot de passe</label>
                  <input type="password" id="userPassword" class="form-control" placeholder="Mot de passe">
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label>Téléphone</label>
                  <input type="tel" id="userTelephone" class="form-control" placeholder="032 12 345 67">
                </div>
              </div>

              <div class="col-md-6">
                <div class="form-group">
                  <label>Statut</label>
                  <select id="userStatut" class="form-control">
                    <option value="Actif">Actif</option>
                    <option value="Inactif">Inactif</option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Dans la modal addUserModal, après le champ Statut, ajoutez : -->

            <div class="row">
              <div class="col-md-12">
                <div class="form-group">
                  <label style="display: block; margin-bottom: 10px; font-weight: 600;">
                    <i class="fas fa-lock"></i> Permissions et accès au menu :
                  </label>

                  <div
                    style="display: flex; flex-wrap: wrap; gap: 15px; padding: 10px; background: #f8f9fa; border-radius: 8px;">
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permDashboard" value="accueil" style="margin-right: 8px;">
                      <label for="permDashboard" style="margin: 0;">📊 Accueil</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permUnites" value="unites" style="margin-right: 8px;">
                      <label for="permUnites" style="margin: 0;">📏 Unités</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permEmplacements" value="emplacements" style="margin-right: 8px;">
                      <label for="permEmplacements" style="margin: 0;">📦 Emplacements</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permCategories" value="categories" style="margin-right: 8px;">
                      <label for="permCategories" style="margin: 0;">📅 Catégories</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permFournisseurs" value="fournisseurs" style="margin-right: 8px;">
                      <label for="permFournisseurs" style="margin: 0;">📄 Fournisseurs</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permArticles" value="articles" style="margin-right: 8px;">
                      <label for="permArticles" style="margin: 0;">👥 Articles</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permEntrees" value="entrees" style="margin-right: 8px;">
                      <label for="permEntrees" style="margin: 0;">📆 Entrées</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permSorties" value="sorties" style="margin-right: 8px;">
                      <label for="permSorties" style="margin: 0;">⏰ Sorties</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permStock" value="stock" style="margin-right: 8px;">
                      <label for="permStock" style="margin: 0;">🛒 Stock</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permSaisies" value="saisies" style="margin-right: 8px;">
                      <label for="permSaisies" style="margin: 0;">✏️ Saisies</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permAccuses" value="accuses" style="margin-right: 8px;">
                      <label for="permAccuses" style="margin: 0;">🎵 Accusés</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permInventaire" value="inventaire" style="margin-right: 8px;">
                      <label for="permInventaire" style="margin: 0;">💰 Inventaire</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permExploitation" value="exploitation" style="margin-right: 8px;">
                      <label for="permExploitation" style="margin: 0;">🚪 Exploitations</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permUser" value="utilisateurs" style="margin-right: 8px;">
                      <label for="permUser" style="margin: 0;">📖 Utilisateurs</label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permRequetes" value="requetes" style="margin-right: 8px;">
                      <label for="permRequetes" style="margin: 0;">💻 Requêtes SQL</label>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn btn-primary" onclick="saveUser()"><i class="fas fa-save"></i>
              Enregistrer</button>
            <button class="btn btn-danger" onclick="closeAddUserModal()">Annuler</button>
          </div>
        </div>
      </div>

      <!-- MODAL RESTAURATION AVANCÉE -->
      <div id="restoreModal" class="modal">
        <div class="modal-content" style="max-width:700px;">
          <div class="modal-header"
            style="background: linear-gradient(135deg, #70e4bd 0%, #0a835b 100%); color: white;">
            <h3><i class="fas fa-undo-alt"></i> Restauration de la base de données</h3>
            <button type="button" onclick="closeModal('restoreModal')"
              style="background:none; border:none; color:white; font-size:24px; cursor:pointer;">&times;</button>
          </div>
          <div class="modal-body">
            <!-- Étape 1 : Sélection de la source -->
            <div class="restore-step" id="restoreStep1">
              <div style="display: flex; gap: 15px; margin-bottom: 15px;">
                <button class="btn btn-warning" onclick="selectRestoreSource('local')" id="btnSourceLocal">
                  <i class="fas fa-folder-open"></i> Fichier local
                </button>
                <button class="btn btn-secondary" onclick="selectRestoreSource('backup')" id="btnSourceBackup">
                  <i class="fas fa-history"></i> Sauvegardes existantes
                </button>
              </div>

              <!-- Source locale -->
              <div id="restoreSourceLocal" style="display: none;">
                <div class="form-group">
                  <label>Fichier de sauvegarde (.bak) *</label>
                  <div style="display: flex; gap: 10px; align-items: center;">
                    <input type="text" id="restoreFilePath" class="form-control"
                      placeholder="Sélectionner un fichier .bak" readonly style="flex:1;">
                    <button type="button" class="btn btn-primary"
                      onclick="document.getElementById('restoreFileInput').click();">
                      <i class="fas fa-folder-open"></i> Parcourir
                    </button>
                  </div>
                  <input type="file" id="restoreFileInput" accept=".bak" style="display:none;"
                    onchange="handleRestoreFileSelect(event)">
                  <p style="font-size: 11px; color: #6c757d; margin-top: 5px;">
                    <i class="fas fa-info-circle"></i> Taille maximale : 100 Mo (format .bak)
                  </p>
                </div>
              </div>

              <!-- Sauvegardes existantes -->
              <div id="restoreSourceBackup" style="display: none;">
                <div class="form-group">
                  <label>Sélectionner une sauvegarde existante :</label>
                  <div id="backupListContainer"
                    style="max-height: 200px; overflow-y: auto; border: 1px solid #dee2e6; border-radius: 6px;">
                    <div id="backupList" style="padding: 10px;">
                      <p style="text-align: center; color: #6c757d;">Chargement des sauvegardes...
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Étape 2 : Informations -->
            <div id="restoreStep2"
              style="display: none; margin-top: 15px; padding: 15px; background: #f8f9fa; border-radius: 8px;">
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                <div>
                  <label style="font-weight: 600; color: #495057;">Fichier :</label>
                  <span id="restoreFileInfo" style="display: block; padding: 5px 0;">-</span>
                </div>
                <div>
                  <label style="font-weight: 600; color: #495057;">Taille :</label>
                  <span id="restoreSizeInfo" style="display: block; padding: 5px 0;">-</span>
                </div>
                <div>
                  <label style="font-weight: 600; color: #495057;">Date :</label>
                  <span id="restoreDateInfo" style="display: block; padding: 5px 0;">-</span>
                </div>
                <div>
                  <label style="font-weight: 600; color: #495057;">Base cible :</label>
                  <span id="restoreDbInfo" style="display: block; padding: 5px 0;">MONAPPECOLE2</span>
                </div>
              </div>
            </div>

            <!-- Progression -->
            <div id="restoreProgressContainer" style="display: none; margin-top: 15px;">
              <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                <span style="font-size: 13px; font-weight: 600;">Restauration en cours...</span>
                <span id="restoreProgressPercent" style="font-size: 13px; font-weight: bold; color: #28a745;">0%</span>
              </div>
              <div style="width: 100%; height: 10px; background: #e9ecef; border-radius: 5px; overflow: hidden;">
                <div id="restoreProgressBar"
                  style="width: 0%; height: 100%; background: linear-gradient(90deg, #28a745, #20c997); transition: width 0.5s;">
                </div>
              </div>
              <p id="restoreStatusMessage" style="font-size: 12px; color: #6c757d; margin-top: 8px;">
                Initialisation...</p>
            </div>

            <!-- Logs -->
            <div id="restoreLogs" style="display: none; margin-top: 15px;">
              <label style="font-weight: 600;">Journal des opérations :</label>
              <div
                style="background: #1e1e1e; color: #d4d4d4; padding: 10px; border-radius: 6px; max-height: 150px; overflow-y: auto; font-family: monospace; font-size: 12px;"
                id="restoreLogContent">
                <div style="color: #4ec9b0;">[INFO] Initialisation de la restauration...</div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <div style="display: flex; gap: 10px; width: 100%; justify-content: flex-end;">
              <button type="button" class="btn btn-success" id="btnRestoreExecute" onclick="executeRestore()" disabled>
                <i class="fas fa-play"></i> Lancer la restauration
              </button>
              <button type="button" class="btn btn-danger" onclick="closeModal('restoreModal')">Annuler</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Control Sidebar (Barre latérale droite) -->
      <aside class="control-sidebar control-sidebar-dark" id="controlSidebar"
        style="position: fixed;top: 0;right: -300px;width: 300px;padding: 20px;height: 100%;background: #343a40;color: #fff;transition: right 0.3s ease-in-out;z-index: 1050;box-shadow: -2px 0 5px rgba(0,0,0,0.2);overflow-y: auto;">
        <div class="p-3">
          <div
            style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #4a5259; padding-bottom: 10px; margin-bottom: 15px;">
            <h5 style="margin: 0; color: #fff;">
              <i class="fas fa-cog"></i> Paramètres
            </h5>
            <button type="button" id="closeSidebarBtn"
              style="background: none; border: none; color: #fff; font-size: 20px; cursor: pointer;">
              <i class="fas fa-times"></i>
            </button>
          </div>

          <div id="licenceExpirationInfo" class="mb-3" style="color: #adb5bd; font-size: 0.85em;">
            <i class="fas fa-calendar-alt"></i> Licence expirée le :
            <strong id="expirationDateStr">
              <%= AuthHelper.GetExpirationDateString() %>
            </strong>
          </div>

          <div class="mb-3" style="color: #adb5bd; font-size: 0.85em;">
            <i class="fas fa-users"></i> Utilisateur max :
            <strong id="maxUsersCount">
              <%= AuthHelper.GetMaxUsersString() %>
            </strong>
          </div>

          <hr style="border-color: #4a5259;">

          <div style="display: flex; flex-direction: column; gap: 10px; padding: 10px;">
            <div style="width: 100%;">
              <button type="button" id="btnCheckUpdates" class="btn btn-primary"
                style="width: 100%; padding: 10px 15px; text-align: center;" onclick="checkForUpdates()">
                <i class="fas fa-sync-alt"></i> Vérifier les MAJ
              </button>
            </div>
            <div style="width: 100%;">
              <button type="button" id="btnBackup" class="btn btn-success"
                style="width: 100%; padding: 10px 15px; text-align: center;" onclick="backupDatabase()">
                <i class="fas fa-database"></i> Sauvegarde
              </button>
            </div>
            <div style="width: 100%;">
              <button type="button" id="btnRestore" class="btn btn-warning"
                style="width: 100%; padding: 10px 15px; text-align: center;" onclick="openRestoreModal()">
                <i class="fas fa-undo-alt"></i> Restitution
              </button>
            </div>
          </div>

          <hr style="border-color: #4a5259;">
        </div>
      </aside>

      <!-- Overlay pour fermer le sidebar quand on clique à l'extérieur -->
      <div id="sidebarOverlay"
        style="position: fixed;top: 0;left: 0;width: 100%;height: 100%;background: rgba(0,0,0,0.5);z-index: 1040;display: none;cursor: pointer;">
      </div>

      <!-- ═══ SPINNER ═══ -->
      <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
        <div class="spinner"></div>
      </div>

      <!-- ═══ SCRIPTS ═══ -->
      <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/jszip.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/pdfmake.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/vfs_fonts.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
      <div id="toastContainer"></div>
    </form>
  </body>

  </html>
