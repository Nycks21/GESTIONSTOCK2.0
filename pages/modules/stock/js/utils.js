// ============================================================
// UTILITAIRES — STOCK
// ============================================================

function showToast(title, message, icon, timer) {
    icon = icon || 'success';
    timer = timer || 3000;
    if (typeof Swal === 'undefined') {
        console.warn('SweetAlert2 non chargé');
        alert((title || '') + (message ? '\n' + message : ''));
        return;
    }
    var finalTitle = (title || '').toString();
    var finalMessage = (message || '').toString();
    if (!finalTitle && !finalMessage) {
        finalTitle = 'Notification';
    }
    if (!finalTitle && finalMessage) {
        finalTitle = finalMessage;
        finalMessage = '';
    }
    var Toast = Swal.mixin({
        toast: true,
        position: 'top-end',
        showConfirmButton: false,
        timer: timer,
        timerProgressBar: true,
        didOpen: function (toast) {
            toast.addEventListener('mouseenter', Swal.stopTimer);
            toast.addEventListener('mouseleave', Swal.resumeTimer);
        }
    });
    Toast.fire({
        icon: icon,
        title: finalTitle,
        text: finalMessage || undefined
    });
}

function showErrorToast(message)   { showToast('Erreur', message, 'error'); }
function showSuccessToast(message) { showToast('Succès', message, 'success'); }

function debounce(fn, delay) {
    var timer;
    return function () {
        var args = arguments;
        clearTimeout(timer);
        timer = setTimeout(function () {
            fn.apply(this, args);
        }.bind(this), delay);
    };
}

// ============================================================
// ✅ HELPERS DE RÔLE (utilisateur connecté) — STOCK
// ============================================================
// Lecture du ROLEID dans cet ordre :
//   1) attribut data-user-role sur <body>  (injecté par le serveur)
//   2) champ caché #hfUserRole             (fallback)
//   3) variable globale window.CURRENT_USER_ROLE (fallback)
// Retourne -1 si introuvable. Gère les valeurs numériques ET chaînes.

function getCurrentUserRole() {
    // 1) Attribut data-user-role sur <body>
    var body = document.body;
    if (body && body.getAttribute) {
        var attr = body.getAttribute('data-user-role');
        if (attr !== null && attr !== '') {
            var v1 = parseInt(attr, 10);
            if (!isNaN(v1)) return v1;
        }
    }

    // 2) Champ caché #hfUserRole
    var hidden = document.getElementById('hfUserRole');
    if (hidden && hidden.value !== undefined && hidden.value !== null && hidden.value !== '') {
        var v2 = parseInt(hidden.value, 10);
        if (!isNaN(v2)) return v2;
    }

    // 3) Variable globale
    if (typeof window.CURRENT_USER_ROLE !== 'undefined' && window.CURRENT_USER_ROLE !== null) {
        var v3 = parseInt(window.CURRENT_USER_ROLE, 10);
        if (!isNaN(v3)) return v3;
    }

    return -1;
}

function userHasRole() {
    var current = getCurrentUserRole();
    if (current < 0) return false;
    for (var i = 0; i < arguments.length; i++) {
        if (current === arguments[i]) return true;
    }
    return false;
}

function isSuperAdmin()  { return getCurrentUserRole() === 0; }
function isAdmin()       { return getCurrentUserRole() === 1; }
function isUser()        { return getCurrentUserRole() === 2; }
function isLogisticien() { return getCurrentUserRole() === 3; }
function isComptable()   { return getCurrentUserRole() === 4; }

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.showToast = showToast;
window.showErrorToast = showErrorToast;
window.showSuccessToast = showSuccessToast;
window.debounce = debounce;

window.getCurrentUserRole = getCurrentUserRole;
window.userHasRole = userHasRole;
window.isSuperAdmin = isSuperAdmin;
window.isAdmin = isAdmin;
window.isUser = isUser;
window.isLogisticien = isLogisticien;
window.isComptable = isComptable;
