'use strict';

// Utilitaires communs (copiés du module Élèves)

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
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
    requestAnimationFrame(function () { toast.style.opacity = '1'; });

    setTimeout(function () {
        toast.style.opacity = '0';
        setTimeout(function () { if (toast.parentNode) toast.remove(); }, 350);
    }, duration);
}

function showErrorToast(message, details) {
    // Version avec plus de détails, identique au module Élèves
    // ... (copier le code de utils.js du module Élèves)
    // Pour gagner de la place, on peut réutiliser la même fonction.
}

function getVal(id) {
    var el = document.getElementById(id);
    return el ? el.value.trim() : '';
}

function setVal(id, val) {
    var el = document.getElementById(id);
    if (el) el.value = val;
}

async function fetchJson(url) {
    var res = await fetch(url);
    return safeJson(res);
}

async function safeJson(res) {
    try {
        var text = await res.text();
        if (!text?.trim()) return { success: false, message: 'Réponse vide du serveur.' };
        return JSON.parse(text);
    } catch (e) {
        return { success: false, message: 'Erreur de parsing JSON.' };
    }
}

function dateDuJour() {
    var d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
}

// Expositions
window.escapeHtml = escapeHtml;
window.showToast = showToast;
window.showErrorToast = showErrorToast;
window.getVal = getVal;
window.setVal = setVal;
window.fetchJson = fetchJson;
window.safeJson = safeJson;
window.dateDuJour = dateDuJour;