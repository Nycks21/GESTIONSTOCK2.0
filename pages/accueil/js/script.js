// ════════════════════════════════════════════════════════════════
// INITIALISATION
// ════════════════════════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

function initializeApp() {
    // Menu toggle
    const menuToggle = document.getElementById('menuToggle');
    const sidebar = document.getElementById('sidebar');
    const contentWrapper = document.getElementById('contentWrapper');
    
    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', function() {
            sidebar.classList.toggle('collapsed');
            contentWrapper.classList.toggle('expanded');
        });
    }
    
    // Notifications
    const notifToggle = document.getElementById('notifToggle');
    const notifDropdown = document.getElementById('notifDropdown');
    
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
    const fullscreenToggle = document.getElementById('fullscreenToggle');
    if (fullscreenToggle) {
        fullscreenToggle.addEventListener('click', function() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen();
            } else {
                document.exitFullscreen();
            }
        });
    }
}

// Fonctions modales globales
window.closeModal = function() {
    const modal = document.getElementById('bulletinModal');
    if (modal) modal.style.display = 'none';
};

window.saveBulletin = function() {
    Swal.fire('Info', 'Fonctionnalité à implémenter', 'info');
};

window.closePaymentModal = function() {
    document.getElementById('paymentModal').style.display = 'none';
};

window.savePayment = function() {
    Swal.fire('Info', 'Fonctionnalité à implémenter', 'info');
};

window.updatePaymentInfo = function() {
    // À implémenter
};

window.closeAddBulletinModal = function() {
    document.getElementById('addBulletinModal').style.display = 'none';
};

window.saveNewBulletin = function() {
    Swal.fire('Info', 'Fonctionnalité à implémenter', 'info');
};