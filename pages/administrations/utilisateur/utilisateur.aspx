<%@ Page Language="C#" AutoEventWireup="true" CodeFile="utilisateurs.cs" Inherits="utilisateurs" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= AuthHelper.T("title.users_list") %> — Gestion Stock</title>

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
            <div class="sidebar">
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
                      <h1 id="dynPageTitle">
                        <i class="fas fa-users" style="color:#007bff;"></i>
                        <span data-i18n="title.users_list"></span>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float: right;">
                        <li class="breadcrumb-item" data-i18n="nav.administration"></li>
                        <li class="breadcrumb-item active" id="dynBreadcrumb" data-i18n="nav.user"></li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <!-- ═══ Section Gestion des utilisateurs ═══ -->
              <section class="content" id="section-utilisateur">

                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title">
                      <i class="fas fa-users-cog"></i>
                      <span data-i18n="card.users_management"></span>
                    </span>
                    <div class="action-buttons">
                      <button class="btn btn-success btn-sm" onclick="openAddUserModal()">
                        <i class="fas fa-plus"></i>
                        <span data-i18n="button.add"></span>
                      </button>
                      <button class="btn btn-primary btn-sm" onclick="exportUsersToExcelOnly()">
                        <i class="fas fa-file-excel"></i>
                        <span data-i18n="button.export"></span>
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
                            <th onclick="sortData('USERNAME')" style="cursor:pointer; width: 100px;">
                              <span data-i18n="table.username"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('NOM')" style="cursor:pointer; width: 180px;">
                              <span data-i18n="table.fullname"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('EMAIL')" style="cursor:pointer; width: 180px;">
                              <span data-i18n="table.email"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('ROLEID')" style="cursor:pointer; width: 100px;">
                              <span data-i18n="table.role"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('TELEPHONE')" style="cursor:pointer; width: 80px;">
                              <span data-i18n="table.phone"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('DATECREATION')" style="cursor:pointer; width: 80px;">
                              <span data-i18n="table.created_at"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('STATUT')" style="cursor:pointer; width: 80px;">
                              <span data-i18n="table.status"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th style="width: 80px;" data-i18n="table.actions"></th>
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

      <!-- ═══════════════════════════════════════════════════════════
           MODAL UTILISATEUR
           ═══════════════════════════════════════════════════════════ -->
      <div id="addUserModal" class="modal">
        <div class="modal-content" style="max-width:550px;">
          <div class="modal-header">
            <h3 id="userModalTitle">
              <i class="fas fa-user-plus"></i>
              <span data-i18n="modal.add_user"></span>
            </h3>
          </div>
          <div class="modal-body">
            <input type="hidden" id="userEditEmail">

            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.username"></label>
                  <input type="text" id="username" class="form-control"
                         data-i18n-attr="placeholder:label.username">
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-12">
                <div class="form-group">
                  <label data-i18n="label.fullname"></label>
                  <input type="text" id="Nom" class="form-control"
                         data-i18n-attr="placeholder:placeholder.fullname">
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.email"></label>
                  <input type="email" id="userEmail" class="form-control"
                         data-i18n-attr="placeholder:placeholder.email">
                </div>
              </div>

              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.role"></label>
                  <select id="userRole" class="form-control">
                    <% if (AuthHelper.IsSuperAdmin()) { %>
                      <option value="0" data-i18n="role.superadmin"></option>
                    <% } %>
                    <option value="1" data-i18n="role.admin"></option>
                    <option value="2" data-i18n="role.user"></option>
                    <option value="3" data-i18n="role.logisticien"></option>
                    <option value="4" data-i18n="role.comptable"></option>
                  </select>
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-12">
                <div class="form-group">
                  <label data-i18n="label.password"></label>
                  <input type="password" id="userPassword" class="form-control"
                         data-i18n-attr="placeholder:label.password">
                </div>
              </div>
            </div>

            <div class="row">
              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.phone"></label>
                  <input type="tel" id="userTelephone" class="form-control"
                         data-i18n-attr="placeholder:placeholder.phone">
                </div>
              </div>

              <div class="col-md-6">
                <div class="form-group">
                  <label data-i18n="label.status"></label>
                  <select id="userStatut" class="form-control">
                    <option value="Actif" data-i18n="status.active"></option>
                    <option value="Inactif" data-i18n="status.inactive"></option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Permissions -->
            <div class="row">
              <div class="col-md-12">
                <div class="form-group">
                  <label style="display: block; margin-bottom: 10px; font-weight: 600;">
                    <i class="fas fa-lock"></i>
                    <span data-i18n="label.permissions"></span>
                  </label>

                  <div
                    style="display: flex; flex-wrap: wrap; gap: 15px; padding: 10px; background: #f8f9fa; border-radius: 8px;">
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permDashboard" value="accueil" style="margin-right: 8px;">
                      <label for="permDashboard" style="margin: 0;">📊 <span data-i18n="perm.dashboard"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permUnites" value="unites" style="margin-right: 8px;">
                      <label for="permUnites" style="margin: 0;">📏 <span data-i18n="perm.units"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permEmplacements" value="emplacements" style="margin-right: 8px;">
                      <label for="permEmplacements" style="margin: 0;">📦 <span data-i18n="perm.locations"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permCategories" value="categories" style="margin-right: 8px;">
                      <label for="permCategories" style="margin: 0;">📅 <span data-i18n="perm.categories"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permFournisseurs" value="fournisseurs" style="margin-right: 8px;">
                      <label for="permFournisseurs" style="margin: 0;">📄 <span data-i18n="perm.suppliers"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permArticles" value="articles" style="margin-right: 8px;">
                      <label for="permArticles" style="margin: 0;">👥 <span data-i18n="perm.articles"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permEntrees" value="entrees" style="margin-right: 8px;">
                      <label for="permEntrees" style="margin: 0;">📆 <span data-i18n="perm.entries"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permSorties" value="sorties" style="margin-right: 8px;">
                      <label for="permSorties" style="margin: 0;">⏰ <span data-i18n="perm.exits"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permStock" value="stock" style="margin-right: 8px;">
                      <label for="permStock" style="margin: 0;">🛒 <span data-i18n="perm.stock"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permSaisies" value="saisies" style="margin-right: 8px;">
                      <label for="permSaisies" style="margin: 0;">✏️ <span data-i18n="perm.inputs"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permAccuses" value="accuses" style="margin-right: 8px;">
                      <label for="permAccuses" style="margin: 0;">🎵 <span data-i18n="perm.acknowledgments"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permInventaire" value="inventaire" style="margin-right: 8px;">
                      <label for="permInventaire" style="margin: 0;">💰 <span data-i18n="perm.inventory"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permExploitation" value="exploitation" style="margin-right: 8px;">
                      <label for="permExploitation" style="margin: 0;">🚪 <span data-i18n="perm.reports"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permResetpwd" value="resetpwd" style="margin-right: 8px;">
                      <label for="permResetpwd" style="margin: 0;">🔑 <span data-i18n="perm.change_password"></span></label>
                    </div>
                    <div style="display: flex; align-items: center;">
                      <input type="checkbox" id="permUser" value="utilisateurs" style="margin-right: 8px;">
                      <label for="permUser" style="margin: 0;">📖 <span data-i18n="perm.users"></span></label>
                    </div>
                    <% if (AuthHelper.IsSuperAdmin()) { %>
                      <div style="display: flex; align-items: center;">
                        <input type="checkbox" id="permRequetes" value="requetes" style="margin-right: 8px;">
                        <label for="permRequetes" style="margin: 0;">💻 <span data-i18n="perm.sql_queries"></span></label>
                      </div>
                    <% } %>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn btn-primary" onclick="saveUser()">
              <i class="fas fa-save"></i>
              <span data-i18n="button.save"></span>
            </button>
            <button class="btn btn-danger" onclick="closeAddUserModal()" data-i18n="button.cancel"></button>
          </div>
        </div>
      </div>

      <!-- ═══════════════════════════════════════════════════════════
           MODAL RESTAURATION
           ═══════════════════════════════════════════════════════════ -->
      <div id="restoreModal" class="modal">
        <div class="modal-content" style="max-width:700px;">
          <div class="modal-header"
            style="background: linear-gradient(135deg, #70e4bd 0%, #0a835b 100%); color: white;">
            <h3>
              <i class="fas fa-undo-alt"></i>
              <span data-i18n="modal.restore_title"></span>
            </h3>
            <button type="button" onclick="closeModal('restoreModal')"
              style="background:none; border:none; color:white; font-size:24px; cursor:pointer;">&times;</button>
          </div>
          <div class="modal-body">
            <div class="restore-step" id="restoreStep1">
              <div style="display: flex; gap: 15px; margin-bottom: 15px;">
                <button class="btn btn-warning" onclick="selectRestoreSource('local')" id="btnSourceLocal">
                  <i class="fas fa-folder-open"></i>
                  <span data-i18n="button.local_file"></span>
                </button>
                <button class="btn btn-secondary" onclick="selectRestoreSource('backup')" id="btnSourceBackup">
                  <i class="fas fa-history"></i>
                  <span data-i18n="button.existing_backups"></span>
                </button>
              </div>

              <div id="restoreSourceLocal" style="display: none;">
                <div class="form-group">
                  <label data-i18n="label.backup_file"></label>
                  <div style="display: flex; gap: 10px; align-items: center;">
                    <input type="text" id="restoreFilePath" class="form-control"
                      readonly style="flex:1;"
                      data-i18n-attr="placeholder:placeholder.select_bak">
                    <button type="button" class="btn btn-primary"
                      onclick="document.getElementById('restoreFileInput').click();">
                      <i class="fas fa-folder-open"></i>
                      <span data-i18n="button.browse"></span>
                    </button>
                  </div>
                  <input type="file" id="restoreFileInput" accept=".bak" style="display:none;"
                    onchange="handleRestoreFileSelect(event)">
                  <p style="font-size: 11px; color: #6c757d; margin-top: 5px;">
                    <i class="fas fa-info-circle"></i>
                    <span data-i18n="message.max_size_bak"></span>
                  </p>
                </div>
              </div>

              <div id="restoreSourceBackup" style="display: none;">
                <div class="form-group">
                  <label data-i18n="label.select_existing"></label>
                  <div id="backupListContainer"
                    style="max-height: 200px; overflow-y: auto; border: 1px solid #dee2e6; border-radius: 6px;">
                    <div id="backupList" style="padding: 10px;">
                      <p style="text-align: center; color: #6c757d;" data-i18n="message.loading_backups"></p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div id="restoreStep2"
              style="display: none; margin-top: 15px; padding: 15px; background: #f8f9fa; border-radius: 8px;">
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                <div>
                  <label style="font-weight: 600; color: #495057;" data-i18n="label.file"></label>
                  <span id="restoreFileInfo" style="display: block; padding: 5px 0;">-</span>
                </div>
                <div>
                  <label style="font-weight: 600; color: #495057;" data-i18n="label.size"></label>
                  <span id="restoreSizeInfo" style="display: block; padding: 5px 0;">-</span>
                </div>
                <div>
                  <label style="font-weight: 600; color: #495057;" data-i18n="label.date"></label>
                  <span id="restoreDateInfo" style="display: block; padding: 5px 0;">-</span>
                </div>
                <div>
                  <label style="font-weight: 600; color: #495057;" data-i18n="label.target_db"></label>
                  <span id="restoreDbInfo" style="display: block; padding: 5px 0;">Nom de la base de donnée</span>
                </div>
              </div>
            </div>

            <div id="restoreProgressContainer" style="display: none; margin-top: 15px;">
              <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                <span style="font-size: 13px; font-weight: 600;" data-i18n="message.restoring"></span>
                <span id="restoreProgressPercent" style="font-size: 13px; font-weight: bold; color: #28a745;">0%</span>
              </div>
              <div style="width: 100%; height: 10px; background: #e9ecef; border-radius: 5px; overflow: hidden;">
                <div id="restoreProgressBar"
                  style="width: 0%; height: 100%; background: linear-gradient(90deg, #28a745, #20c997); transition: width 0.5s;">
                </div>
              </div>
              <p id="restoreStatusMessage" style="font-size: 12px; color: #6c757d; margin-top: 8px;"
                 data-i18n="message.initializing"></p>
            </div>

            <div id="restoreLogs" style="display: none; margin-top: 15px;">
              <label style="font-weight: 600;" data-i18n="label.operations_log"></label>
              <div
                style="background: #1e1e1e; color: #d4d4d4; padding: 10px; border-radius: 6px; max-height: 150px; overflow-y: auto; font-family: monospace; font-size: 12px;"
                id="restoreLogContent">
                <div style="color: #4ec9b0;">[INFO] Initializing...</div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <div style="display: flex; gap: 10px; width: 100%; justify-content: flex-end;">
              <button type="button" class="btn btn-success" id="btnRestoreExecute" onclick="executeRestore()" disabled>
                <i class="fas fa-play"></i>
                <span data-i18n="button.start_restore"></span>
              </button>
              <button type="button" class="btn btn-danger" onclick="closeModal('restoreModal')" data-i18n="button.cancel"></button>
            </div>
          </div>
        </div>
      </div>

      <!-- ═══ Control Sidebar ═══ -->
      <aside class="control-sidebar control-sidebar-dark" id="controlSidebar"
        style="position: fixed;top: 0;right: -300px;width: 300px;padding: 20px;height: 100%;background: #343a40;color: #fff;transition: right 0.3s ease-in-out;z-index: 1050;box-shadow: -2px 0 5px rgba(0,0,0,0.2);overflow-y: auto;">
        <div class="p-3">
          <div
            style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #4a5259; padding-bottom: 10px; margin-bottom: 15px;">
            <h5 style="margin: 0; color: #fff;">
              <i class="fas fa-cog"></i>
              <span data-i18n="sidebar.settings"></span>
            </h5>
            <button type="button" id="closeSidebarBtn"
              style="background: none; border: none; color: #fff; font-size: 20px; cursor: pointer;">
              <i class="fas fa-times"></i>
            </button>
          </div>

          <div id="licenceExpirationInfo" class="mb-3" style="color: #adb5bd; font-size: 0.85em;">
            <i class="fas fa-calendar-alt"></i>
            <span data-i18n="label.licence_expires"></span>
            <strong id="expirationDateStr">
              <%= AuthHelper.GetExpirationDateString() %>
            </strong>
          </div>

          <div class="mb-3" style="color: #adb5bd; font-size: 0.85em;">
            <i class="fas fa-users"></i>
            <span data-i18n="label.max_users"></span>
            <strong id="maxUsersCount">
              <%= AuthHelper.GetMaxUsersString() %>
            </strong>
          </div>

          <hr style="border-color: #4a5259;">

          <div style="display: flex; flex-direction: column; gap: 10px; padding: 10px;">
            <div style="width: 100%;">
              <button type="button" id="btnCheckUpdates" class="btn btn-primary"
                style="width: 100%; padding: 10px 15px; text-align: center;" onclick="checkForUpdates()">
                <i class="fas fa-sync-alt"></i>
                <span data-i18n="button.check_updates"></span>
              </button>
            </div>
            <div style="width: 100%;">
              <button type="button" id="btnBackup" class="btn btn-success"
                style="width: 100%; padding: 10px 15px; text-align: center;" onclick="backupDatabase()">
                <i class="fas fa-database"></i>
                <span data-i18n="button.backup"></span>
              </button>
            </div>
            <div style="width: 100%;">
              <button type="button" id="btnRestore" class="btn btn-warning"
                style="width: 100%; padding: 10px 15px; text-align: center;" onclick="openRestoreModal()">
                <i class="fas fa-undo-alt"></i>
                <span data-i18n="button.restore"></span>
              </button>
            </div>
          </div>

          <hr style="border-color: #4a5259;">
        </div>
      </aside>

      <!-- Overlay sidebar -->
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
      <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
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
