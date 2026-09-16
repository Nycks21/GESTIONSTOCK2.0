<%@ Page Language="C#" AutoEventWireup="true" CodeFile="resetpwd.aspx.cs" Inherits="resetpwd" %>
  <!DOCTYPE html>
  <html lang="fr">

  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Changer mot de passe — Gestion Stock</title>

    <!-- Font Awesome -->
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/fontawesome.min.css?v=<%=AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>">
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

              <!-- En-tête -->
              <div class="content-header">
                <div class="container-fluid">
                  <div class="row">
                    <div class="col-lg-6">
                      <h1 id="dynPageTitle">
                        <i class="fas fa-key" style="color:#007bff;"></i>
                        Changer mot de passe
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float: right;">
                        <li class="breadcrumb-item">Administration</li>
                        <li class="breadcrumb-item active" id="dynBreadcrumb">Changer mot de passe</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Contenu minimal : la page est utilisée uniquement pour héberger le modal -->
              <section class="content" id="section-resetpwd">
                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title">
                      <i class="fas fa-key"></i> Changement de mot de passe
                    </span>
                  </div>
                  <div class="dash-card-body">
                    <div style="text-align: center; padding: 40px 20px; color: #6c757d;">
                      <i class="fas fa-shield-alt" style="font-size: 48px; color: #007bff; display: block; margin-bottom: 15px;"></i>
                      <p style="margin: 0 0 8px 0;">Le formulaire de changement de mot de passe est ouvert.</p>
                      <p style="font-size: 12px; margin: 0;">
                        Si le modal ne s'ouvre pas, cliquez
                        <a href="javascript:void(0);" id="reopenPwdModalLink" style="color:#007bff;text-decoration:underline;">ici</a>.
                      </p>
                    </div>
                  </div>
                </div>
              </section>
            </div>
      </div>

      <!-- ═══════════════════════════════════════════════════════════
           MODAL — Changer mot de passe
           ═══════════════════════════════════════════════════════════ -->
      <div class="pwd-modal-overlay" id="changePwdModal"
           aria-hidden="true" role="dialog" aria-modal="true"
           aria-labelledby="pwdModalTitle">

        <div class="pwd-modal" role="document">

          <div class="pwd-modal-header">
            <h3 id="pwdModalTitle">
              <i class="fas fa-key"></i>
              <span>Changer mot de passe</span>
            </h3>
            <button type="button" class="pwd-modal-close" id="pwdModalClose"
                    aria-label="Fermer" title="Fermer">&times;</button>
          </div>

          <form id="changePwdForm" autocomplete="off" onsubmit="return false;">
            <div class="pwd-modal-body">

              <%-- Zone d'alerte --%>
              <div class="pwd-error-box" id="pwdErrorBox" role="alert" aria-live="polite"></div>

              <%-- Ancien mot de passe --%>
              <div class="pwd-field">
                <label for="pwdOld">Ancien mot de passe</label>
                <div class="pwd-input-wrap">
                  <input type="password" id="pwdOld" name="oldPwd" maxlength="128"
                         autocomplete="current-password" />
                  <button type="button" class="pwd-toggle-eye" data-target="pwdOld"
                          tabindex="-1" aria-label="Afficher / masquer">
                    <i class="fas fa-eye"></i>
                  </button>
                </div>
              </div>

              <%-- Nouveau mot de passe --%>
              <div class="pwd-field">
                <label for="pwdNew">Nouveau mot de passe</label>
                <div class="pwd-input-wrap">
                  <input type="password" id="pwdNew" name="newPwd" maxlength="128"
                         autocomplete="new-password" />
                  <button type="button" class="pwd-toggle-eye" data-target="pwdNew"
                          tabindex="-1" aria-label="Afficher / masquer">
                    <i class="fas fa-eye"></i>
                  </button>
                </div>

                <%-- Indicateur de robustesse --%>
                <div class="pwd-strength" id="pwdStrengthBox" aria-live="polite">
                  <div class="pwd-strength-bar">
                    <span id="pwdStrengthFill"></span>
                  </div>
                  <span class="pwd-strength-text" id="pwdStrengthText">Robustesse : —</span>
                </div>
              </div>

              <%-- Confirmation --%>
              <div class="pwd-field">
                <label for="pwdConfirm">Confirmation du nouveau mot de passe</label>
                <div class="pwd-input-wrap">
                  <input type="password" id="pwdConfirm" name="confirmPwd" maxlength="128"
                         autocomplete="new-password" />
                  <button type="button" class="pwd-toggle-eye" data-target="pwdConfirm"
                          tabindex="-1" aria-label="Afficher / masquer">
                    <i class="fas fa-eye"></i>
                  </button>
                </div>
              </div>

            </div>

            <div class="pwd-modal-footer">
              <button type="button" class="pwd-btn pwd-btn-secondary" id="pwdCancelBtn">
                <i class="fas fa-times"></i>
                <span>Annuler</span>
              </button>
              <button type="button" class="pwd-btn pwd-btn-primary" id="btnSavePwd">
                <span class="pwd-loader" id="pwdLoader"></span>
                <i class="fas fa-save" id="pwdSaveIcon"></i>
                <span>Enregistrer</span>
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- ═══ Configuration exposée au JS (URLs absolues calculées côté serveur) ═══ -->
      <div id="pwdConfig"
           data-pwd-url="<%= PwdHandlerUrl %>"
           data-home-url="<%= HomeUrl %>"
           style="display:none;"></div>

      <!-- Overlay sidebar (Ctrl) -->
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
      <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
<script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/resetpwd.js?v=<%=AuthHelper.Version %>"></script>
      <div id="toastContainer"></div>
    </form>
  </body>

  </html>
