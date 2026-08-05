/**
 * config.js
 */

'use strict';

var API = {
    liste: 'handlers/GetNiveaux.ashx',
    ajouter: 'handlers/AjouterNiveau.ashx',
    modifier: 'handlers/ModifierNiveau.ashx',
    supprimer: 'handlers/SupprimerNiveau.ashx'
};

var STATE = {
    niveauxData: [],
    editId: null,
    currentPage: 1,
    rowsPerPage: 10,
    filteredNiveaux: []
};

var CONSTANTS = {
    STATUT_ACTIF: '1',
    STATUT_INACTIF: '0'
};

// ─────────────────────────────────────────────
// CSRF — Récupération FORCÉE depuis le DOM
// ─────────────────────────────────────────────
function getCsrfToken() {
    // 🔥 PRIORITÉ ABSOLUE : meta tag
    var meta = document.querySelector('meta[name="csrf-token"]');
    if (meta) {
        var token = meta.getAttribute('content');
        if (token && token.length > 10) {
            sessionStorage.setItem('CSRF_TOKEN', token);
            return token;
        }
    }

    // Fallback : champ caché
    var input = document.getElementById('csrfTokenField');
    if (input && input.value && input.value.length > 10) {
        sessionStorage.setItem('CSRF_TOKEN', input.value);
        return input.value;
    }

    // Fallback : cookie
    var cookies = document.cookie.split(';');
    for (var i = 0; i < cookies.length; i++) {
        var cookie = cookies[i].trim();
        if (cookie.indexOf('CSRF_TOKEN=') === 0) {
            var value = decodeURIComponent(cookie.substring(cookie.indexOf('=') + 1));
            if (value && value.length > 10) {
                sessionStorage.setItem('CSRF_TOKEN', value);
                return value;
            }
        }
    }

    // Dernier recours
    var session = sessionStorage.getItem('CSRF_TOKEN');
    if (session) return session;

    var newToken = 'Token_' + Date.now() + '_' + Math.random().toString(36).substring(2, 15);
    sessionStorage.setItem('CSRF_TOKEN', newToken);
    return newToken;
}

function getCsrfHeaders() {
    var token = getCsrfToken();
    var headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Requested-With': 'XMLHttpRequest'
    };
    if (token) {
        headers['X-CSRF-Token'] = token;
    }
    return headers;
}

function addCsrfToken(payload) {
    var token = getCsrfToken();
    if (token) {
        payload.CSRF_TOKEN = token;
    }
    return payload;
}