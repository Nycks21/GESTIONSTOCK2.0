/**
 * crud.js - Opérations CRUD pour le module Classes
 */

'use strict';

// ─────────────────────────────────────────────
// SAUVEGARDER (Ajouter ou Modifier)
// ─────────────────────────────────────────────
async function saveClasse() {
    console.log('🔵 saveClasse appelée');

    // Validation du formulaire
    if (!validateClasseForm()) {
        console.warn('⚠️ Formulaire invalide');
        return;
    }

    // Récupération des valeurs
    var payload = {
        NOM: getVal('ClasseNom'),
        NIVEAU_ID: getVal('ClasseNiveau'),
        TITULAIRE_ID: parseInt(getVal('ClasseUser'), 10),
        SALLE_ID: getVal('ClasseSalle'),
        EFFECTIF: parseInt(getVal('ClasseEffectif'), 10) || 0,
        STATUT: getVal('ClasseStatut').toLowerCase() === 'actif' ? 'actif' : 'inactif'
    };

    var estUneModification = STATE.isEditMode;
    var url = estUneModification ? API_CLASSES.modifier : API_CLASSES.ajouter;
    if (estUneModification) {
        payload.ID = STATE.editId;
    }

    console.log('📤 Envoi payload:', payload);
    console.log('🔗 URL:', url);

    var btnSave = document.querySelector('#addClasseModal .btn-primary');
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

        // Gestion des erreurs HTTP
        if (!res.ok) {
            var errorText = await res.text();
            var errorMessage = 'Erreur ' + res.status;
            try {
                var errorJson = JSON.parse(errorText);
                if (errorJson.message) errorMessage = errorJson.message;
            } catch (e) {
                // Si ce n'est pas du JSON, on affiche le texte brut (utile pour voir les erreurs ASP.NET)
                console.error('Réponse non JSON reçue :', errorText);
                errorMessage = errorText.substring(0, 200); // limite pour éviter de noyer la console
            }
            throw new Error(errorMessage);
        }

        var data = await res.json();

        if (data.success) {
            showToast(data.message || 'Opération réussie', 'success');
            setTimeout(function () {
                closeAddClasseModal();
                loadClasses();
            }, 1500);
        } else {
            showErrorToast(data.message || 'Erreur inconnue.');
        }
    } catch (err) {
        console.error('❌ Erreur saveClasse:', err);
        showErrorToast('Erreur lors de l\'enregistrement', err.message);
    } finally {
        hideSpinner();
        if (btnSave) {
            btnSave.disabled = false;
            btnSave.innerHTML = '<i class="fas fa-save"></i> Enregistrer';
        }
    }
}

// ─────────────────────────────────────────────
// ÉDITER
// ─────────────────────────────────────────────
function editClasse(id) {
    console.log('🔵 editClasse appelée pour ID:', id);

    var classe = STATE.classesData.find(function (item) {
        return String(item.ID) === String(id);
    });

    if (!classe) {
        console.error("❌ Classe introuvable pour l'ID : " + id);
        showErrorToast('Classe introuvable.', 'ID: ' + id);
        return;
    }

    STATE.editId = id;
    STATE.isEditMode = true;

    document.getElementById('classeEditId').value = id;
    setVal('ClasseNom', classe.NOM);
    setVal('ClasseNiveau', classe.NIVEAU_ID);
    setVal('ClasseUser', classe.TITULAIRE_ID);
    setVal('ClasseSalle', classe.SALLE_ID);
    setVal('ClasseEffectif', classe.EFFECTIF);
    setVal('ClasseStatut', classe.STATUT ? 'Actif' : 'Inactif');

    var titleElement = document.getElementById('classeModalTitle');
    if (titleElement) {
        titleElement.innerHTML = '<i class="fas fa-edit"></i> Modifier la classe';
    }

    showModal('addClasseModal');
    document.getElementById('ClasseNom').focus();
}

// ─────────────────────────────────────────────
// SUPPRIMER
// ─────────────────────────────────────────────
async function deleteClasse(id, nom) {
    console.log('🔵 deleteClasse appelée pour:', nom);

    var result = await Swal.fire({
        title: 'Confirmation',
        html: 'Supprimer la classe <strong>' + escapeHtml(nom) + '</strong> ? Cette action est irréversible.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    });

    if (!result.isConfirmed) return;

    showSpinner();

    try {
        var res = await fetch(API_CLASSES.supprimer, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ID: id })
        });

        var data = await safeJson(res);

        if (data.success) {
            await loadClasses();
            Swal.fire({
                icon: 'success',
                title: data.message || 'Classe supprimée.',
                timer: 1000,
                showConfirmButton: false
            });
        } else {
            showErrorToast(data.message || 'Erreur lors de la suppression.');
        }
    } catch (err) {
        console.error('❌ Erreur deleteClasse:', err);
        showErrorToast('Erreur réseau', err.message);
    } finally {
        hideSpinner();
    }
}

// ─────────────────────────────────────────────
// EXPOSITION GLOBALE
// ─────────────────────────────────────────────
window.saveClasse = saveClasse;
window.editClasse = editClasse;
window.deleteClasse = deleteClasse;

console.log('✅ crud.js (Classes) chargé');