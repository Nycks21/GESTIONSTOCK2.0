'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT — Module Utilisateurs (corrigé)
// ─────────────────────────────────────────────────────────────────────────────

// Fonction d'échappement HTML (définie localement)
function escapeHtml(text) {
    if (!text) return '';
    var map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return String(text).replace(/[&<>"']/g, function(m) { return map[m]; });
}

function exportUsersToExcelOnly(event) {
    if (event) event.preventDefault();

    // Vérifier que filteredUsers est défini et non vide
    if (typeof filteredUsers === 'undefined' || !filteredUsers || !filteredUsers.length) {
        Swal.fire({ icon: 'warning', title: 'Aucune donnée', text: 'Aucun utilisateur à exporter' });
        return false;
    }

    // Définir un fallback pour getUserRoleName si non défini
    var roleMap = {
        0: 'SuperAdmin',
        1: 'Admin',
        2: 'User',
        3: 'Logisticien',
        4: 'Comptable'
    };
    var getUserRoleNameLocal = (typeof getUserRoleName === 'function') ? getUserRoleName : function(roleId) {
        return roleMap[roleId] || 'Rôle ' + roleId;
    };

    // En-têtes incluant la colonne "Dernière connexion"
    var headers = ['Nom d\'utilisateur', 'Nom', 'Email', 'Téléphone', 'Rôle', 'Statut', 'Date de création', 'Dernière connexion'];

    var rows = filteredUsers.map(function(user) {
        var lastLogin = user.LAST_LOGIN || user.LASTLOGIN || null;
        var lastLoginFormatted = lastLogin ? formatDate(lastLogin) : 'Jamais'; // formatDate doit exister

        return [
            user.USERNAME || '',
            user.NOM || '',
            user.EMAIL || '',
            user.TELEPHONE || '',
            getUserRoleNameLocal(user.ROLEID),
            (user.ACTIVE === true || user.ACTIVE === 1) ? 'Actif' : 'Inactif',
            formatDate(user.CREATED_AT) || '',
            lastLoginFormatted
        ];
    });

    var exportDate = new Date().toLocaleString('fr-FR');
    var html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Export Utilisateurs</title><style>th{background:#4CAF50;color:white;border:1px solid #ddd;padding:8px}td{border:1px solid #ddd;padding:8px}table{border-collapse:collapse;width:100%}</style></head><body><h2>Liste des Utilisateurs</h2><p>Date: ' + escapeHtml(exportDate) + '</p><p>Total: ' + rows.length + '</p><table><thead><tr>' + headers.map(function(h) { return '<th>' + escapeHtml(h) + '</th>'; }).join('') + '</tr></thead><tbody>' + rows.map(function(row) {
        return '<tr>' + row.map(function(cell) { return '<td>' + escapeHtml(String(cell || '-')) + '</td>'; }).join('') + '</tr>';
    }).join('') + '</tbody></table></body></html>';

    // Télécharger avec le bon MIME et BOM UTF-8
    downloadFile(html, 'utilisateurs.xls', 'application/vnd.ms-excel');

    Swal.fire({
        icon: 'success',
        title: 'Export Excel réussi',
        text: filteredUsers.length + ' utilisateur(s) exporté(s)',
        timer: 2000,
        showConfirmButton: false
    });
    return false;
}

function downloadFile(content, filename, mimeType) {
    try {
        var blob = new Blob(['\uFEFF' + content], { type: mimeType });
        var link = document.createElement('a');
        var url = URL.createObjectURL(blob);
        link.href = url;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        setTimeout(function() { URL.revokeObjectURL(url); }, 100);
    } catch (error) {
        console.error('Erreur téléchargement:', error);
        Swal.fire({ icon: 'error', title: 'Erreur', text: 'Impossible de télécharger ' + filename });
    }
}

// Exposer globalement
window.exportUsersToExcelOnly = exportUsersToExcelOnly;
window.downloadFile = downloadFile;
