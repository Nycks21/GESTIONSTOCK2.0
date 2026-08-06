/**
 * config.js - Configuration du module Salles
 */

'use strict';

// URLs des handlers
var API = {
    liste: 'handlers/GetSalles.ashx',
    ajouter: 'handlers/AjouterSalle.ashx',
    modifier: 'handlers/ModifierSalle.ashx',
    supprimer: 'handlers/SupprimerSalle.ashx'
};

// État local
var STATE = {
    sallesData: [],
    editId: null,
    currentPage: 1,
    rowsPerPage: 10,
    filteredSalles: []
};

// Constantes
var CONSTANTS = {
    STATUT_ACTIF: '1',
    STATUT_INACTIF: '0'
};

// ─────────────────────────────────────────────
// CSRF TOKEN MANAGEMENT
// ─────────────────────────────────────────────

/**
 * Récupère le token CSRF depuis le DOM (meta tag, champ caché, cookie)
 * @returns {string} Le token CSRF
 */
function getCsrfToken() {
    // 1. Meta tag (prioritaire)
    var meta = document.querySelector('meta[name="csrf-token"]');
    if (meta && meta.getAttribute('content')) {
        var token = meta.getAttribute('content');
        if (token && token !== 'SESSION EXPIRE' && token.length > 10) {
            sessionStorage.setItem('CSRF_TOKEN', token);
            return token;
        }
    }

    // 2. Champ caché
    var input = document.getElementById('csrfTokenField');
    if (input && input.value && input.value !== 'SESSION EXPIRE') {
        sessionStorage.setItem('CSRF_TOKEN', input.value);
        return input.value;
    }

    // 3. Cookie
    var cookies = document.cookie.split(';');
    for (var i = 0; i < cookies.length; i++) {
        var cookie = cookies[i].trim();
        if (cookie.indexOf('CSRF_TOKEN=') === 0) {
            var value = decodeURIComponent(cookie.substring(cookie.indexOf('=') + 1));
            if (value && value !== 'SESSION EXPIRE') {
                sessionStorage.setItem('CSRF_TOKEN', value);
                return value;
            }
        }
    }

    // 4. SessionStorage (fallback)
    var session = sessionStorage.getItem('CSRF_TOKEN');
    if (session) return session;

    console.warn('Token CSRF introuvable — rechargez la page ou reconnectez-vous.');
    return '';
}

/**
 * Ajoute le token CSRF au payload
 * @param {object} payload
 * @returns {object}
 */
function addCsrfToken(payload) {
    var token = getCsrfToken();
    if (token) {
        payload.CSRF_TOKEN = token;
        payload.__RequestVerificationToken = token;
        payload._csrf = token;
    }
    return payload;
}

/**
 * Obtient les headers avec le token CSRF
 * @returns {object}
 */
function getCsrfHeaders() {
    var token = getCsrfToken();
    var headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Requested-With': 'XMLHttpRequest'
    };
    if (token) {
        headers['X-CSRF-Token'] = token;   // Le handler vérifie ce header
        headers['X-CSRF-TOKEN'] = token;
        headers['CSRF_TOKEN'] = token;
    }
    return headers;
}