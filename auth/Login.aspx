﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Login.aspx.cs" Inherits="Login" %>

  <!DOCTYPE html>
  <html lang="fr">

  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
    <title>Connexion</title>

    <!-- Google Font: Source Sans Pro -->
    <link rel="stylesheet" href="../pages/_assets/css/family.css?v=<%= AuthHelper.Version %>" />
    <!-- Font Awesome -->
    <link rel="stylesheet" href="../pages/_assets/css/all.min.css?v=<%= AuthHelper.Version %>" />
    <!-- icheck bootstrap -->
    <link rel="stylesheet" href="../pages/_assets/css/icheck-bootstrap.min.css?v=<%= AuthHelper.Version %>" />
    <!-- Theme style -->
    <link rel="stylesheet" href="../pages/_assets/css/adminlte.min.css?v=<%= AuthHelper.Version %>" />
    <!-- Toastr CSS -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.css" />
    <link rel="stylesheet" href="css/style.css?v=<%= AuthHelper.Version %>" />

    <!-- ════════════════════════════════════════════════════════════════
         ✅ jQuery + Toastr chargés ICI, dans le <head>, de façon SYNCHRONE.
         Raison : ScriptManager.RegisterStartupScript (côté serveur) injecte
         systématiquement son code juste avant </form>. Si Toastr n'est
         chargé qu'après </form> (en bas de body), un toast déclenché juste
         après une connexion réussie risque de s'exécuter AVANT que Toastr
         n'existe encore — d'où l'ancien repli sur un alert() natif du
         navigateur. En chargeant ces deux scripts ici, ils sont disponibles
         dès le tout début du rendu du <body>, donc bien avant n'importe quel
         script injecté plus tard dans la page. Plus aucun pari de timing.
         ════════════════════════════════════════════════════════════════ -->
    <script src="../pages/_assets/js/jquery.min.js?v=<%= AuthHelper.Version %>"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.js"></script>

    <style>
      .d-block {
        display: block;
      }

      .mb-2 {
        margin-bottom: 8px;
      }

      .licence-warning {
        background-color: #fff3cd;
        border: 2px solid #ffc107;
        border-radius: 6px;
        color: #856404;
        padding: 12px 16px;
        font-weight: 600;
        font-size: 13px;
        display: block;
        margin-bottom: 10px;
        text-align: center;
      }

      .licence-error {
        background-color: #fde8e8;
        border: 2px solid #dc3545;
        border-radius: 6px;
        color: #dc3545;
        padding: 12px 16px;
        font-weight: 600;
        font-size: 13px;
        display: block;
        margin-bottom: 10px;
        text-align: center;
      }

      .error-box-red {
        background-color: #fde8e8;
        border: 2px solid #dc3545;
        border-radius: 6px;
        color: #dc3545;
        padding: 12px 16px;
        font-weight: 600;
        font-size: 13px;
        display: flex;
        align-items: center;
        justify-content: center;
        text-align: center;
        gap: 10px;
        margin: 10px 0;
      }

      .error-box-red::before {
        content: "⚠️ ";
        font-size: 16px;
        flex-shrink: 0;
      }

      @keyframes pulse-green {

        0%,
        100% {
          box-shadow: 0 0 0 0 rgba(40, 167, 69, 0.4);
        }

        50% {
          box-shadow: 0 0 0 10px rgba(40, 167, 69, 0);
        }
      }

      /* Toastr override */
      .toast-success {
        background-color: #28a745 !important;
      }

      .toast-error {
        background-color: #dc3545 !important;
      }

      .toast-warning {
        background-color: #ffc107 !important;
      }

      .toast-info {
        background-color: #17a2b8 !important;
      }

      /* Toast personnalisé */
      .toast-login {
        background-color: #28a745 !important;
        border-radius: 8px !important;
        box-shadow: 0 4px 20px rgba(40, 167, 69, 0.3) !important;
      }

      .toast-login .toast-title {
        font-weight: 600;
        font-size: 15px;
        letter-spacing: 0.5px;
      }

      .toast-login .toast-message {
        font-size: 13px;
        opacity: 0.95;
      }

      /* Focus sur les champs */
      .input-group.focused .form-control {
        border-color: #28a745;
        box-shadow: 0 0 0 3px rgba(40, 167, 69, 0.1);
      }

      .input-group.focused .input-group-text {
        border-color: #28a745;
        background-color: #f0fff4;
      }
    </style>

    <!-- ════════════════════════════════════════════════════════════════
         ✅ FONCTIONS WRAPPER — DÉFINIES MAINTENANT DANS LE <head>
         pour être disponibles AVANT que ScriptManager.RegisterStartupScript
         n'injecte son code juste avant </form>.
         ════════════════════════════════════════════════════════════════ -->
    <script>
      // ═════════════════════════════════════════════════════════════════════════
      // CONFIGURATION TOASTR
      // ═════════════════════════════════════════════════════════════════════════

      toastr.options = {
        "closeButton": true,
        "debug": false,
        "newestOnTop": false,
        "progressBar": true,
        "positionClass": "toast-top-right",
        "preventDuplicates": false,
        "onclick": null,
        "showDuration": 300,
        "hideDuration": 1000,
        "timeOut": 10000,
        "extendedTimeOut": 10000,
        "showEasing": "swing",
        "hideEasing": "linear",
        "showMethod": "fadeIn",
        "hideMethod": "fadeOut"
      };

      // ════════════════════════════════════════════════════════════════
      // ✅ NOTIFICATIONS — POINT D'ENTRÉE UNIQUE (Toastr exclusivement)
      // ════════════════════════════════════════════════════════════════
      function showNotification(message, type, duration) {
        type = type || 'info';
        duration = duration || 10000;

        if (typeof toastr !== 'undefined') {
          toastr.options.timeOut = duration;
          toastr.options.extendedTimeOut = Math.min(duration, 1000);

          switch (type) {
            case 'success': toastr.success(message, '✅ Succès'); break;
            case 'error': toastr.error(message, '❌ Erreur'); break;
            case 'warning': toastr.warning(message, '⚠️ Attention'); break;
            default: toastr.info(message, 'ℹ️ Information');
          }
          return;
        }

        // Repli professionnel (jamais un alert() natif)
        showFallbackToast(message, type, duration);
      }

      // ✅ Toast de succès spécifique à la connexion (style "Login — Utilisateur authentifié")
      function showLoginSuccessNotification(message) {
        if (typeof toastr !== 'undefined') {
          toastr.options.timeOut = 10000;
          toastr.options.extendedTimeOut = 10000;
          toastr.options.progressBar = true;
          toastr.success(
            '<div style="font-size:14px;font-weight:500;display:flex;align-items:center;gap:6px;">' +
            '<span style="font-size:16px;">👤</span> ' +
            '<span>Utilisateur authentifié</span>' +
            '<span style="font-size:12px;opacity:0.6;margin:0 4px;">•</span>' +
            '<span style="font-size:13px;font-weight:400;opacity:0.85;">' + message + '</span>' +
            '</div>',
            'Login'
          );
          return;
        }

        showFallbackToast('👤 Utilisateur authentifié — ' + message, 'success', 3000);
      }

      // ════════════════════════════════════════════════════════════════
      // ✅ Repli interne (DOM/CSS pur) — utilisé UNIQUEMENT si Toastr n'a
      // pas pu être chargé. Reproduit le style des toasts (coin supérieur
      // droit, couleur selon le type, disparition automatique). Ne bloque
      // jamais l'interface (contrairement à alert()/confirm()).
      // ════════════════════════════════════════════════════════════════
      var _fallbackToastContainer = null;

      function showFallbackToast(message, type, duration) {
        var colors = {
          success: '#28a745',
          error: '#dc3545',
          warning: '#ffc107',
          info: '#17a2b8'
        };
        var color = colors[type] || colors.info;

        if (!_fallbackToastContainer) {
          _fallbackToastContainer = document.createElement('div');
          _fallbackToastContainer.style.cssText =
            'position:fixed;top:20px;right:20px;z-index:99999;' +
            'display:flex;flex-direction:column;gap:10px;max-width:320px;';
          document.body.appendChild(_fallbackToastContainer);
        }

        var toast = document.createElement('div');
        toast.style.cssText =
          'background:' + color + ';color:#fff;padding:14px 18px;border-radius:8px;' +
          'box-shadow:0 4px 16px rgba(0,0,0,0.25);font-size:13px;line-height:1.4;' +
          'opacity:0;transform:translateX(20px);transition:opacity .3s ease,transform .3s ease;';
        toast.textContent = message;

        _fallbackToastContainer.appendChild(toast);
        requestAnimationFrame(function () {
          toast.style.opacity = '1';
          toast.style.transform = 'translateX(0)';
        });

        setTimeout(function () {
          toast.style.opacity = '0';
          toast.style.transform = 'translateX(20px)';
          setTimeout(function () { toast.remove(); }, 300);
        }, duration);
      }

      // ════════════════════════════════════════════════════════════════
      // ✅ GARDE ANTI-RETOUR-ARRIÈRE CORRIGÉ
      // ════════════════════════════════════════════════════════════════
      // BUG CORRIGÉ : le garde anti-retour-arrière forçait systématiquement
      // location.replace('/auth/Login.aspx') sur tout événement "popstate",
      // y compris ceux déclenchés involontairement pendant la redirection
      // post-connexion (postback ASP.NET classique qui modifie le DOM/l'historique).
      // Résultat : le toast "Utilisateur authentifié" s'affichait, mais la
      // redirection vers le dashboard était annulée et on restait bloqué sur Login.
      //
      // Solution : on introduit un indicateur global "isRedirecting". Le garde
      // anti-retour ne renvoie vers Login.aspx que si AUCUNE redirection légitime
      // n'est en cours. La fonction redirectTo() (utilisée après connexion) lève
      // ce drapeau avant de naviguer.
      window.isRedirecting = false;

      function redirectTo(url) {
        window.isRedirecting = true;
        window.location.href = url;
      }

      (function () {
        history.pushState(null, document.title, location.href);
        window.addEventListener('popstate', function (event) {
          if (window.isRedirecting) {
            // Une redirection légitime est en cours (ex: après connexion) :
            // on laisse la navigation suivre son cours normalement.
            return;
          }
          history.pushState(null, document.title, location.href);
          location.replace('/auth/Login.aspx');
        }, false);
      })();
    </script>
  </head>

  <body class="hold-transition login-page"
    style="background: url('../img/bg.png') no-repeat center center fixed; background-size: cover;">
    <div class="login-box">
      <div class="card card-outline card-primary">
        <div class="card-header text-center">
          <img src="../img/logo1.png" alt="Logo" style="width: 130px; height: 100px; position: relative;" />
          <hr />
          <h4 style="color: #13245C">Unité de Facilitation de projet</h4>
          <hr />
          <!-- ✅ Nom du projet (lu depuis Web.config : ProjectCode) -->
          <div class="project-name-badge">
            <i class="fas fa-project-diagram"></i>
            <span class="project-label">Projet :</span>
            <span class="project-code">
              <%= AuthHelper.GetProjectCode(this.Context) %>
            </span>
          </div>

          <hr />
          <a class="h2"><b>Gestion de Stock</b></a>
        </div>
        <div class="card-body" style="background-color: #f6f6f6">
          <form id="form1" runat="server" style="gap:10px">
            <asp:HiddenField ID="hfTimerEnabled" runat="server" Value="false" />
            <asp:Label ID="lblLicenceInfo" runat="server" ForeColor="#856404" CssClass="mb-2 d-block licence-warning"
              Font-Bold="true" Visible="false"></asp:Label>
            <asp:Label ID="lblUserLimitInfo" runat="server" ForeColor="#dc3545" CssClass="mb-2 d-block licence-error"
              Font-Bold="true" Visible="false"></asp:Label>
            <asp:Label ID="lblMessage" runat="server" CssClass="mb-2 d-block error-box-red" Font-Bold="true"
              Visible="false"></asp:Label>
            <asp:Panel ID="pnlErreur" runat="server" Visible="false" CssClass="error-box">
              <asp:Label ID="lblErreur" runat="server"></asp:Label>
            </asp:Panel>
            <div class="input-group mb-3">
              <asp:TextBox ID="txtUsername" CssClass="form-control" runat="server" Placeholder="Nom d'utilisateur"
                autocomplete="username"></asp:TextBox>
              <div class="input-group-append">
                <div class="input-group-text">
                  <span class="fas fa-user"></span>
                </div>
              </div>
            </div>
            <div class="input-group mb-3">
              <asp:TextBox ID="txtPassword" CssClass="form-control" runat="server" TextMode="Password"
                Placeholder="Mot de passe" autocomplete="current-password"></asp:TextBox>
              <div class="input-group-append">
                <div class="input-group-text" id="togglePasswordBtn" style="cursor:pointer;"
                  title="Afficher / masquer le mot de passe">
                  <span class="fas fa-eye" id="togglePasswordIcon"></span>
                </div>
              </div>
            </div>
            <div id="capsLockWarning"
              style="display:none;color:#856404;background:#fff3cd;border:1px solid #ffc107;border-radius:4px;padding:4px 10px;font-size:12px;margin-bottom:12px;">
              <i class="fas fa-exclamation-triangle"></i> Verrouillage majuscules activé
            </div>
            <div class="row">
              <div class="col-12">
                <asp:Button ID="btnLogin" CssClass="btn btn-primary btn-block" runat="server" Text="Connexion"
                  OnClick="btnLogin_Click" OnClientClick="return onLoginButtonClick();" />
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- ═══ SPINNER ═══ -->
    <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
      <div class="spinner"></div>
    </div>

    <!-- ✅ SCRIPTS -->
    <!-- jQuery et Toastr déjà chargés dans le <head> (voir explication plus haut) -->
    <!-- Bootstrap 4 -->
    <script src="../pages/_assets/js/bootstrap.bundle.min.js?v=<%= AuthHelper.Version %>"></script>
    <!-- AdminLTE App -->
    <script src="../pages/_assets/js/adminlte.min.js?v=<%= AuthHelper.Version %>"></script>

    <script>
      // ✅ Démarrer le vérificateur de blocage
      if (typeof startBlockChecker === 'function') {
        startBlockChecker();
      }

      // ════════════════════════════════════════════════════════════════
      // ✅ NOUVELLE FONCTIONNALITÉ : Afficher / masquer le mot de passe
      // ════════════════════════════════════════════════════════════════
      document.addEventListener('DOMContentLoaded', function () {
        var toggleBtn = document.getElementById('togglePasswordBtn');
        var toggleIcon = document.getElementById('togglePasswordIcon');
        var passwordField = document.getElementById('<%= txtPassword.ClientID %>');

        if (toggleBtn && passwordField) {
          toggleBtn.addEventListener('click', function () {
            var isHidden = passwordField.type === 'password';
            passwordField.type = isHidden ? 'text' : 'password';
            toggleIcon.classList.toggle('fa-eye', !isHidden);
            toggleIcon.classList.toggle('fa-eye-slash', isHidden);
          });
        }
      });

      // ════════════════════════════════════════════════════════════════
      // ✅ NOUVELLE FONCTIONNALITÉ : Se souvenir de moi (nom d'utilisateur)
      // ════════════════════════════════════════════════════════════════
      const REMEMBER_KEY = 'gs_remembered_username';

      document.addEventListener('DOMContentLoaded', function () {
        var usernameField = document.getElementById('<%= txtUsername.ClientID %>');
        var rememberBox = document.getElementById('chkRememberMe');
        if (!usernameField || !rememberBox) return;

        // Pré-remplir si un nom d'utilisateur a été mémorisé précédemment
        var saved = localStorage.getItem(REMEMBER_KEY);
        if (saved && !usernameField.value) {
          usernameField.value = saved;
          rememberBox.checked = true;
        }
      });

      function persistRememberMe() {
        var usernameField = document.getElementById('<%= txtUsername.ClientID %>');
        var rememberBox = document.getElementById('chkRememberMe');
        if (!usernameField || !rememberBox) return;

        if (rememberBox.checked) {
          localStorage.setItem(REMEMBER_KEY, usernameField.value.trim());
        } else {
          localStorage.removeItem(REMEMBER_KEY);
        }
      }

      // ════════════════════════════════════════════════════════════════
      // ✅ NOUVELLE FONCTIONNALITÉ : Spinner sur le bouton pendant la connexion
      // ════════════════════════════════════════════════════════════════
      var loginSubmitting = false;

      function onLoginButtonClick() {
        if (loginSubmitting) {
          return false; // empêche un double-clic d'envoyer deux postbacks
        }

        var usernameField = document.getElementById('<%= txtUsername.ClientID %>');
        var passwordField = document.getElementById('<%= txtPassword.ClientID %>');

        // Validation minimale côté client
        if (!usernameField.value.trim() || !passwordField.value.trim()) {
          showNotification('Veuillez remplir tous les champs.', 'warning', 4000);
          return false;
        }

        persistRememberMe();

        var btn = document.getElementById('<%= btnLogin.ClientID %>');
        if (btn) {
          loginSubmitting = true;
          btn.dataset.originalText = btn.value;
          btn.value = '⏳ Connexion en cours...';
          btn.style.opacity = '0.75';
          btn.style.cursor = 'wait';
        }

        return true;
      }

      // ✅ Effet de focus sur les champs
      document.addEventListener('DOMContentLoaded', function () {
        var usernameField = document.getElementById('<%= txtUsername.ClientID %>');
        var passwordField = document.getElementById('<%= txtPassword.ClientID %>');

        if (usernameField) {
          usernameField.addEventListener('focus', function () {
            this.parentElement.parentElement.classList.add('focused');
          });
          usernameField.addEventListener('blur', function () {
            this.parentElement.parentElement.classList.remove('focused');
          });

          // Focus automatique intelligent
          if (usernameField.value && passwordField) {
            passwordField.focus();
          } else {
            usernameField.focus();
          }
        }

        if (passwordField) {
          passwordField.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') {
              document.getElementById('<%= btnLogin.ClientID %>').click();
            }
          });

          // ════════════════════════════════════════════════════════
          // ✅ NOUVELLE FONCTIONNALITÉ : avertissement Verrouillage Majuscules
          // ════════════════════════════════════════════════════════
          var capsWarning = document.getElementById('capsLockWarning');

          function checkCapsLock(e) {
            if (!capsWarning) return;
            var isCapsOn = typeof e.getModifierState === 'function' && e.getModifierState('CapsLock');
            capsWarning.style.display = isCapsOn ? 'block' : 'none';
          }
          passwordField.addEventListener('keydown', checkCapsLock);
          passwordField.addEventListener('keyup', checkCapsLock);
          passwordField.addEventListener('blur', function () {
            if (capsWarning) capsWarning.style.display = 'none';
          });
        }

        // ✅ Filet de sécurité : si la page se recharge après un postback
        var btn = document.getElementById('<%= btnLogin.ClientID %>');
        if (btn && !window.isRedirecting) {
          loginSubmitting = false;
          btn.style.opacity = '1';
          btn.style.cursor = 'pointer';
          if (btn.dataset.originalText) {
            btn.value = btn.dataset.originalText;
          }
        }
      });
    </script>
  </body>

  </html>
