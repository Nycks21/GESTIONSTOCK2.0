/**
 * ui.js - Interface utilisateur pour le module Salles
 */

'use strict';

// ─────────────────────────────────────────────
// SPINNER
// ─────────────────────────────────────────────
function forceHideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none';
    s.style.visibility = 'hidden';
    s.style.opacity = '0';
    s.setAttribute('aria-hidden', 'true');
}

function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.opacity = '1';
    s.style.visibility = 'visible';
    s.style.display = 'flex';
    s.removeAttribute('aria-hidden');
}

function hideSpinner() {
    forceHideSpinner();
}

// ─────────────────────────────────────────────
// PRELOADER
// ─────────────────────────────────────────────
function hidePreloader() {
    var pre = document.getElementById('preloader');
    if (!pre) return;
    setTimeout(function() {
        pre.style.opacity = '0';
        setTimeout(function() {
            pre.style.display = 'none';
            forceHideSpinner();
        }, 400);
    }, 600);
}

// ─────────────────────────────────────────────
// MODAL
// ─────────────────────────────────────────────
function showModal(id) {
    var m = document.getElementById(id);
    if (m) {
        m.style.display = 'flex';
        m.classList.add('open');
    }
}

function hideModal(id) {
    var m = document.getElementById(id);
    if (m) {
        m.style.display = 'none';
        m.classList.remove('open');
    }
}

function openAddSalleModal() {
    STATE.editId = null;
    resetSalleForm();
    var titleEl = document.getElementById('salleModalTitle');
    if (titleEl) {
        titleEl.innerHTML = '<i class="fas fa-door-open"></i> Ajouter une salle';
    }
    showModal('addSalleModal');
    document.getElementById('salleNumero').focus();
}

function closeAddSalleModal() {
    hideModal('addSalleModal');
    resetSalleForm();
    STATE.editId = null;
    clearFormErrors();
}

// ─────────────────────────────────────────────
// FORMULAIRE
// ─────────────────────────────────────────────
function resetSalleForm() {
    document.getElementById('salleEditId').value = '';
    document.getElementById('salleNumero').value = '';
    document.getElementById('salleCapacite').value = '30';
    document.getElementById('salleStatut').value = CONSTANTS.STATUT_ACTIF;
    clearFormErrors();
}

function showFieldError(fieldId, msg) {
    var field = document.getElementById(fieldId);
    if (!field) return;
    field.classList.add('is-invalid');
    var err = document.createElement('div');
    err.className = 'field-error';
    err.textContent = msg;
    field.parentNode.appendChild(err);
}

function clearFormErrors() {
    var invalids = document.querySelectorAll('#addSalleModal .is-invalid');
    for (var i = 0; i < invalids.length; i++) {
        invalids[i].classList.remove('is-invalid');
    }
    var errors = document.querySelectorAll('#addSalleModal .field-error');
    for (var j = 0; j < errors.length; j++) {
        if (errors[j].parentNode) {
            errors[j].parentNode.removeChild(errors[j]);
        }
    }
}

function validateSalleForm() {
    clearFormErrors();
    var ok = true;
    var numero = document.getElementById('salleNumero').value.trim();
    if (!numero) {
        showFieldError('salleNumero', 'Le numéro de salle est obligatoire.');
        ok = false;
    } else if (numero.length > 50) {
        showFieldError('salleNumero', 'Maximum 50 caractères.');
        ok = false;
    }
    var capa = parseInt(document.getElementById('salleCapacite').value, 10);
    if (isNaN(capa) || capa < 1 || capa > 200) {
        showFieldError('salleCapacite', 'La capacité doit être comprise entre 1 et 200.');
        ok = false;
    }
    return ok;
}

// ─────────────────────────────────────────────
// MESSAGE D'ERREUR GLOBAL
// ─────────────────────────────────────────────
function afficherErreurGlobale(msg) {
    var existing = document.getElementById('alertErreurGlobal');
    if (existing) existing.parentNode.removeChild(existing);

    var div = document.createElement('div');
    div.id = 'alertErreurGlobal';
    div.className = 'alert-erreur';
    div.innerHTML = '<i class="fas fa-exclamation-triangle"></i> ' + escHtml(msg) +
        '<button onclick="this.parentNode.remove()" style="float:right;background:none;border:none;cursor:pointer;font-size:16px;color:inherit;">&times;</button>';

    var section = document.getElementById('section-salles');
    if (section) section.insertBefore(div, section.firstChild);
}

// ─────────────────────────────────────────────
// CONTRÔLES UI
// ─────────────────────────────────────────────
function initUIControls() {
    var menuToggle = document.getElementById('menuToggle');
    var sidebar = document.getElementById('sidebar');
    var wrapper = document.getElementById('contentWrapper');
    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', function() {
            sidebar.classList.toggle('sidebar-collapsed');
            if (wrapper) wrapper.classList.toggle('sidebar-collapsed');
        });
    }

    var notifToggle = document.getElementById('notifToggle');
    var notifDropdown = document.getElementById('notifDropdown');
    if (notifToggle && notifDropdown) {
        notifToggle.addEventListener('click', function(e) {
            e.stopPropagation();
            var isOpen = notifDropdown.classList.toggle('show');
            notifToggle.setAttribute('aria-expanded', String(isOpen));
        });
    }
    document.addEventListener('click', function(e) {
        if (!notifDropdown || !notifToggle) return;
        if (!notifDropdown.contains(e.target) && !notifToggle.contains(e.target)) {
            notifDropdown.classList.remove('show');
            notifToggle.setAttribute('aria-expanded', 'false');
        }
    });

    var fsToggle = document.getElementById('fullscreenToggle');
    if (fsToggle) {
        fsToggle.addEventListener('click', function() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen &&
                    document.documentElement.requestFullscreen().catch(function() {});
            } else {
                document.exitFullscreen && document.exitFullscreen().catch(function() {});
            }
        });
    }

    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') closeAddSalleModal();
    });

    var modal = document.getElementById('addSalleModal');
    if (modal) {
        modal.addEventListener('click', function(e) {
            if (e.target === modal) closeAddSalleModal();
        });
    }
}

// ─────────────────────────────────────────────
// UTILITAIRES
// ─────────────────────────────────────────────
function escHtml(str) {
    return String(str == null ? '' : str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function dateDuJour() {
    var d = new Date();
    return d.getFullYear() + '-' +
        String(d.getMonth() + 1).padStart(2, '0') + '-' +
        String(d.getDate()).padStart(2, '0');
}

// Exposer les fonctions UI globalement
window.openAddSalleModal = openAddSalleModal;
window.closeAddSalleModal = closeAddSalleModal;
window.validateSalleForm = validateSalleForm;
window.resetSalleForm = resetSalleForm;
window.showModal = showModal;
window.hideModal = hideModal;