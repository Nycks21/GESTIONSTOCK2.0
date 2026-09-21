// ============================================================
// UTILITAIRES GLOBAUX + i18n
// ============================================================

function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

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
        finalTitle = _t('message.warning') || 'Notification';
    }

    if (!finalTitle && finalMessage) {
        finalTitle = finalMessage;
        finalMessage = '';
    }

    var Toast = Swal.mixin({
        toast: true,
        position: 'top-end',
        showConfirmButton: false,
        timer: 8000,
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

function showErrorToast(message) {
    showToast(_t('message.error'), message, 'error');
}

function showSuccessToast(message) {
    showToast(_t('message.success'), message, 'success');
}

window.showToast = showToast;
window.showErrorToast = showErrorToast;
window.showSuccessToast = showSuccessToast;
