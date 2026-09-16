'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// UTILITAIRES — Module Utilisateurs
// ─────────────────────────────────────────────────────────────────────────────

function escapeHtml(text) {
    if (!text) return '';
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function formatDate(dateValue) {
    if (!dateValue) return '-';
    var timestamp;
    if (typeof dateValue === 'string' && dateValue.match(/\/Date\((\d+)\)\//)) {
        timestamp = parseInt(dateValue.match(/\/Date\((\d+)\)\//)[1]);
    } else if (typeof dateValue === 'number') {
        timestamp = dateValue;
    } else if (dateValue instanceof Date) {
        timestamp = dateValue.getTime();
    } else {
        var parsed = new Date(dateValue);
        if (!isNaN(parsed.getTime())) timestamp = parsed.getTime();
        else return '-';
    }
    var date = new Date(timestamp);
    if (isNaN(date.getTime())) return '-';
    return String(date.getDate()).padStart(2, '0') + '/' + String(date.getMonth() + 1).padStart(2, '0') + '/' + date.getFullYear();
}

// ✅ FIX : getRoleId accepte un ROLEID numérique (string ou number) ET les anciens libellés.
function getRoleId(roleValue) {
    if (roleValue === null || roleValue === undefined || roleValue === '') {
        return null;
    }

    var asNum = parseInt(roleValue, 10);
    if (!isNaN(asNum) && String(asNum) === String(roleValue).trim() && asNum >= 0 && asNum <= 4) {
        return asNum;
    }

    var byName = {
        'SuperAdmin': 0,
        'Admin': 1,
        'Administrateur': 1,
        'User': 2,
        'Utilisateur': 2,
        'Logisticien': 3,
        'Comptable': 4
    };
    if (Object.prototype.hasOwnProperty.call(byName, roleValue)) {
        return byName[roleValue];
    }

    console.error('❌ getRoleId : rôle invalide → "' + roleValue + '"');
    return null;
}

// ✅ TRADUIT : les noms de rôle passent par t()
function getUserRoleName(roleId) {
    var keyMap = {
        0: 'role.superadmin',
        1: 'role.admin',
        2: 'role.user',
        3: 'role.logisticien',
        4: 'role.comptable'
    };
    var key = keyMap[roleId];
    if (key && typeof t === 'function') return t(key);
    return keyMap[roleId] ? keyMap[roleId] : 'Utilisateur';
}

function findUserById(userId) {
    return usersData.find(function(u) { return u.IDUSER == userId; });
}

async function safeJson(res) {
    try {
        var text = await res.text();
        if (!text || text.trim() === "") {
            return { success: false, message: "Empty response" };
        }
        text = text.replace(/^\uFEFF/, '');
        text = text.replace(/^﻿﻿/, '');
        text = text.replace(/﻿﻿$/, '');
        text = text.replace(/[\u200B\u200C\u200D\uFEFF]/g, '');
        text = text.trim();
        return JSON.parse(text);
    } catch (e) {
        console.error("Erreur parsing JSON:", e);
        return { success: false, message: "JSON parsing error" };
    }
}

function getActiveUsersCount() {
    return usersData.filter(function(u) {
        return u.ACTIVE === true || u.ACTIVE === 1 || u.ACTIVE === 'true';
    }).length;
}

// ✅ TRADUIT : alerte de limite de licence
function showLicenceLimitAlert(currentUsers, maxUsers, action) {
    action = action || (typeof t === 'function' ? t('licence.action.activate') : 'activer');

    var currentLabel = typeof t === 'function'
        ? t('licence.current_users', { current: currentUsers })
        : 'Vous avez actuellement <strong>' + currentUsers + '</strong> utilisateur(s) actif(s).';

    var maxLabel = typeof t === 'function'
        ? t('licence.max_users', { max: maxUsers })
        : 'Votre licence autorise un maximum de <strong>' + maxUsers + '</strong> utilisateur(s).';

    var infoLabel = typeof t === 'function'
        ? t('licence.info_deactivate', { action: action })
        : 'Pour ' + action + ' cet utilisateur, vous devez d\'abord désactiver un autre utilisateur actif.';

    var title = typeof t === 'function' ? t('licence.limit_reached') : '⚠️ Limite d\'utilisateurs atteinte';
    var modalTitle = typeof t === 'function' ? t('licence.limit_title') : 'Licence dépassée';
    var btnText = typeof t === 'function' ? t('licence.understand') : 'Compris';

    var modalHtml = `
        <div style="text-align: center; padding: 10px;">
            <i class="fas fa-exclamation-triangle" style="font-size: 48px; color: #dc3545; margin-bottom: 20px;"></i>
            <h3 style="color: #dc3545; margin-bottom: 15px;">${title}</h3>
            <p style="font-size: 14px; color: #555; margin-bottom: 10px;">${currentLabel}</p>
            <p style="font-size: 14px; color: #555; margin-bottom: 20px;">${maxLabel}</p>
            <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; border-radius: 5px; text-align: left;">
                <i class="fas fa-info-circle" style="color: #ffc107; margin-right: 8px;"></i>
                <span style="font-size: 13px;">${infoLabel}</span>
            </div>
        </div>
    `;
    Swal.fire({
        title: modalTitle,
        html: modalHtml,
        icon: 'warning',
        confirmButtonText: btnText,
        confirmButtonColor: '#dc3545'
    });
}

function getDefaultTime() {
    var now = new Date();
    now.setMinutes(now.getMinutes() + 5);
    return now.toTimeString().slice(0, 5);
}

function apiUrl(path) {
    return path;
}

// Exposer globalement
window.escapeHtml = escapeHtml;
window.formatDate = formatDate;
window.getRoleId = getRoleId;
window.getUserRoleName = getUserRoleName;
window.findUserById = findUserById;
window.safeJson = safeJson;
window.getActiveUsersCount = getActiveUsersCount;
window.showLicenceLimitAlert = showLicenceLimitAlert;
window.getDefaultTime = getDefaultTime;
window.apiUrl = apiUrl;
