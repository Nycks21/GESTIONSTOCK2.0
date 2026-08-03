'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// URLS DES HANDLERS
// ─────────────────────────────────────────────────────────────────────────────
var API_FRAIS = {
    getFrais: 'handlers/GetFrais.ashx',
    getEleves: 'handlers/GetEleve.ashx',
    getClasses: 'handlers/GetClasses.ashx',
    getAnnees: 'handlers/GetAnnees.ashx',
    ajouterPaiement: 'handlers/AjouterPaiementFrais.ashx',
    getHistorique: 'handlers/GetHistoriquePaiements.ashx',
    modifierHistorique: 'handlers/ModifierHistoriquePaiement.ashx',
    supprimerHistorique: 'handlers/SupprimerHistoriquePaiement.ashx',
    getTarifs: 'handlers/GetTarifsEcolage.ashx',
    ajouterTarif: 'handlers/AjouterTarifEcolage.ashx',
    modifierTarif: 'handlers/ModifierTarifEcolage.ashx',
    supprimerTarif: 'handlers/SupprimerTarifEcolage.ashx',
    getTarifByClasse: 'handlers/GetTarifByClasse.ashx',
    updateAll: 'handlers/UpdateAllFrais.ashx',
    recalculer: 'handlers/RecalculerFrais.ashx'
};