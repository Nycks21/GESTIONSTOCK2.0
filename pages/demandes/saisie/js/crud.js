// ============================================================
// SAISIE - CRUD (ADD / EDIT / VIEW)
// ============================================================

var currentMode = 'add'; // 'add', 'edit', 'view'

// Récupère le titre du modal de manière robuste
function getModalTitle() {
    var title = document.getElementById('modalTitle');
    if (!title) {
        title = document.querySelector('#saisieModal .modal-header h3');
    }
    return title;
}

// ============================================================
// ✅ Activer/désactiver les champs du modal
//    ⚠️ Les boutons marqués data-keep-active="true" (ex: Annuler)
//       ne sont JAMAIS désactivés.
// ============================================================
function setFieldsEnabled(enabled) {
    // ─── Champs de saisie ───
    var inputs = document.querySelectorAll('#saisieModal input, #saisieModal select, #saisieModal textarea');
    for (var i = 0; i < inputs.length; i++) {
        inputs[i].disabled = !enabled;
        if (!enabled) {
            inputs[i].style.backgroundColor = '#e9ecef';
            inputs[i].style.cursor = 'not-allowed';
        } else {
            inputs[i].style.backgroundColor = '';
            inputs[i].style.cursor = '';
        }
    }

    // ─── Boutons de ligne (btn-success, btn-danger) ───
    var ligneBtns = document.querySelectorAll('#saisieModal .btn-success, #saisieModal .btn-danger');
    for (var j = 0; j < ligneBtns.length; j++) {
        // ⚠️ NE PAS désactiver les boutons marqués "data-keep-active"
        if (ligneBtns[j].getAttribute('data-keep-active') === 'true') {
            ligneBtns[j].disabled = false;
            continue;
        }
        ligneBtns[j].disabled = !enabled;
    }
}

// Masque/affiche les boutons d'action (Enregistrer, Réinitialiser)
function setActionButtonsVisible(visible) {
    var btnSave = document.getElementById('btnSaveSaisie');
    if (btnSave) btnSave.style.display = visible ? '' : 'none';
    var btnReset = document.getElementById('btnResetSaisie');
    if (btnReset) btnReset.style.display = visible ? '' : 'none';

    // ✅ Le bouton Annuler reste TOUJOURS visible ET actif
    var btnAnnuler = document.getElementById('btnAnnulerDemande');
    if (btnAnnuler) {
        btnAnnuler.style.display = '';
        btnAnnuler.disabled = false;
        btnAnnuler.style.opacity = '1';
        btnAnnuler.style.cursor = 'pointer';
    }
}

// ============================================================
// OUVERTURE DU MODAL (AJOUT)
// ============================================================
function openModalSaisie(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    currentMode = 'add';
    var title = getModalTitle();
    if (title) title.innerHTML = '<i class="fas fa-plus"></i> Nouvelle demande';
    resetFormSaisie();
    setFieldsEnabled(true);
    setActionButtonsVisible(true);
    document.getElementById('saisieModal').style.display = 'flex';
}

// ============================================================
// FERMETURE DU MODAL
// ============================================================
function closeModalSaisie() {
    document.getElementById('saisieModal').style.display = 'none';
    AppState.editingId = null;
    currentMode = 'add';
    setFieldsEnabled(true);
    setActionButtonsVisible(true);
    clearErrors();
}

// ============================================================
// RÉINITIALISATION DU FORMULAIRE
// ============================================================
function resetFormSaisie() {
    var numero = document.getElementById('sortieNumero');
    if (numero) numero.value = '';
    var date = document.getElementById('sortieDate');
    if (date) date.value = new Date().toISOString().slice(0, 16);
    var dest = document.getElementById('sortieDestination');
    if (dest) dest.value = '';
    var nom = document.getElementById('sortieNom');
    if (nom) nom.value = '';
    var fonction = document.getElementById('sortieFonction');
    if (fonction) fonction.value = '';
    var notes = document.getElementById('sortieNotes');
    if (notes) notes.value = '';
    var lignesBody = document.getElementById('lignesBody');
    if (lignesBody) lignesBody.innerHTML = '';
    ajouterLigne();
    clearErrors();
}

// Charge les données d'une demande dans le modal
function chargerDemandeDansModal(demande) {
    var numero = document.getElementById('sortieNumero');
    if (numero) numero.value = demande.NUMERO || '';
    var date = document.getElementById('sortieDate');
    if (date) {
        var dateStr = '';
        if (demande.DATE_SORTIE) {
            try {
                var d = new Date(demande.DATE_SORTIE);
                if (!isNaN(d.getTime())) {
                    dateStr = d.toISOString().slice(0, 16);
                }
            } catch (e) { /* ignore */ }
        }
        date.value = dateStr;
    }
    var dest = document.getElementById('sortieDestination');
    if (dest) dest.value = demande.DESTINATION || '';
    var nom = document.getElementById('sortieNom');
    if (nom) nom.value = demande.NOM || '';
    var fonction = document.getElementById('sortieFonction');
    if (fonction) fonction.value = demande.FONCTION || '';
    var notes = document.getElementById('sortieNotes');
    if (notes) notes.value = demande.NOTES || '';

    var lignesBody = document.getElementById('lignesBody');
    if (lignesBody) lignesBody.innerHTML = '';
    var lignes = demande.Lignes || [];
    if (lignes.length) {
        lignes.forEach(function (l) {
            ajouterLigne(l.ARTICLE_ID, l.QUANTITE_D, l.OBSERVATIONS);
        });
    } else {
        ajouterLigne();
    }
}

