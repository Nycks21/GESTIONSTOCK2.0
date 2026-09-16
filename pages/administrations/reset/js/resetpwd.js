"use strict";

/* ============================================================
   RESETPWD — Page dédiée resetpwd.aspx
   Ouvre automatiquement le modal de changement de mot de passe,
   valide côté client, envoie au handler via fetch (FormData),
   puis redirige vers index.aspx (succès OU annulation).
   ============================================================ */

(function () {
  // ----------------------------------------------------------
  // Configuration lue depuis le DOM (valeurs calculées par .aspx.cs)
  // ----------------------------------------------------------
  function getConfig() {
    var cfg = document.getElementById("pwdConfig");
    return {
      pwdUrl:
        (cfg && cfg.dataset.pwdUrl) ||
        "/pages/administrations/reset/api/pwdUpdate",
      homeUrl: (cfg && cfg.dataset.homeUrl) || "/pages/accueil/index.aspx",
    };
  }

  // ----------------------------------------------------------
  // Modal : ouverture / fermeture
  // ----------------------------------------------------------
  function openChangePasswordModal() {
    var modal = document.getElementById("changePwdModal");
    if (!modal) return;

    var form = document.getElementById("changePwdForm");
    if (form) form.reset();

    clearError();
    resetStrength();
    setLoader(false);

    modal.classList.add("show");
    modal.setAttribute("aria-hidden", "false");
    document.body.classList.add("modal-open");

    var first = document.getElementById("pwdOld");
    if (first)
      setTimeout(function () {
        first.focus();
      }, 80);
  }

  function closeChangePasswordModal() {
    var modal = document.getElementById("changePwdModal");
    if (!modal) return;

    modal.classList.remove("show");
    modal.setAttribute("aria-hidden", "true");
    document.body.classList.remove("modal-open");

    // Nettoyage des champs sensibles
    ["pwdOld", "pwdNew", "pwdConfirm"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) {
        el.value = "";
        el.type = "password";
      }
    });
  }

  // ----------------------------------------------------------
  // Redirection vers index.aspx
  // ----------------------------------------------------------
  function redirectToHome() {
    window.location.href = getConfig().homeUrl;
  }

  // ----------------------------------------------------------
  // Affichage / masquage d'un mot de passe
  // ----------------------------------------------------------
  function togglePassword(button) {
    var inputId = button.dataset.target;
    if (!inputId) return;

    var input = document.getElementById(inputId);
    var icon = button.querySelector("i");
    if (!input) return;

    if (input.type === "password") {
      input.type = "text";
      if (icon) {
        icon.classList.remove("fa-eye");
        icon.classList.add("fa-eye-slash");
      }
    } else {
      input.type = "password";
      if (icon) {
        icon.classList.remove("fa-eye-slash");
        icon.classList.add("fa-eye");
      }
    }
  }

  // ----------------------------------------------------------
  // Robustesse du mot de passe
  // ----------------------------------------------------------
  function computeStrength(pwd) {
    if (!pwd) return { level: 0, label: "Robustesse : —", cls: "" };

    var score = 0;
    if (pwd.length >= 8) score++;
    if (pwd.length >= 12) score++;
    if (/[a-z]/.test(pwd)) score++;
    if (/[A-Z]/.test(pwd)) score++;
    if (/[0-9]/.test(pwd)) score++;
    if (/[^A-Za-z0-9]/.test(pwd)) score++;

    if (pwd.length < 8) return { level: 1, label: "Faible", cls: "weak" };
    if (score <= 3) return { level: 2, label: "Moyen", cls: "medium" };
    return { level: 3, label: "Fort", cls: "strong" };
  }

  function updateStrength() {
    var input = document.getElementById("pwdNew");
    var fill = document.getElementById("pwdStrengthFill");
    var text = document.getElementById("pwdStrengthText");
    if (!input || !fill || !text) return;

    var s = computeStrength(input.value);

    fill.style.width = s.level * 33.33 + "%";
    fill.className = s.cls ? s.cls : "";

    text.className = "pwd-strength-text" + (s.cls ? " " + s.cls : "");
    text.textContent = "Robustesse : " + s.label;
  }

  function resetStrength() {
    var fill = document.getElementById("pwdStrengthFill");
    var text = document.getElementById("pwdStrengthText");
    if (fill) {
      fill.style.width = "0%";
      fill.className = "";
    }
    if (text) {
      text.className = "pwd-strength-text";
      text.textContent = "Robustesse : —";
    }
  }

  // ----------------------------------------------------------
  // Erreur / loader
  // ----------------------------------------------------------
  function showError(msg) {
    var box = document.getElementById("pwdErrorBox");
    if (!box) return;
    box.textContent = msg;
    box.style.display = "block";
  }

  function clearError() {
    var box = document.getElementById("pwdErrorBox");
    if (!box) return;
    box.textContent = "";
    box.style.display = "none";
  }

  function setLoader(loading) {
    var btn = document.getElementById("btnSavePwd");
    var loader = document.getElementById("pwdLoader");
    var saveIcon = document.getElementById("pwdSaveIcon");
    if (btn) btn.disabled = !!loading;
    if (loader) loader.style.display = loading ? "inline-block" : "none";
    if (saveIcon) saveIcon.style.display = loading ? "none" : "inline-block";
  }

  // ----------------------------------------------------------
  // Validation côté client
  // ----------------------------------------------------------
  function validateResetPassword() {
    var oldPwd = (document.getElementById("pwdOld") || {}).value || "";
    var newPwd = (document.getElementById("pwdNew") || {}).value || "";
    var confirmPwd = (document.getElementById("pwdConfirm") || {}).value || "";

    if (!oldPwd.trim())
      return {
        ok: false,
        message: "Veuillez saisir votre ancien mot de passe.",
      };
    if (!newPwd.trim())
      return { ok: false, message: "Veuillez saisir le nouveau mot de passe." };
    if (newPwd.length < 8)
      return {
        ok: false,
        message: "Le nouveau mot de passe doit contenir au moins 8 caractères.",
      };
    if (!confirmPwd.trim())
      return {
        ok: false,
        message: "Veuillez confirmer le nouveau mot de passe.",
      };
    if (newPwd !== confirmPwd)
      return {
        ok: false,
        message:
          "Le nouveau mot de passe et sa confirmation ne correspondent pas.",
      };
    if (newPwd === oldPwd)
      return {
        ok: false,
        message: "Le nouveau mot de passe doit être différent de l'ancien.",
      };

    return { ok: true };
  }

  // ----------------------------------------------------------
  // Soumission AJAX (FormData — même mécanisme que le reste de l'app)
  // ----------------------------------------------------------
  function submitResetPassword() {
    clearError();

    var v = validateResetPassword();
    if (!v.ok) {
      showError(v.message);
      return;
    }

    var cfg = getConfig();

    var fd = new FormData();
    fd.append("oldPwd", document.getElementById("pwdOld").value);
    fd.append("newPwd", document.getElementById("pwdNew").value);
    fd.append("confirmPwd", document.getElementById("pwdConfirm").value);

    setLoader(true);

    fetch(cfg.pwdUrl, {
      method: "POST",
      credentials: "same-origin",
      headers: { "X-Requested-With": "XMLHttpRequest" },
      body: fd,
    })
      .then(function (r) {
        return r.json().catch(function () {
          return { success: false, message: "Réponse serveur invalide." };
        });
      })
      .then(function (res) {
        setLoader(false);
        if (res && res.success) {
          // Succès → notification persistante jusqu'au clic sur OK
          if (window.Swal && typeof Swal.fire === "function") {
            Swal.fire({
              icon: "success",
              title: "Succès",
              text: "Votre mot de passe a été mis à jour.",
              confirmButtonText: "OK",
              confirmButtonColor: "#28a745",
              allowOutsideClick: false, // clic à l'extérieur : ignoré
              allowEscapeKey: false, // touche Échap : ignorée
            }).then(function () {
              redirectToHome();
            });
          } else {
            alert(res.message || "Mot de passe mis à jour.");
            redirectToHome();
          }
        } else {
          // Erreur métier → on reste sur la page, message dans le modal
          showError((res && res.message) || "Erreur lors du traitement.");
        }
      })
      .catch(function (err) {
        setLoader(false);
        showError(
          "Erreur réseau : " + (err && err.message ? err.message : "inconnue"),
        );
      });
  }

  // ----------------------------------------------------------
  // Bind des événements (une seule fois)
  // ----------------------------------------------------------
  function bindEvents() {
    // Bouton œil — délégation d'événement
    document.addEventListener("click", function (e) {
      var eye = e.target.closest && e.target.closest(".pwd-toggle-eye");
      if (eye) {
        e.preventDefault();
        togglePassword(eye);
      }
    });

    var btnSave = document.getElementById("btnSavePwd");
    if (btnSave) btnSave.addEventListener("click", submitResetPassword);

    var btnCancel = document.getElementById("pwdCancelBtn");
    if (btnCancel)
      btnCancel.addEventListener("click", function () {
        closeChangePasswordModal();
        redirectToHome();
      });

    var btnClose = document.getElementById("pwdModalClose");
    if (btnClose)
      btnClose.addEventListener("click", function () {
        closeChangePasswordModal();
        redirectToHome();
      });

    // Échap : ferme + redirige (comme Annuler)
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" || e.keyCode === 27) {
        var modal = document.getElementById("changePwdModal");
        if (modal && modal.classList.contains("show")) {
          closeChangePasswordModal();
          redirectToHome();
        }
      }
    });

    // Robustesse du mot de passe
    var pwdNew = document.getElementById("pwdNew");
    if (pwdNew) pwdNew.addEventListener("input", updateStrength);

    // Lien "cliquez ici" pour ré-ouvrir le modal si jamais il s'est fermé
    var reopen = document.getElementById("reopenPwdModalLink");
    if (reopen)
      reopen.addEventListener("click", function (e) {
        e.preventDefault();
        openChangePasswordModal();
      });
  }

  // ----------------------------------------------------------
  // Init
  // ----------------------------------------------------------
  function initResetPassword() {
    bindEvents();
    // Ouverture automatique (léger délai pour laisser l'animation se faire)
    setTimeout(openChangePasswordModal, 60);
  }

  // Expose globalement
  window.initResetPassword = initResetPassword;
  window.openChangePasswordModal = openChangePasswordModal;
  window.closeChangePasswordModal = closeChangePasswordModal;
  window.togglePassword = togglePassword;
  window.checkPasswordStrength = computeStrength;
  window.validateResetPassword = validateResetPassword;
  window.submitResetPassword = submitResetPassword;
  window.redirectToHome = redirectToHome;

  // Auto-init
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initResetPassword);
  } else {
    initResetPassword();
  }
})();
