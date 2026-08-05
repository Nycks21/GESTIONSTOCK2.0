'use strict';

function init() {
    console.log('🚀 Initialisation du module Matières...');
    initUIControls();
    loadMatieres();
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}