'use strict';

// Initialisation du module

function init() {
    console.log('🚀 Initialisation du module Classes...');
    initUIControls();
    loadClasses();
}

// Attendre le DOM chargé
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}