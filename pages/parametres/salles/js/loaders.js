/**
 * loaders.js - Chargement des données pour le module Salles
 */

'use strict';

function chargerSalles() {
    showSpinner();
    fetch(API.liste)
        .then(function(r) {
            if (!r.ok) throw new Error('Erreur HTTP ' + r.status);
            return r.json();
        })
        .then(function(data) {
            if (!data.success) throw new Error(data.message || 'Erreur serveur');
            STATE.sallesData = data.salles || [];
            STATE.filteredSalles = [...STATE.sallesData];
            STATE.currentPage = 1;

            renderSallesStats();
            renderSallesTable();
        })
        .catch(function(err) {
            afficherErreurGlobale('Impossible de charger les salles : ' + err.message);
        })
        .finally(function() {
            hideSpinner();
        });
}

function initLoaders() {
    forceHideSpinner();
    hidePreloader();
    chargerSalles();
}