// ============================================================
// SAUVEGARDE (création ou modification)
// ============================================================
async function saveSaisie(e) {
    e.preventDefault();
    if (currentMode === 'view') {
        showToast('Info', 'Vous êtes en consultation, aucune modification possible.', 'info');
        return;
    }
    var id = AppState.editingId;
    var data = {
        numero: document.getElementById('sortieNumero').value.trim(),
        dateSortie: document.getElementById('sortieDate').value,
        destination: document.getElementById('sortieDestination').value.trim(),
        nom: document.getElementById('sortieNom').value.trim(),
        fonction: document.getElementById('sortieFonction').value.trim(),
        notes: document.getElementById('sortieNotes').value.trim(),
        lignes: getLignesFromModal()
    };

    var valid = true;
    clearErrors();
    if (!data.numero) { showError('sortieNumero', 'Le numéro est requis'); valid = false; }
    if (!data.dateSortie) { showError('sortieDate', 'La date est requise'); valid = false; }
    if (!data.destination) { showError('sortieDestination', 'La destination est requise'); valid = false; }
    if (!data.lignes.length) { showToast('Erreur', 'Ajoutez au moins une ligne d\'article', 'error'); valid = false; }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload = id ? Object.assign({}, data, { id: id }) : data;

    try {
        showSpinner();
        var url = API.BASE + endpoint;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        var result = await resp.json();
        if (result.success) {
            showToast('Succès', result.message || (id ? 'Demande modifiée' : 'Demande créée'), 'success');
            closeModalSaisie();
            loadDemandes();
            loadDemandesStats();
        } else {
            showToast('Erreur', result.message || 'Échec de l\'opération', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// VISUALISATION (VIEW)
//    ⚠️ Le bouton Annuler doit rester ACTIF et VISIBLE
// ============================================================
function viewDemande(id) {
    var demande = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!demande) return;
    AppState.editingId = id;
    currentMode = 'view';

    var title = getModalTitle();
    if (title) title.innerHTML = '<i class="fas fa-eye"></i> Détails de la demande';

    chargerDemandeDansModal(demande);

    // Désactive tous les champs SAUF les boutons data-keep-active="true"
    setFieldsEnabled(false);

    // Masque Enregistrer et Réinitialiser (mais PAS Annuler)
    setActionButtonsVisible(false);

    // ✅ Sécurité supplémentaire : s'assurer que le bouton Annuler est actif
    var btnAnnuler = document.getElementById('btnAnnulerDemande');
    if (btnAnnuler) {
        btnAnnuler.disabled = false;
        btnAnnuler.style.opacity = '1';
        btnAnnuler.style.cursor = 'pointer';
        btnAnnuler.style.display = '';
    }

    clearErrors();
    document.getElementById('saisieModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION (EDIT)
// ============================================================
function editDemande(id) {
    var demande = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!demande) return;
    if (demande.STATUT !== 'BROUILLON') {
        showToast('Attention', 'Cette demande est déjà validée et ne peut pas être modifiée.', 'warning');
        return;
    }
    AppState.editingId = id;
    currentMode = 'edit';
    var title = getModalTitle();
    if (title) title.innerHTML = '<i class="fas fa-edit"></i> Modifier la demande';
    chargerDemandeDansModal(demande);
    setFieldsEnabled(true);
    setActionButtonsVisible(true);
    clearErrors();
    document.getElementById('saisieModal').style.display = 'flex';
}

// ============================================================
// SUPPRESSION
// ============================================================
async function deleteDemande(id) {
    var demande = AppState.sorties.find(function (s) { return s.ID === id; });
    if (demande && demande.STATUT !== 'BROUILLON') {
        showToast('Attention', 'Impossible de supprimer une demande validée.', 'warning');
        return;
    }
    var confirm = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer cette demande ?',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    });
    if (!confirm.isConfirmed) return;

    try {
        showSpinner();
        var url = API.BASE + API.DELETE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        });
        var result = await resp.json();
        if (result.success) {
            showToast('Succès', 'Demande supprimée', 'success');
            loadDemandes();
            loadDemandesStats();
        } else {
            showToast('Erreur', result.message || 'Échec de la suppression', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// UTILITAIRES D'ERREURS
// ============================================================
function showError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
}

function clearErrors() {
    document.querySelectorAll('.field-error').forEach(function (el) {
        el.textContent = '';
        el.style.display = 'none';
    });
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.openModalSaisie = openModalSaisie;
window.closeModalSaisie = closeModalSaisie;
window.resetFormSaisie = resetFormSaisie;
window.saveSaisie = saveSaisie;
window.viewDemande = viewDemande;
window.editDemande = editDemande;
window.deleteDemande = deleteDemande;
window.showError = showError;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
window.setActionButtonsVisible = setActionButtonsVisible;
window.getModalTitle = getModalTitle;
