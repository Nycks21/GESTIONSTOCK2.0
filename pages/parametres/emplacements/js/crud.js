// crud.js

function openAddEmplacementModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    document.getElementById('modalTitle').textContent = 'Ajouter un emplacement';
    document.getElementById('emplacementForm').reset();
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    document.getElementById('emplacementModal').style.display = 'flex';
}

function editEmplacement(id) {
    var emplacement = AppState.emplacements.find(function(e) { return e.ID === id; });
    if (!emplacement) return;
    AppState.editingId = id;
    document.getElementById('modalTitle').textContent = 'Modifier un emplacement';
    document.getElementById('emplacementCode').value = emplacement.CODE || '';
    document.getElementById('emplacementNom').value = emplacement.NOM || '';
    document.getElementById('emplacementType').value = emplacement.TYPE || '';
    document.getElementById('emplacementParent').value = emplacement.PARENT_ID || '';
    document.getElementById('emplacementActif').value = emplacement.ACTIVE ? '1' : '0';
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    document.getElementById('emplacementModal').style.display = 'flex';
}

async function saveEmplacement(e) {
    e.preventDefault();
    var id = AppState.editingId;
    var data = {
        code: document.getElementById('emplacementCode').value.trim(),
        nom: document.getElementById('emplacementNom').value.trim(),
        type: document.getElementById('emplacementType').value,
        parentId: document.getElementById('emplacementParent').value || null,
        actif: parseInt(document.getElementById('emplacementActif').value) === 1
    };

    var valid = true;
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    if (!data.code) { showFieldError('emplacementCode', 'Le code est requis'); valid = false; }
    if (!data.nom) { showFieldError('emplacementNom', 'Le nom est requis'); valid = false; }
    if (!data.type) { showFieldError('emplacementType', 'Le type est requis'); valid = false; }
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
            showToast('Succès', result.message || (id ? 'Emplacement modifié' : 'Emplacement ajouté'), 'success');
            closeEmplacementModal();
            loadEmplacements();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Une erreur est survenue', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

function showFieldError(fieldId, msg) {
    var err = document.getElementById('err-' + fieldId);
    if (err) { err.textContent = msg; err.style.display = 'block'; }
}

async function deleteEmplacement(id) {
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer cet emplacement ?',
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
            showToast('Succès', 'Emplacement supprimé', 'success');
            loadEmplacements();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Échec de la suppression', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

function closeEmplacementModal() {
    document.getElementById('emplacementModal').style.display = 'none';
    AppState.editingId = null;
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
}

// Expositions globales
window.openAddEmplacementModal = openAddEmplacementModal;
window.editEmplacement = editEmplacement;
window.saveEmplacement = saveEmplacement;
window.deleteEmplacement = deleteEmplacement;
window.closeEmplacementModal = closeEmplacementModal;
