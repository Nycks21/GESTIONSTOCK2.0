'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// UTILITAIRES — Module Dashboard
// ─────────────────────────────────────────────────────────────────────────────

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// ✅ Formatage des montants avec séparateurs de milliers
function formatCurrency(value) {
    if (value === undefined || value === null || isNaN(value)) return '0 Ar';
    return value.toLocaleString('fr-MG') + ' Ar';
}

function getMonthNames() {
    return ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 
            'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
}

function getShortMonthNames() {
    return ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
}

function getWeekDays() {
    return ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
}

function formatDateFr(date) {
    return date.toLocaleDateString('fr-FR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric'
    });
}

function showToast(message, type, duration) {
    type = type || 'info';
    duration = duration || 4000;

    var container = document.getElementById('toastContainer');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toastContainer';
        container.style.cssText = 'position:fixed;top:20px;right:20px;z-index:999999;max-width:500px;width:100%;pointer-events:none;';
        document.body.appendChild(container);
    }

    var colors = {
        success: '#d4edda;color:#155724;border-left:4px solid #28a745',
        error: '#f8d7da;color:#721c24;border-left:4px solid #dc3545',
        warning: '#fff3cd;color:#856404;border-left:4px solid #ffc107',
        info: '#d1ecf1;color:#0c5460;border-left:4px solid #17a2b8'
    };

    var icons = {
        success: 'fa-check-circle',
        error: 'fa-exclamation-circle',
        warning: 'fa-exclamation-triangle',
        info: 'fa-info-circle'
    };

    var toast = document.createElement('div');
    toast.style.cssText = 'background:' + colors[type].split(';')[0] + ';'
        + colors[type].split(';')[1] + ';padding:12px 18px;border-radius:8px;font-size:13px;font-weight:500;'
        + 'min-width:280px;max-width:500px;box-shadow:0 4px 12px rgba(0,0,0,.15);opacity:0;transition:opacity .3s ease;'
        + 'margin-bottom:10px;cursor:pointer;z-index:99999;pointer-events:auto;';
    toast.innerHTML = '<div style="display:flex;align-items:center;gap:10px;">'
        + '<i class="fas ' + icons[type] + '" style="font-size:18px;"></i>'
        + '<span style="flex:1;">' + message + '</span>'
        + '</div>';

    container.appendChild(toast);
    requestAnimationFrame(function() { toast.style.opacity = '1'; });

    setTimeout(function() {
        toast.style.opacity = '0';
        setTimeout(function() { if (toast.parentNode) toast.remove(); }, 350);
    }, duration);
}

function showLoading(message) {
    var overlay = document.getElementById('spinnerOverlay');
    if (!overlay) return;
    overlay.style.display = 'flex';
    var msgEl = overlay.querySelector('.loading-message');
    if (!msgEl) {
        msgEl = document.createElement('div');
        msgEl.className = 'loading-message';
        msgEl.style.cssText = 'color:white;margin-top:15px;font-size:14px;font-weight:500;';
        overlay.appendChild(msgEl);
    }
    msgEl.textContent = message || 'Chargement en cours...';
}

function hideLoading() {
    var overlay = document.getElementById('spinnerOverlay');
    if (overlay) overlay.style.display = 'none';
}

function setBarWidth(id, percent) {
    var el = document.getElementById(id);
    if (el) {
        setTimeout(function() {
            el.style.width = Math.min(100, Math.max(0, percent)) + '%';
        }, 100);
    }
}

// Exposer globalement
window.escapeHtml = escapeHtml;
window.formatCurrency = formatCurrency;
window.showToast = showToast;
window.showLoading = showLoading;
window.hideLoading = hideLoading;
window.setBarWidth = setBarWidth;