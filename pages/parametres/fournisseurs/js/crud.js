// crud.js
var currentFournisseurId = null;

function openAddFournisseurModal(e) {
    if (e) e.preventDefault();
    currentFournisseurId = null;
    document.getElementById('modalTitle').textContent = 'Ajouter un fournisseur';
    document.getElementById('fournisseurForm').reset();
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    document.getElementById('fournisseurModal').style.display = 'flex';
}

function editFournisseur(id) {
    var fournisseur = AppState.fournisseurs.find(function (f) { return f.ID === id; });
    if (!fournisseur) return;
    currentFournisseurId = id;
    document.getElementById('modalTitle').textContent = 'Modifier un fournisseur';
    document.getElementById('fournisseurCode').value = fournisseur.CODE || '';
    document.getElementById('fournisseurNom').value = fournisseur.NOM || '';
    document.getElementById('fournisseurAdresse').value = fournisseur.ADRESSE || '';
    document.getElementById('fournisseurTelephone').value = fournisseur.TELEPHONE || '';
    document.getElementById('fournisseurEmail').value = fournisseur.EMAIL || '';
    document.getElementById('fournisseurContactNom').value = fournisseur.CONTACT_NOM || '';
    document.getElementById('fournisseurContactTelephone').value = fournisseur.CONTACT_TELEPHONE || '';
    document.getElementById('fournisseurSiret').value = fournisseur.SIRET || '';
    document.getElementById('fournisseurActif').value = fournisseur.ACTIVE ? '1' : '0';
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    document.getElementById('fournisseurModal').style.display = 'flex';
}

async function saveFournisseur(e) {
    e.preventDefault();
    var id = currentFournisseurId;
    var data = {
        code: document.getElementById('fournisseurCode').value.trim(),
        nom: document.getElementById('fournisseurNom').value.trim(),
        adresse: document.getElementById('fournisseurAdresse').value.trim(),
        telephone: document.getElementById('fournisseurTelephone').value.trim(),
        email: document.getElementById('fournisseurEmail').value.trim(),
        contactNom: document.getElementById('fournisseurContactNom').value.trim(),
        contactTelephone: document.getElementById('fournisseurContactTelephone').value.trim(),
        siret: document.getElementById('fournisseurSiret').value.trim(),
        actif: parseInt(document.getElementById('fournisseurActif').value) === 1
    };

    var valid = true;
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    if (!data.code) { showFieldError('fournisseurCode', 'Le code est requis'); valid = false; }
    if (!data.nom) { showFieldError('fournisseurNom', 'Le nom est requis'); valid = false; }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload = id ? Object.assign({}, data, { id: id }) : data;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + endpoint;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        var result = await resp.json();
        if (result.success) {
            showToast('Succès', result.message || (id ? 'Fournisseur modifié' : 'Fournisseur ajouté'), 'success');
            closeFournisseurModal();
            loadFournisseurs();
            loadFournisseurStats();
        } else {
            showToast('Erreur', result.message || 'Une erreur est survenue', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

async function deleteFournisseur(id) {
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer ce fournisseur ?',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    });
    if (!confirmResult.isConfirmed) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.DELETE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        });
        var result = await resp.json();
        if (result.success) {
            showToast('Succès', 'Fournisseur supprimé', 'success');
            loadFournisseurs();
            loadFournisseurStats();
        } else {
            showToast('Erreur', result.message || 'Échec de la suppression', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

function closeFournisseurModal() {
    document.getElementById('fournisseurModal').style.display = 'none';
    currentFournisseurId = null;
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
}

function showFieldError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
}

function clearFieldErrors(fieldIds) {
    fieldIds.forEach(function(id) {
        var err = document.getElementById('err-' + id);
        if (err) { err.textContent = ''; err.style.display = 'none'; }
    });
}

// Expositions globales
window.openAddFournisseurModal = openAddFournisseurModal;
window.editFournisseur = editFournisseur;
window.saveFournisseur = saveFournisseur;
window.deleteFournisseur = deleteFournisseur;
window.closeFournisseurModal = closeFournisseurModal;
