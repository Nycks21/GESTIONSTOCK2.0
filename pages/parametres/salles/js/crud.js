/**
 * crud.js - Opérations CRUD pour le module Salles avec CSRF
 */

'use strict';

// ─────────────────────────────────────────────
// AJAX — helper générique avec CSRF
// ─────────────────────────────────────────────
function ajax(url, payload) {
    var payloadWithToken = addCsrfToken(payload || {});
    var headers = getCsrfHeaders();

    var token = getCsrfToken();
    console.log('🔒 Token utilisé:', token ? token.substring(0, 20) + '...' : 'aucun');
    console.log('📤 Envoi à:', url);
    console.log('📦 Payload:', payloadWithToken);

    return fetch(url, {
        method: 'POST',
        headers: headers,
        body: JSON.stringify(payloadWithToken)
    })
    .then(function(r) {
        return r.text().then(function(text) {
            console.log('📥 Réponse brute:', text);
            try {
                var data = JSON.parse(text);
                if (!r.ok) {
                    throw new Error(data.message || 'Erreur HTTP ' + r.status);
                }
                if (data.success === false) {
                    throw new Error(data.message || 'Erreur serveur');
                }
                return data;
            } catch (e) {
                if (r.ok) {
                    throw new Error('Réponse invalide du serveur');
                }
                throw new Error('Erreur HTTP ' + r.status + ': ' + text);
            }
        });
    })
    .catch(function(err) {
        console.error('❌ Erreur ajax:', err.message);
        throw err;
    });
}

// ─────────────────────────────────────────────
// SAUVEGARDER (Ajouter ou Modifier)
// ─────────────────────────────────────────────
function saveSalle() {
    console.log('🔵 saveSalle appelée');

    if (typeof validateSalleForm === "function" && !validateSalleForm()) {
        console.warn('⚠️ Formulaire invalide');
        return;
    }

    var estUneModification = (STATE.editId !== null);

    var elNumero = document.getElementById('salleNumero');
    var elCapacite = document.getElementById('salleCapacite');
    var elStatut = document.getElementById('salleStatut');

    var payload = {
        numero: elNumero.value.trim(),
        capacite: parseInt(elCapacite.value, 10) || 30,
        statut: elStatut.value === CONSTANTS.STATUT_ACTIF
    };

    var url = API.ajouter;
    if (estUneModification) {
        payload.id = STATE.editId;
        url = API.modifier;
    }

    var btnSave = document.querySelector('#addSalleModal .btn-primary');
    if (btnSave) {
        btnSave.disabled = true;
        btnSave.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Enregistrement...';
    }

    showSpinner();

    ajax(url, payload)
        .then(function(data) {
            closeAddSalleModal();
            Swal.fire({
                title: estUneModification ? 'Salle modifiée !' : 'Salle ajoutée !',
                text: estUneModification ? 'Les modifications ont été enregistrées.' : 'La nouvelle salle a été créée avec succès.',
                icon: 'success',
                timer: 2500,
                showConfirmButton: false
            });
            chargerSalles();
        })
        .catch(function(err) {
            Swal.fire({
                icon: 'error',
                title: "Erreur d'enregistrement",
                text: err.message || 'Une erreur inattendue est survenue',
                confirmButtonColor: '#d63030'
            });
        })
        .finally(function() {
            hideSpinner();
            if (btnSave) {
                btnSave.disabled = false;
                btnSave.innerHTML = '<i class="fas fa-save"></i> Enregistrer';
            }
        });
}

// ─────────────────────────────────────────────
// ÉDITER
// ─────────────────────────────────────────────
function editSalle(id) {
    var s = STATE.sallesData.find(function(item) {
        return String(item.ID).toLowerCase() === String(id).toLowerCase();
    });
    if (!s) {
        console.error("Salle introuvable :", id);
        Swal.fire({
            icon: 'error',
            title: 'Erreur',
            text: 'La salle demandée n\'existe pas. Veuillez rafraîchir.',
            confirmButtonColor: '#d63030'
        });
        return;
    }

    STATE.editId = s.ID;
    document.getElementById('salleEditId').value = s.ID;
    document.getElementById('salleNumero').value = s.NUMERO;
    document.getElementById('salleCapacite').value = s.CAPACITE;

    var statutSelect = document.getElementById('salleStatut');
    if (statutSelect) {
        var isDispo = (s.STATUT === true || s.STATUT === 1 || s.STATUT === '1' || s.STATUT === 'True');
        statutSelect.value = isDispo ? CONSTANTS.STATUT_ACTIF : CONSTANTS.STATUT_INACTIF;
    }

    document.getElementById('salleModalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier la salle';
    showModal('addSalleModal');
    document.getElementById('salleNumero').focus();
}

// ─────────────────────────────────────────────
// SUPPRIMER
// ─────────────────────────────────────────────
function deleteSalle(id, numero) {
    Swal.fire({
        title: 'Confirmation',
        text: "Supprimer la salle « " + numero + " » ? Cette action est irréversible.",
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler',
        target: document.body
    }).then(function(result) {
        if (result.isConfirmed) {
            showSpinner();
            ajax(API.supprimer, { id: id })
                .then(function(data) {
                    Swal.fire({
                        title: 'Supprimée !',
                        text: 'La salle a été supprimée avec succès.',
                        icon: 'success',
                        timer: 3000,
                        showConfirmButton: false
                    });
                    chargerSalles();
                })
                .catch(function(err) {
                    Swal.fire({
                        title: 'Erreur',
                        text: 'Erreur lors de la suppression : ' + err.message,
                        icon: 'error'
                    });
                    hideSpinner();
                });
        }
    });
}

// Exposer les fonctions globalement
window.saveSalle = saveSalle;
window.editSalle = editSalle;
window.deleteSalle = deleteSalle;