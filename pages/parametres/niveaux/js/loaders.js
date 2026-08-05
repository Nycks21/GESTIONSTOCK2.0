/**
 * loaders.js - Gestion du chargement des données pour le module Niveaux
 */

'use strict';

function chargerNiveaux() {
    showSpinner();
    fetch(API.liste)
        .then(function(r) {
            if (!r.ok) throw new Error('Erreur HTTP ' + r.status);
            return r.json();
        })
        .then(function(data) {
            if (!data.success) throw new Error(data.message || 'Erreur serveur');
            STATE.niveauxData = data.niveaux || [];
            STATE.filteredNiveaux = [...STATE.niveauxData];
            STATE.currentPage = 1;

            renderNiveauxStats();
            renderNiveauxTable();
        })
        .catch(function(err) {
            afficherErreurGlobale('Impossible de charger les niveaux : ' + err.message);
        })
        .finally(function() {
            hideSpinner();
        });
}

function initLoaders() {
    forceHideSpinner();
    hidePreloader();
    chargerNiveaux();
}