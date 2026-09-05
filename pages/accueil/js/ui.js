'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// UI — Module Dashboard
// ─────────────────────────────────────────────────────────────────────────────

function initializeUI() {
    // Menu toggle
    var menuToggle = document.getElementById('menuToggle');
    var sidebar = document.getElementById('sidebar');
    var contentWrapper = document.getElementById('contentWrapper');

    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', function() {
            sidebar.classList.toggle('collapsed');
            if (contentWrapper) contentWrapper.classList.toggle('expanded');
        });
    }

    // Notifications
    var notifToggle = document.getElementById('notifToggle');
    var notifDropdown = document.getElementById('notifDropdown');

    if (notifToggle && notifDropdown) {
        notifToggle.addEventListener('click', function(e) {
            e.stopPropagation();
            notifDropdown.classList.toggle('show');
        });

        document.addEventListener('click', function() {
            notifDropdown.classList.remove('show');
        });
    }

    // Fullscreen
    var fullscreenToggle = document.getElementById('fullscreenToggle');
    if (fullscreenToggle) {
        fullscreenToggle.addEventListener('click', function() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen();
            } else {
                document.exitFullscreen();
            }
        });
    }

    // Activer le lien Dashboard dans la sidebar
    activateDashboardLink();
}

function activateDashboardLink() {
    var links = document.querySelectorAll('.sidebar .nav-link, .nav-pills .nav-link');
    for (var i = 0; i < links.length; i++) {
        var link = links[i];
        link.classList.remove('active');
        if (link.textContent.trim() === 'Dashboard' || 
            link.getAttribute('onclick') === 'loadDashboard()') {
            link.classList.add('active');
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MODALES
// ─────────────────────────────────────────────────────────────

function showStudentDetail(name) {
    if (typeof Swal !== 'undefined') {
        Swal.fire('Élève', 'Détails de ' + name, 'info');
    } else {
        alert('Détails de ' + name);
    }
}

function showKPIDetail(type) {
    var titles = {
        eleves: 'Total des élèves',
        classes: 'Classes actives',
        presence: 'Taux de présence',
        impayes: 'Frais impayés'
    };
    if (typeof Swal !== 'undefined') {
        Swal.fire('Détail', titles[type] || 'Information', 'info');
    }
}

function closeModal() {
    var modal = document.getElementById('bulletinModal');
    if (modal) modal.style.display = 'none';
}

function closePaymentModal() {
    var modal = document.getElementById('paymentModal');
    if (modal) modal.style.display = 'none';
}

function saveBulletin() {
    if (typeof Swal !== 'undefined') {
        Swal.fire('Info', 'Fonctionnalité à implémenter', 'info');
    }
}

function savePayment() {
    if (typeof Swal !== 'undefined') {
        Swal.fire('Info', 'Fonctionnalité à implémenter', 'info');
    }
}

function closeAddBulletinModal() {
    var modal = document.getElementById('addBulletinModal');
    if (modal) modal.style.display = 'none';
}

function saveNewBulletin() {
    if (typeof Swal !== 'undefined') {
        Swal.fire('Info', 'Fonctionnalité à implémenter', 'info');
    }
}

// Exposer globalement
window.showStudentDetail = showStudentDetail;
window.showKPIDetail = showKPIDetail;
window.closeModal = closeModal;
window.closePaymentModal = closePaymentModal;
window.saveBulletin = saveBulletin;
window.savePayment = savePayment;
window.closeAddBulletinModal = closeAddBulletinModal;
window.saveNewBulletin = saveNewBulletin;
window.initializeUI = initializeUI;
window.activateDashboardLink = activateDashboardLink;