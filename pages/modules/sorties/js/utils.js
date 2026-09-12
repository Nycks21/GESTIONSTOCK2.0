// ============================================================
// UTILITAIRES — SORTIE
// ============================================================

function showToast(title, message, icon, timer) {
    icon = icon || 'success';
    timer = timer || 3000;
    if (typeof Swal === 'undefined') {
        console.warn('SweetAlert2 non chargé, fallback vers alert');
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
// ✅ HELPERS DE RÔLE (utilisateur connecté)
// ============================================================
// Récupère le ROLEID depuis le champ caché #hfUserRole.
// Retourne -1 si absent ou invalide.

function getCurrentUserRole() {
    // 1) Attribut data-user-role sur <body> (le plus simple)
    var body = document.body;
    if (body && body.getAttribute) {
        var v = parseInt(body.getAttribute('data-user-role'), 10);
        if (!isNaN(v)) return v;
    }
    // 2) Fallback : champ caché #hfUserRole
    var hidden = document.getElementById('hfUserRole');
    if (hidden) {
        var v2 = parseInt(hidden.value, 10);
        if (!isNaN(v2)) return v2;
    }
    return -1;
}

// Vérifie si l'utilisateur a l'un des rôles passés en argument
//   userHasRole(3)     → true si ROLEID === 3 (Logisticien)
//   userHasRole(1, 3)  → true si Admin OU Logisticien
function userHasRole() {
    var current = getCurrentUserRole();
    if (current < 0) return false;
    for (var i = 0; i < arguments.length; i++) {
        if (current === arguments[i]) return true;
    }
    return false;
}

// Raccourcis explicites
function isSuperAdmin()  { return getCurrentUserRole() === 0; }
function isAdmin()       { return getCurrentUserRole() === 1; }
function isUser()        { return getCurrentUserRole() === 2; }
function isLogisticien() { return getCurrentUserRole() === 3; }
function isComptable()   { return getCurrentUserRole() === 4; }

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.showToast = showToast;
window.debounce = debounce;

window.getCurrentUserRole = getCurrentUserRole;
window.userHasRole = userHasRole;
window.isSuperAdmin = isSuperAdmin;
window.isAdmin = isAdmin;
window.isUser = isUser;
window.isLogisticien = isLogisticien;
window.isComptable = isComptable;
