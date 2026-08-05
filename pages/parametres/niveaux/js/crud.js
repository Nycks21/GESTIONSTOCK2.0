/**
 * crud.js - Opérations CRUD pour le module Niveaux
 */

'use strict';

// Helper AJAX
function ajax(url, payload) {
    var token = getCsrfToken();
    var headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Requested-With': 'XMLHttpRequest'
    };
    if (token) {
        headers['X-CSRF-Token'] = token;
    }
    // Ajouter le token au payload aussi (au cas où)
    if (token) {
        payload.CSRF_TOKEN = token;
    }

    return fetch(url, {
        method: 'POST',
        headers: headers,
        body: JSON.stringify(payload)
    })
    .then(function(response) {
        return response.text().then(function(text) {
            try {
                var data = JSON.parse(text);
                if (!response.ok) {
                    throw new Error(data.message || 'Erreur HTTP ' + response.status);
                }
                if (data.success === false) {
                    throw new Error(data.message || 'Erreur serveur');
                }
                return data;
            } catch (e) {
                if (response.ok) {
                    throw new Error('Réponse invalide du serveur');
                } else {
                    throw new Error('Erreur HTTP ' + response.status + ': ' + text.substring(0, 100));
                }
            }
        });
    });
}

// Sauvegarder (ajouter ou modifier)
function saveNiveau() {
    console.log('🔵 saveNiveau appelée');

    if (typeof validateNiveauForm === 'function' && !validateNiveauForm()) {
        console.warn('⚠️ Formulaire invalide');
        return;
    }

    var estUneModification = (STATE.editId !== null);

    var elNom = document.getElementById('niveauNom');
    var elOrdre = document.getElementById('niveauOrdre');
    var elStatut = document.getElementById('niveauStatut');

    var payload = {
        nom: elNom.value.trim(),
        ordre: parseInt(elOrdre.value, 10) || 0,
        statut: elStatut.value === CONSTANTS.STATUT_ACTIF
    };

    var url = API.ajouter;
    if (estUneModification) {
        payload.id = STATE.editId;
        url = API.modifier;
    }

    var btnSave = document.querySelector('#addNiveauModal .btn-primary');
    if (btnSave) {
        btnSave.disabled = true;
        btnSave.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Enregistrement...';
    }

    showSpinner();

    ajax(url, payload)
        .then(function(data) {
            closeAddNiveauModal();
            Swal.fire({
                title: estUneModification ? 'Modification réussie !' : 'Ajout réussi !',
                text: estUneModification ? 'Les modifications du niveau ont été enregistrées.' : 'Le nouveau niveau a été créé avec succès.',
                icon: 'success',
                timer: 2500,
                showConfirmButton: false
            });
            chargerNiveaux();
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

// Éditer
function editNiveau(id) {
    var n = STATE.niveauxData.find(function(item) {
        return String(item.ID).toLowerCase() === String(id).toLowerCase();
    });

    if (!n) {
        console.error("Niveau introuvable pour l'ID : " + id);
        Swal.fire({
            icon: 'error',
            title: 'Erreur',
            text: 'Le niveau demandé n\'existe pas. Veuillez rafraîchir.'
        });
        return;
    }

    STATE.editId = n.ID;
    document.getElementById('niveauEditId').value = n.ID;
    document.getElementById('niveauNom').value = n.NOM;
    document.getElementById('niveauOrdre').value = n.ORDRE;

    var statutSelect = document.getElementById('niveauStatut');
    if (statutSelect) {
        var isActif = (n.STATUT === true || n.STATUT === 1 || n.STATUT === '1' || n.STATUT === 'True');
        statutSelect.value = isActif ? CONSTANTS.STATUT_ACTIF : CONSTANTS.STATUT_INACTIF;
    }

    document.getElementById('niveauModalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier le niveau';
    showModal('addNiveauModal');
    document.getElementById('niveauNom').focus();
}

// Supprimer
function deleteNiveau(id, nom) {
    Swal.fire({
        title: 'Confirmation',
        text: "Supprimer le niveau « " + nom + " » ? Cette action est irréversible.",
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    }).then(function(result) {
        if (result.isConfirmed) {
            showSpinner();
            ajax(API.supprimer, { id: id })
                .then(function() {
                    Swal.fire({
                        title: 'Supprimé !',
                        text: 'Le niveau a été supprimé avec succès.',
                        icon: 'success',
                        timer: 3000,
                        showConfirmButton: false
                    });
                    chargerNiveaux();
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

// ✅ EXPOSITION GLOBALE (pour les appels inline)
window.saveNiveau = saveNiveau;
window.editNiveau = editNiveau;
window.deleteNiveau = deleteNiveau;

console.log('✅ crud.js chargé - saveNiveau, editNiveau, deleteNiveau exposés');