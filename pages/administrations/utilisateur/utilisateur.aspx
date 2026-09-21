<%@ Page Language="C#" AutoEventWireup="true" CodeFile="utilisateurs.cs" Inherits="utilisateurs" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title data-i18n="title.users_list">Liste des utilisateurs — Gestion Stock</title>

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

        <%= AuthHelper.RenderTopBarHTML() %>

          <aside class="main-sidebar" id="sidebar">
            <div class="sidebar">
              <%= AuthHelper.RenderMenuHTML() %>
            </div>
          </aside>

          <%= AuthHelper.RenderControlSidebarHTML() %>

            <div class="content-wrapper md" id="contentWrapper">

              <div class="content-header">
                <div class="container-fluid">
                  <div class="row">
                    <div class="col-lg-6">
                      <h1 id="dynPageTitle">
                        <i class="fas fa-users" style="color:#007bff;"></i>
                        <span data-i18n="title.users_list">Liste des utilisateurs</span>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float: right;">
                        <li class="breadcrumb-item" data-i18n="nav.administration">Administration</li>
                        <li class="breadcrumb-item active" id="dynBreadcrumb" data-i18n="nav.user">Utilisateur</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content" id="section-utilisateur">
                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title">
                      <i class="fas fa-users-cog"></i>
                      <span data-i18n="card.users_management">Gestion des utilisateurs</span>
                    </span>
                    <div class="action-buttons">
                      <button type="button" class="btn btn-success btn-sm" onclick="openAddUserModal(event)">
                        <i class="fas fa-plus"></i>
                        <span data-i18n="button.add">Ajouter</span>
                      </button>
                      <button type="button" class="btn btn-primary btn-sm" onclick="exportUsersToExcelOnly()">
                        <i class="fas fa-file-excel"></i>
                        <span data-i18n="button.export">Exporter</span>
                      </button>
                    </div>
                  </div>

                  <div class="dash-card-body">
                    <div style="overflow-x: auto; width: 100%; border: 1px solid #dee2e6; border-radius: 8px;">
                      <table class="dash-table"
                        style="table-layout: fixed; width: 1200px; min-width: 100%; border-collapse: collapse;">
                        <thead>
                          <tr style="background-color: #f8f9fa; text-align: left;">
                            <th onclick="sortData('USERNAME')" style="cursor:pointer; width: 100px;">
                              <span data-i18n="table.username">Nom d'utilisateur</span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('NOM')" style="cursor:pointer; width: 180px;">
                              <span data-i18n="table.fullname">Nom complet</span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('EMAIL')" style="cursor:pointer; width: 180px;">
                              <span data-i18n="table.email">Email</span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('ROLEID')" style="cursor:pointer; width: 100px;">
                              <span data-i18n="table.role">Rôle</span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('TELEPHONE')" style="cursor:pointer; width: 80px;">
                              <span data-i18n="table.phone">Téléphone</span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('DATECREATION')" style="cursor:pointer; width: 80px;">
                              <span data-i18n="table.created_at">Date de création</span> <i
                                class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('STATUT')" style="cursor:pointer; width: 80px;">
                              <span data-i18n="table.status">Statut</span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th style="width: 80px;" data-i18n="table.actions">Actions</th>
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
            <h3 id="userModalTitle">
              <i class="fas fa-user-plus"></i>
              <span data-i18n="users.modal.add_title">Ajouter un utilisateur</span>
            </h3>
          </div>
          <div class="modal-body">
            <input type="hidden" id="userEditEmail">

            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.username">Nom d'utilisateur</label>
                  <input type="text" id="username" class="form-control" data-i18n-attr="placeholder:label.username">
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-12">
                <div class="form-group">
                  <label data-i18n="label.fullname">Nom complet</label>
                  <input type="text" id="Nom" class="form-control" data-i18n-attr="placeholder:placeholder.fullname">
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.email">Email</label>
                  <input type="email" id="userEmail" class="form-control"
                    data-i18n-attr="placeholder:placeholder.email">
                </div>
              </div>

              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.role">Rôle</label>
                  <select id="userRole" class="form-control">
                    <% if (AuthHelper.IsSuperAdmin()) { %>
                      <option value="0" data-i18n="role.superadmin">SuperAdmin</option>
                      <% } %>
                        <option value="1" data-i18n="role.admin">Administrateur</option>
                        <option value="2" data-i18n="role.user">User</option>
                        <option value="3" data-i18n="role.logisticien">Logisticien</option>
                        <option value="4" data-i18n="role.comptable">Comptable</option>
                  </select>
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-12">
                <div class="form-group">
                  <label data-i18n="label.password">Mot de passe</label>
                  <input type="password" id="userPassword" class="form-control"
                    data-i18n-attr="placeholder:label.password">
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.phone">Téléphone</label>
                  <input type="tel" id="userTelephone" class="form-control"
                    data-i18n-attr="placeholder:placeholder.phone">
                </div>
              </div>

              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.status">Statut</label>
                  <select id="userStatut" class="form-control">
                    <option value="Actif" data-i18n="status.active">Actif</option>
                    <option value="Inactif" data-i18n="status.inactive">Inactif</option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Permissions -->
            <div class="row">
              <div class="col-md-12">
                <div class="form-group">
                  <label style="display:block;margin-bottom:10px;font-weight:600;">
                    <i class="fas fa-lock"></i>
                    <span data-i18n="label.permissions">Permissions et accès au menu :</span>
                  </label>

                  <%= AuthHelper.RenderPermissionsUI() %>
                </div>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button type="button" class="btn btn-primary" onclick="saveUser(event)">
              <i class="fas fa-save"></i>
              <span data-i18n="button.save">Enregistrer</span>
            </button>
            <button type="button" class="btn btn-danger" onclick="closeAddUserModal(event)"
              data-i18n="button.cancel">Annuler</button>
          </div>
        </div>
      </div>

      <!-- MODAL RESTAURATION -->
      <div id="restoreModal" class="modal">
        <div class="modal-content" style="max-width:700px;">
          <div class="modal-header" style="background:linear-gradient(135deg,#70e4bd 0%,#0a835b 100%);color:white;">
            <h3>
              <i class="fas fa-undo-alt"></i>
              <span data-i18n="modal.restore_title">Restauration de la base de données</span>
            </h3>
            <button type="button" onclick="closeModal('restoreModal')"
              style="background:none;border:none;color:white;font-size:24px;cursor:pointer;">&times;</button>
          </div>
          <div class="modal-body">
            <div class="restore-step" id="restoreStep1">
              <div style="display:flex;gap:15px;margin-bottom:15px;">
                <button class="btn btn-warning" onclick="selectRestoreSource('local')" id="btnSourceLocal">
                  <i class="fas fa-folder-open"></i>
                  <span data-i18n="button.local_file">Fichier local</span>
                </button>
                <button class="btn btn-secondary" onclick="selectRestoreSource('backup')" id="btnSourceBackup">
                  <i class="fas fa-history"></i>
                  <span data-i18n="button.existing_backups">Sauvegardes existantes</span>
                </button>
              </div>

              <div id="restoreSourceLocal" style="display:none;">
                <div class="form-group">
                  <label data-i18n="label.backup_file">Fichier de sauvegarde (.bak) *</label>
                  <div style="display:flex;gap:10px;align-items:center;">
                    <input type="text" id="restoreFilePath" class="form-control" readonly style="flex:1;"
                      data-i18n-attr="placeholder:placeholder.select_bak">
                    <button type="button" class="btn btn-primary"
                      onclick="document.getElementById('restoreFileInput').click();">
                      <i class="fas fa-folder-open"></i>
                      <span data-i18n="button.browse">Parcourir</span>
                    </button>
                  </div>
                  <input type="file" id="restoreFileInput" accept=".bak" style="display:none;"
                    onchange="handleRestoreFileSelect(event)">
                  <p style="font-size:11px;color:#6c757d;margin-top:5px;">
                    <i class="fas fa-info-circle"></i>
                    <span data-i18n="message.max_size_bak">Taille maximale : 100 Mo (format .bak)</span>
                  </p>
                </div>
              </div>

              <div id="restoreSourceBackup" style="display:none;">
                <div class="form-group">
                  <label data-i18n="label.select_existing">Sélectionner une sauvegarde existante :</label>
                  <div id="backupListContainer"
                    style="max-height:200px;overflow-y:auto;border:1px solid #dee2e6;border-radius:6px;">
                    <div id="backupList" style="padding:10px;">
                      <p style="text-align:center;color:#6c757d;" data-i18n="message.loading_backups">Chargement des
                        sauvegardes...</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div id="restoreStep2"
              style="display:none;margin-top:15px;padding:15px;background:#f8f9fa;border-radius:8px;">
              <div style="display:grid;grid-template-columns:1fr 1fr;gap:15px;">
                <div>
                  <label style="font-weight:600;color:#495057;" data-i18n="label.file">Fichier :</label>
                  <span id="restoreFileInfo" style="display:block;padding:5px 0;">-</span>
                </div>
                <div>
                  <label style="font-weight:600;color:#495057;" data-i18n="label.size">Taille :</label>
                  <span id="restoreSizeInfo" style="display:block;padding:5px 0;">-</span>
                </div>
                <div>
                  <label style="font-weight:600;color:#495057;" data-i18n="label.date">Date :</label>
                  <span id="restoreDateInfo" style="display:block;padding:5px 0;">-</span>
                </div>
                <div>
                  <label style="font-weight:600;color:#495057;" data-i18n="label.target_db">Base cible :</label>
                  <span id="restoreDbInfo" style="display:block;padding:5px 0;">-</span>
                </div>
              </div>
            </div>

            <div id="restoreProgressContainer" style="display:none;margin-top:15px;">
              <div style="display:flex;justify-content:space-between;margin-bottom:5px;">
                <span style="font-size:13px;font-weight:600;" data-i18n="message.restoring">Restauration en
                  cours...</span>
                <span id="restoreProgressPercent" style="font-size:13px;font-weight:bold;color:#28a745;">0%</span>
              </div>
              <div style="width:100%;height:10px;background:#e9ecef;border-radius:5px;overflow:hidden;">
                <div id="restoreProgressBar"
                  style="width:0%;height:100%;background:linear-gradient(90deg,#28a745,#20c997);transition:width 0.5s;">
                </div>
              </div>
              <p id="restoreStatusMessage" style="font-size:12px;color:#6c757d;margin-top:8px;"
                data-i18n="message.initializing">Initialisation...</p>
            </div>

            <div id="restoreLogs" style="display:none;margin-top:15px;">
              <label style="font-weight:600;" data-i18n="label.operations_log">Journal des opérations :</label>
              <div
                style="background:#1e1e1e;color:#d4d4d4;padding:10px;border-radius:6px;max-height:150px;overflow-y:auto;font-family:monospace;font-size:12px;"
                id="restoreLogContent">
                <div style="color:#4ec9b0;">[INFO] Initializing...</div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <div style="display:flex;gap:10px;width:100%;justify-content:flex-end;">
              <button type="button" class="btn btn-success" id="btnRestoreExecute" onclick="executeRestore()" disabled>
                <i class="fas fa-play"></i>
                <span data-i18n="button.start_restore">Lancer la restauration</span>
              </button>
              <button type="button" class="btn btn-danger" onclick="closeModal('restoreModal')"
                data-i18n="button.cancel">Annuler</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Control Sidebar -->
      <aside class="control-sidebar control-sidebar-dark" id="controlSidebar"
        style="position:fixed;top:0;right:-300px;width:300px;padding:20px;height:100%;background:#343a40;color:#fff;transition:right 0.3s ease-in-out;z-index:1050;box-shadow:-2px 0 5px rgba(0,0,0,0.2);overflow-y:auto;">
        <div class="p-3">
          <div
            style="display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #4a5259;padding-bottom:10px;margin-bottom:15px;">
            <h5 style="margin:0;color:#fff;">
              <i class="fas fa-cog"></i>
              <span data-i18n="sidebar.settings">Paramètres</span>
            </h5>
            <button type="button" id="closeSidebarBtn"
              style="background:none;border:none;color:#fff;font-size:20px;cursor:pointer;">
              <i class="fas fa-times"></i>
            </button>
          </div>

          <div id="licenceExpirationInfo" class="mb-3" style="color:#adb5bd;font-size:0.85em;">
            <i class="fas fa-calendar-alt"></i>
            <span data-i18n="label.licence_expires">Licence expirée le :</span>
            <strong id="expirationDateStr">
              <%= AuthHelper.GetExpirationDateString() %>
            </strong>
          </div>

          <div class="mb-3" style="color:#adb5bd;font-size:0.85em;">
            <i class="fas fa-users"></i>
            <span data-i18n="label.max_users">Utilisateur max :</span>
            <strong id="maxUsersCount">
              <%= AuthHelper.GetMaxUsersString() %>
            </strong>
          </div>

          <hr style="border-color:#4a5259;">

          <div style="display:flex;flex-direction:column;gap:10px;padding:10px;">
            <div style="width:100%;">
              <button type="button" id="btnCheckUpdates" class="btn btn-primary"
                style="width:100%;padding:10px 15px;text-align:center;" onclick="checkForUpdates()">
                <i class="fas fa-sync-alt"></i>
                <span data-i18n="button.check_updates">Vérifier les MAJ</span>
              </button>
            </div>
            <div style="width:100%;">
              <button type="button" id="btnBackup" class="btn btn-success"
                style="width:100%;padding:10px 15px;text-align:center;" onclick="backupDatabase()">
                <i class="fas fa-database"></i>
                <span data-i18n="button.backup">Sauvegarde</span>
              </button>
            </div>
            <div style="width:100%;">
              <button type="button" id="btnRestore" class="btn btn-warning"
                style="width:100%;padding:10px 15px;text-align:center;" onclick="openRestoreModal()">
                <i class="fas fa-undo-alt"></i>
                <span data-i18n="button.restore">Restitution</span>
              </button>
            </div>
          </div>

          <hr style="border-color:#4a5259;">
        </div>
      </aside>

      <div id="sidebarOverlay"
        style="position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);z-index:1040;display:none;cursor:pointer;">
      </div>

      <div id="spinnerOverlay"
        style="display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.35);z-index:9998;align-items:center;justify-content:center;">
        <div class="ldr" aria-label="Loading">
          <span></span><span></span><span></span><span></span><span></span>
        </div>
      </div>

      <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/jszip.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/pdfmake.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/vfs_fonts.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
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
