'use strict';

function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function formatNumber(v) {
    if (v === null || v === undefined || isNaN(v)) return '0';
    return Number(v).toLocaleString('fr-FR');
}

function formatCurrency(v) {
    if (v === null || v === undefined || isNaN(v)) return '0 Ar';
    var n = Number(v);
    if (n >= 1000000000) return (n / 1000000000).toFixed(2) + ' Md Ar';
    if (n >= 1000000)    return (n / 1000000).toFixed(2) + ' M Ar';
    if (n >= 1000)       return (n / 1000).toFixed(1) + ' k Ar';
    return n.toLocaleString('fr-FR') + ' Ar';
}

function formatDateFr(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    return d.toLocaleDateString('fr-FR', {
        day: '2-digit', month: '2-digit', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    });
}

function timeAgo(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    var diff = Math.floor((Date.now() - d.getTime()) / 1000);
    if (diff < 60)        return 'à l\'instant';
    if (diff < 3600)      return 'il y a ' + Math.floor(diff / 60) + ' min';
    if (diff < 86400)     return 'il y a ' + Math.floor(diff / 3600) + ' h';
    if (diff < 604800)    return 'il y a ' + Math.floor(diff / 86400) + ' j';
    return formatDateFr(iso);
}

function statutLabel(statut) {
    var labels = {
        'BROUILLON': 'Brouillon',
        'VALIDE':    'Validé',
        'ANNULE':    'Annulé',
        'TERMINE':   'Terminé',
        'NORMALE':   'Normale',
        'ALERTE':    'Alerte',
        'RUPTURE':   'Rupture'
    };
    return labels[statut] || statut || '';
}

function statutBadge(statut) {
    var cls = {
        'BROUILLON': 'badge-warning',
        'VALIDE':    'badge-success',
        'ANNULE':    'badge-danger',
        'TERMINE':   'badge-success',
        'NORMALE':   'badge-success',
        'ALERTE':    'badge-warning',
        'RUPTURE':   'badge-danger'
    };
    return '<span class="badge ' + (cls[statut] || 'badge-secondary') + '">' +
           escapeHtml(statutLabel(statut)) + '</span>';
}

window.escapeHtml = escapeHtml;
window.formatNumber = formatNumber;
window.formatCurrency = formatCurrency;
window.formatDateFr = formatDateFr;
window.timeAgo = timeAgo;
window.statutLabel = statutLabel;
window.statutBadge = statutBadge;
