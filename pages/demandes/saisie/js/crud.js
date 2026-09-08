// ============================================================
// OUVERTURE / FERMETURE DU MODAL
// ============================================================

function openModalSaisie(e) {
    if (e) e.preventDefault();
    resetFormSaisie();
    document.getElementById('saisieModal').style.display = 'flex';
}

function closeModalSaisie() {
    document.getElementById('saisieModal').style.display = 'none';
    clearErrors();
}

function resetFormSaisie() {
    document.getElementById('sortieNumero').value = '';
    document.getElementById('sortieDate').value = new Date().toISOString().slice(0, 16);
    document.getElementById('sortieDestination').value = '';
    document.getElementById('sortieNom').value = '';
    document.getElementById('sortieFonction').value = '';
    document.getElementById('sortieNotes').value = '';
    document.getElementById('lignesBody').innerHTML = '';
    ajouterLigne();  // ligne par défaut
    clearErrors();
}

// ============================================================
// SAUVEGARDE DE LA DEMANDE
// ============================================================

async function saveSaisie(e) {
    e.preventDefault();
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

    try {
        showSpinner();
        var url = API.BASE + 'pages/modules/sorties/handlers/' + API.ADD;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        var result = await resp.json();
        if (result.success) {
            showToast('Succès', 'Demande de sortie créée avec succès (statut : En cours)', 'success');
            closeModalSaisie();
            loadDemandes();           // recharge la liste
            loadDemandesStats();      // recharge les stats
        } else {
            showToast('Erreur', result.message || 'Échec de la création', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

function viewDemande(id) {
    // Optionnel : afficher les détails de la demande dans une modale ou rediriger
    showToast('Info', 'Détails de la demande ' + id, 'info');
    // Vous pouvez implémenter une modale de détails ou renvoyer vers la page sorties
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

// Expositions
window.openModalSaisie = openModalSaisie;
window.closeModalSaisie = closeModalSaisie;
window.resetFormSaisie = resetFormSaisie;
window.saveSaisie = saveSaisie;
window.viewDemande = viewDemande;
window.showError = showError;
window.clearErrors = clearErrors;
