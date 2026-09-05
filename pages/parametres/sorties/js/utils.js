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

window.showToast = showToast;
window.debounce = debounce;
