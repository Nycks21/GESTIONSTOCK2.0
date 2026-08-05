'use strict';

async function saveMatiere() {
    if (!validateMatiereForm()) {
        return;
    }

    var payload = {
        NOM: getVal('matiereNom'),
        ENSEIGNANT_ID: parseInt(getVal('matiereEnseignant'), 10),
        COEFFICIENT: parseFloat(getVal('matiereCoeff')) || 0,
        HEURES_SEMAINE: parseInt(getVal('matiereHeures'), 10) || 3,
        CLASSE_ID: parseInt(getVal('matiereClasse'), 10)
    };

    var url = STATE.isEditMode ? API_MATIERES.modifier : API_MATIERES.ajouter;
    if (STATE.isEditMode) {
        payload.ID = STATE.editId;
    }

    var btnSave = document.querySelector('#addMatiereModal .btn-primary');
    if (btnSave) {
        btnSave.disabled = true;
        btnSave.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Enregistrement...';
    }

    showSpinner();

    try {
        var res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (!res.ok) {
            var errorText = await res.text();
            var errorMessage = 'Erreur ' + res.status;
            try {
                var errorJson = JSON.parse(errorText);
                if (errorJson.message) errorMessage = errorJson.message;
            } catch (e) {
                console.error('Réponse non JSON :', errorText);
                errorMessage = errorText.substring(0, 200);
            }
            throw new Error(errorMessage);
        }

        var data = await res.json();

        if (data.success) {
            showToast(data.message || 'Opération réussie', 'success');
            setTimeout(function() {
                closeAddMatiereModal();
                loadMatieres();
            }, 1500);
        } else {
            showErrorToast(data.message || 'Erreur inconnue.');
        }
    } catch (err) {
        console.error('saveMatiere:', err);
        showErrorToast('Erreur lors de l\'enregistrement', err.message);
    } finally {
        hideSpinner();
        if (btnSave) {
            btnSave.disabled = false;
            btnSave.innerHTML = '<i class="fas fa-save"></i> Enregistrer';
        }
    }
}

async function deleteMatiere(id, nom) {
    var result = await Swal.fire({
        title: 'Supprimer cette matière ?',
        html: '<strong>' + escapeHtml(nom) + '</strong> sera supprimée définitivement.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    });

    if (!result.isConfirmed) return;

    showSpinner();

    try {
        var res = await fetch(API_MATIERES.supprimer, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ID: id })
        });

        var data = await safeJson(res);

        if (data.success) {
            await loadMatieres();
            Swal.fire({
                icon: 'success',
                title: data.message || 'Matière supprimée.',
                timer: 1000,
                showConfirmButton: false
            });
        } else {
            showErrorToast(data.message || 'Erreur lors de la suppression.');
        }
    } catch (err) {
        console.error('deleteMatiere:', err);
        showErrorToast('Erreur réseau', err.message);
    } finally {
        hideSpinner();
    }
}

// Expositions
window.saveMatiere = saveMatiere;
window.deleteMatiere = deleteMatiere;