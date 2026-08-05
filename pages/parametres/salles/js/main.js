/**
 * main.js - Point d'entrée principal du module Salles
 */

'use strict';

console.log('🚀 main.js chargé');

// Initialisation au chargement du DOM
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 DOM chargé - Initialisation du module Salles...');

    var token = getCsrfToken ? getCsrfToken() : 'non disponible';
    console.log('🔒 Token CSRF actuel:', token ? token.substring(0, 20) + '...' : 'aucun');
    console.log('📦 SessionStorage:', sessionStorage.getItem('CSRF_TOKEN') ? 'présent' : 'absent');

    initUIControls();
    initLoaders();
});