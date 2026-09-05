function showToast(title, message, icon, timer) {
    icon = icon || 'success';
    timer = timer || 3000;
    if (typeof Swal === 'undefined') {
        console.warn('SweetAlert2 non chargé, fallback alert');
        alert((title || '') + (message ? '\n' + message : ''));
        return;
    }
    var finalTitle = (title || '').toString();
    var finalMessage = (message || '').toString();
    if (!finalTitle && !finalMessage) { finalTitle = 'Notification'; }
    if (!finalTitle && finalMessage) { finalTitle = finalMessage; finalMessage = ''; }
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
    Toast.fire({ icon: icon, title: finalTitle, text: finalMessage || undefined });
}

function showErrorToast(message) {
    showToast('Erreur', message, 'error');
}
function showSuccessToast(message) {
    showToast('Succès', message, 'success');
}
