'use strict';

function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (s) s.style.display = 'flex';
}

function hideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (s) s.style.display = 'none';
}

function showToast(message, type) {
    type = type || 'info';
    if (typeof Swal !== 'undefined') {
        var Toast = Swal.mixin({
            toast: true, position: 'top-end',
            showConfirmButton: false, timer: 3500, timerProgressBar: true
        });
        Toast.fire({ icon: type, title: message });
    } else {
        console.log('[' + type + '] ' + message);
    }
}

function activateDashboardLink() {
    var links = document.querySelectorAll('.sidebar .nav-link, .nav-pills .nav-link');
    for (var i = 0; i < links.length; i++) {
        links[i].classList.remove('active');
        var href = links[i].getAttribute('href') || '';
        if (href.indexOf('index.aspx') > -1 ||
            (links[i].getAttribute('onclick') || '').indexOf('loadDashboard') > -1) {
            links[i].classList.add('active');
        }
    }
}

window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.showToast = showToast;
window.activateDashboardLink = activateDashboardLink;
