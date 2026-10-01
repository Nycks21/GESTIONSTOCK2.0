<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Login.aspx.cs" Inherits="Login" %>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
    <title>Connexion — UFP</title>

    <!-- Google Font -->
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

    <script src="../pages/_assets/js/jquery.min.js?v=<%= AuthHelper.Version %>"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/toastr.js/latest/toastr.min.js"></script>

    <style>
        .d-block { display: block; }
        .mb-2 { margin-bottom: 8px; }

        .toast-login {
            background-color: #28a745 !important;
            border-radius: 12px !important;
            box-shadow: 0 12px 32px rgba(40, 167, 69, 0.35) !important;
        }
        .toast-login .toast-title { font-weight: 700; font-size: 15px; }
        .toast-login .toast-message { font-size: 13px; opacity: 0.95; }

        /* ✅ Toast toujours au-dessus de l'overlay de chargement */
        #toast-container { z-index: 9999 !important; }

        body.login-page {
            background: url('../img/bg.png') no-repeat center center fixed !important;
            background-size: cover !important;
            position: relative;
            min-height: 100vh;
        }
        body.login-page::before {
            content: '';
            position: fixed;
            inset: 0;
            z-index: 0;
            background:
                radial-gradient(ellipse at 15% 10%, rgba(249, 214, 90, 0.18), transparent 55%),
                radial-gradient(ellipse at 85% 90%, rgba(26, 43, 86, 0.42), transparent 60%),
                linear-gradient(135deg, rgba(26, 43, 86, 0.55), rgba(10, 20, 45, 0.65));
            pointer-events: none;
        }
        body.login-page .login-box,
        body.login-page .logo-zoom-overlay,
        body.login-page .login-loading-overlay {
            position: relative;
            z-index: 2;
        }
        body.login-page .login-corner-logo { z-index: 100; }
    </style>

    <script>
        toastr.options = {
            "closeButton": true, "debug": false, "newestOnTop": false,
            "progressBar": true, "positionClass": "toast-top-right",
            "preventDuplicates": false, "onclick": null,
            "showDuration": 300, "hideDuration": 1000,
            "timeOut": 10000, "extendedTimeOut": 10000,
            "showEasing": "swing", "hideEasing": "linear",
            "showMethod": "fadeIn", "hideMethod": "fadeOut"
        };

        function showNotification(message, type, duration) {
            type = type || 'info';
            duration = duration || 10000;
            if (typeof toastr !== 'undefined') {
                toastr.options.timeOut = duration;
                toastr.options.extendedTimeOut = Math.min(duration, 1000);
                switch (type) {
                    case 'success': toastr.success(message, '✅ Succès'); break;
                    case 'error':   toastr.error(message,   '❌ Erreur');  break;
                    case 'warning': toastr.warning(message, '⚠️ Attention'); break;
                    default:        toastr.info(message,    'ℹ️ Information');
                }
                return;
            }
            showFallbackToast(message, type, duration);
        }

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
                    '</div>', 'Login');
                return;
            }
            showFallbackToast('👤 Utilisateur authentifié — ' + message, 'success', 3000);
        }

        var _fallbackToastContainer = null;
        function showFallbackToast(message, type, duration) {
            var colors = { success:'#28a745', error:'#dc3545', warning:'#ffc107', info:'#17a2b8' };
            var color = colors[type] || colors.info;
            if (!_fallbackToastContainer) {
                _fallbackToastContainer = document.createElement('div');
                _fallbackToastContainer.style.cssText =
                    'position:fixed;top:20px;right:20px;z-index:9999;' +
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
                toast.style.opacity = '1'; toast.style.transform = 'translateX(0)';
            });
            setTimeout(function () {
                toast.style.opacity = '0'; toast.style.transform = 'translateX(20px)';
                setTimeout(function () { toast.remove(); }, 300);
            }, duration);
        }

        // ════════════════════════════════════════════════════════════
        // ✅ GARDE ANTI-RETOUR-ARRIÈRE (logique d'origine préservée)
        // ════════════════════════════════════════════════════════════
        window.isRedirecting = false;

        (function () {
            history.pushState(null, document.title, location.href);
            window.addEventListener('popstate', function () {
                if (window.isRedirecting) return;
                history.pushState(null, document.title, location.href);
                location.replace('/auth/Login.aspx');
            }, false);
        })();
    </script>
