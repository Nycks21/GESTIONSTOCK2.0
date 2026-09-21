// utils.js — Helpers génériques

// ============================================================
// Helper i18n : T(key, fallback, params)
// ============================================================
function T(key, fallback, params) {
    var v;
    try {
        if (typeof window.t === 'function') v = window.t(key, params);
    } catch (e) { v = key; }
    if (v && v !== key) return v;
    return (fallback !== undefined) ? fallback : key;
}

// ============================================================
// TOAST
// ============================================================
function showToast(title, message, icon, timer) {
    icon  = icon  || 'success';
    timer = timer || 3000;
    if (typeof Swal === 'undefined') {
        console.warn('SweetAlert2 non chargé, fallback vers alert');
        alert((title || '') + (message ? '\n' + message : ''));
        return;
    }
    var finalTitle   = (title   || '').toString();
    var finalMessage = (message || '').toString();
    if (!finalTitle && !finalMessage) {
        finalTitle = T('message.warning', 'Notification');
    }
    if (!finalTitle && finalMessage) {
        finalTitle   = finalMessage;
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
// HELPERS DE RÔLE
// ============================================================
function getCurrentUserRole() {
    var body = document.body;
    if (body && body.getAttribute) {
        var v = parseInt(body.getAttribute('data-user-role'), 10);
        if (!isNaN(v)) return v;
    }
    var hidden = document.getElementById('hfUserRole');
    if (hidden) {
        var v2 = parseInt(hidden.value, 10);
        if (!isNaN(v2)) return v2;
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
// EXPOSITIONS
// ============================================================
window.T         = T;
window.showToast = showToast;
window.debounce  = debounce;

window.getCurrentUserRole = getCurrentUserRole;
window.userHasRole        = userHasRole;
window.isSuperAdmin       = isSuperAdmin;
window.isAdmin            = isAdmin;
window.isUser             = isUser;
window.isLogisticien      = isLogisticien;
window.isComptable        = isComptable;