</head>

<body class="hold-transition login-page">

    <div class="login-box">
        <div class="login-card">

            <div class="login-card__header">
                <div class="login-logo-wrap">
                    <img src="../img/logo1.png" alt="Logo UFP" class="login-logo" />
                </div>

                <h1 class="title-anim" aria-label="Unité de Facilitation de Projet">
                    <span aria-hidden="true"><span class="c-yellow">U</span>nité de <span class="c-navy">F</span>acilitation de <span class="c-yellow">P</span>rojet</span>
                </h1>

                <div class="project-name-badge">
                    <i class="fas fa-project-diagram"></i>
                    <span class="project-label">Projet :</span>
                    <span class="project-code"><%= AuthHelper.GetProjectCode(this.Context) %></span>
                </div>

                <div class="login-subtitle">
                    <span class="login-subtitle__line"></span>
                    <span class="login-subtitle__text">Gestion de Stock</span>
                    <span class="login-subtitle__line"></span>
                </div>
            </div>

            <div class="login-card__body">
                <form id="form1" runat="server">

                    <asp:HiddenField ID="hfTimerEnabled" runat="server" Value="false" />

                    <asp:Label ID="lblLicenceInfo" runat="server" ForeColor="#856404"
                               CssClass="mb-2 d-block licence-warning" Font-Bold="true" Visible="false"></asp:Label>
                    <asp:Label ID="lblUserLimitInfo" runat="server" ForeColor="#dc3545"
                               CssClass="mb-2 d-block licence-error" Font-Bold="true" Visible="false"></asp:Label>
                    <asp:Label ID="lblMessage" runat="server"
                               CssClass="mb-2 d-block error-box-red" Font-Bold="true" Visible="false"></asp:Label>
                    <asp:Panel ID="pnlErreur" runat="server" Visible="false" CssClass="error-box">
                        <asp:Label ID="lblErreur" runat="server"></asp:Label>
                    </asp:Panel>

                    <!-- Champ Identifiant -->
                    <div class="modern-field">
                        <span class="modern-field__icon"><i class="fas fa-user"></i></span>
                        <asp:TextBox ID="txtUsername" CssClass="modern-field__input" runat="server"
                                     Placeholder="Nom d'utilisateur ou email"
                                     autocomplete="username"></asp:TextBox>
                    </div>

                    <!-- Champ Mot de passe -->
                    <div class="modern-field">
                        <span class="modern-field__icon"><i class="fas fa-lock"></i></span>
                        <asp:TextBox ID="txtPassword" CssClass="modern-field__input" runat="server"
                                     TextMode="Password" Placeholder="Mot de passe"
                                     autocomplete="current-password"></asp:TextBox>
                        <button type="button" class="modern-field__toggle" id="togglePasswordBtn"
                                title="Afficher / masquer le mot de passe" aria-label="Afficher le mot de passe">
                            <i class="fas fa-eye" id="togglePasswordIcon"></i>
                        </button>
                    </div>

                    <!-- Avertissement Caps Lock -->
                    <div id="capsLockWarning" class="caps-warning">
                        <i class="fas fa-exclamation-triangle"></i>
                        <span>Verrouillage majuscules activé</span>
                    </div>

                    <!-- Bouton Connexion (enveloppé pour le reflet lumineux) -->
                    <div class="btn-login-wrap">
                        <asp:Button ID="btnLogin" CssClass="btn-login" runat="server" Text="Se connecter"
                                    OnClick="btnLogin_Click" OnClientClick="return onLoginButtonClick();" />
                    </div>

                    <!-- Badge version -->
                    <div class="login-version-badge">
                        <i class="fas fa-code-branch"></i>
                        <span>Version <%= AuthHelper.Version %></span>
                    </div>
                </form>
            </div>

            <div class="login-card__footer">
                <i class="fas fa-shield-alt"></i>
                <span>Connexion sécurisée · MOZH &copy; <%= DateTime.Now.Year %></span>
            </div>
        </div>
    </div>

    <script src="../pages/_assets/js/bootstrap.bundle.min.js?v=<%= AuthHelper.Version %>"></script>
    <script src="../pages/_assets/js/adminlte.min.js?v=<%= AuthHelper.Version %>"></script>

    <script>
        if (typeof startBlockChecker === 'function') startBlockChecker();

        // ════════════════════════════════════════════════════════════
        // Toggle password
        // ════════════════════════════════════════════════════════════
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
                    toggleBtn.setAttribute('aria-label', isHidden ? 'Masquer le mot de passe' : 'Afficher le mot de passe');
                });
            }
        });

        // ════════════════════════════════════════════════════════════
        // Remember me
        // ════════════════════════════════════════════════════════════
        const REMEMBER_KEY = 'gs_remembered_username';
        document.addEventListener('DOMContentLoaded', function () {
            var usernameField = document.getElementById('<%= txtUsername.ClientID %>');
            var rememberBox = document.getElementById('chkRememberMe');
            if (!usernameField || !rememberBox) return;
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
            if (rememberBox.checked) localStorage.setItem(REMEMBER_KEY, usernameField.value.trim());
            else localStorage.removeItem(REMEMBER_KEY);
        }

        // ════════════════════════════════════════════════════════════
        // LOGIN SUBMIT — désactivation différée
        // ════════════════════════════════════════════════════════════
        var loginSubmitting = false;

        function onLoginButtonClick() {
            if (loginSubmitting) return false;

            var usernameField = document.getElementById('<%= txtUsername.ClientID %>');
            var passwordField = document.getElementById('<%= txtPassword.ClientID %>');

            if (!usernameField.value.trim() || !passwordField.value.trim()) {
                showNotification('Veuillez remplir tous les champs.', 'warning', 5000);
                return false;
            }

            persistRememberMe();

            setTimeout(function () {
                var btn = document.getElementById('<%= btnLogin.ClientID %>');
                if (!btn) return;
                loginSubmitting = true;
                btn.dataset.originalText = btn.value;
                btn.value = '⏳ Connexion…';
                btn.classList.add('btn-login--loading');
                btn.disabled = true;
            }, 0);

            return true;
        }

        // ════════════════════════════════════════════════════════════
        // ✅ TRANSITION DE CONNEXION RÉUSSIE
        // ─────────────────────────────────────────────────────────
        // Appelée depuis Login.aspx.cs APRÈS confirmation serveur
        // de l'authentification. Ne touche à AUCUNE logique métier.
        //
        // Actions :
        //   1. Floute le contenu de la page (body.is-loading)
        //   2. Affiche l'overlay sombre + le spinner
        //   3. Désactive tous les champs pour empêcher toute interaction
        //
        // Le toast est déjà affiché par le serveur AVANT cet appel
        // → il reste visible au-dessus (z-index 9999 > 9998).
        // ════════════════════════════════════════════════════════════
        function showLoginLoadingSpinner() {
            var overlay = document.getElementById('loginLoadingOverlay');
            if (!overlay) return;
            if (overlay.classList.contains('is-active')) return;  // anti-double

            // 1. Flou de la page + blocage global
            document.body.classList.add('is-loading');

            // 2. Overlay + spinner
            overlay.classList.add('is-active');
            overlay.setAttribute('aria-hidden', 'false');

            // 3. Blocage des inputs
            var form = document.getElementById('form1');
            if (form) {
                var fields = form.querySelectorAll('input, select, textarea, button');
                for (var i = 0; i < fields.length; i++) fields[i].disabled = true;
            }
        }

        // ════════════════════════════════════════════════════════════
        // Focus effects + Caps Lock + Enter + Reset après postback
        // ════════════════════════════════════════════════════════════
        document.addEventListener('DOMContentLoaded', function () {
            var usernameField = document.getElementById('<%= txtUsername.ClientID %>');
            var passwordField = document.getElementById('<%= txtPassword.ClientID %>');

            function bindFocus(el) {
                if (!el) return;
                el.addEventListener('focus', function () { this.closest('.modern-field').classList.add('is-focused'); });
                el.addEventListener('blur',  function () { this.closest('.modern-field').classList.remove('is-focused'); });
            }
            bindFocus(usernameField);
            bindFocus(passwordField);

            if (usernameField && passwordField) {
                if (usernameField.value) passwordField.focus(); else usernameField.focus();
            }

            if (passwordField) {
                passwordField.addEventListener('keydown', function (e) {
                    if (e.key === 'Enter') document.getElementById('<%= btnLogin.ClientID %>').click();
                });

                var capsWarning = document.getElementById('capsLockWarning');
                function checkCapsLock(e) {
                    if (!capsWarning) return;
                    var isCapsOn = typeof e.getModifierState === 'function' && e.getModifierState('CapsLock');
                    capsWarning.classList.toggle('is-visible', isCapsOn);
                }
                passwordField.addEventListener('keydown', checkCapsLock);
                passwordField.addEventListener('keyup', checkCapsLock);
                passwordField.addEventListener('blur', function () {
                    if (capsWarning) capsWarning.classList.remove('is-visible');
                });
            }

            // Reset du bouton après rechargement (postback échoué)
            var btn = document.getElementById('<%= btnLogin.ClientID %>');
            if (btn && !window.isRedirecting) {
                loginSubmitting = false;
                btn.classList.remove('btn-login--loading');
                btn.disabled = false;
                if (btn.dataset.originalText) btn.value = btn.dataset.originalText;
                else btn.value = 'Se connecter';
            }
        });
    </script>

    <!-- ═══════════════════════════════════════════════════════════════
         LOGO COIN BAS DROIT + Modale Zoom
         ═══════════════════════════════════════════════════════════════ -->
    <div class="login-corner-logo" id="loginLogoTrigger" role="button" tabindex="0"
         aria-label="Agrandir le logo" title="Cliquer pour agrandir">
        <img src="../img/logo2.png" alt="Logo" />
    </div>

    <div id="logoZoomOverlay" class="logo-zoom-overlay" aria-hidden="true"
         role="dialog" aria-modal="true" aria-label="Logo agrandi">
        <button type="button" class="logo-zoom-close" id="logoZoomClose" aria-label="Fermer">&times;</button>
        <img src="../img/logo2.png" alt="Logo" class="logo-zoom-image" />
    </div>

    <script>
        (function () {
            'use strict';
            var trigger = document.getElementById('loginLogoTrigger');
            var overlay = document.getElementById('logoZoomOverlay');
            var closeBtn = document.getElementById('logoZoomClose');
            if (!trigger || !overlay) return;

            function openZoom() {
                overlay.classList.add('show');
                overlay.setAttribute('aria-hidden', 'false');
                document.body.style.overflow = 'hidden';
                if (closeBtn) closeBtn.focus();
            }
            function closeZoom() {
                overlay.classList.remove('show');
                overlay.setAttribute('aria-hidden', 'true');
                document.body.style.overflow = '';
                trigger.focus();
            }
            trigger.addEventListener('click', function (e) { e.preventDefault(); openZoom(); });
            trigger.addEventListener('keydown', function (e) {
                if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openZoom(); }
            });
            if (closeBtn) closeBtn.addEventListener('click', function (e) { e.stopPropagation(); closeZoom(); });
            overlay.addEventListener('click', function (e) { if (e.target === overlay) closeZoom(); });
            document.addEventListener('keydown', function (e) {
                if (e.key === 'Escape' && overlay.classList.contains('show')) closeZoom();
            });
        })();
    </script>

    <!-- ═══════════════════════════════════════════════════════════════
         OVERLAY DE TRANSITION — affiché uniquement après
         authentification réussie.
         z-index: 9998 (sous le toast qui est à 9999)
         ═══════════════════════════════════════════════════════════════ -->
    <div id="loginLoadingOverlay" class="login-loading-overlay"
         aria-hidden="true" role="status" aria-live="polite">
        <div class="login-loading-content">
            <div class="login-loading-spinner">
                <div class="login-loading-spinner__ring"></div>
                <div class="login-loading-spinner__icon">
                    <i class="fas fa-check"></i>
                </div>
            </div>
            <div class="login-loading-text">
                <h3>Connexion réussie</h3>
                <p>Chargement de votre espace…</p>
            </div>
            <div class="login-loading-bar">
                <div class="login-loading-bar__fill"></div>
            </div>
        </div>
    </div>

</body>
</html>
