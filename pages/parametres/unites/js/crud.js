// crud.js
var currentUniteId = null;

function openAddUniteModal(e) {
    if (e) e.preventDefault();
    currentUniteId = null;
    document.getElementById('modalTitle').textContent = 'Ajouter une unité';
    document.getElementById('uniteForm').reset();
    document.getElementById('uniteActif').value = '1';
    clearErrors();
    document.getElementById('uniteModal').style.display = 'flex';
}

function editUnite(id) {
    var unite = AppState.unites.find(function (u) { return u.ID === id; });
    if (!unite) return;
    currentUniteId = id;
    document.getElementById('modalTitle').textContent = 'Modifier une unité';
    document.getElementById('uniteCode').value = unite.CODE || '';
    document.getElementById('uniteNom').value = unite.NOM || '';
    document.getElementById('uniteActif').value = unite.ACTIVE ? '1' : '0';
    clearErrors();
    document.getElementById('uniteModal').style.display = 'flex';
}

async function saveUnite(e) {
    e.preventDefault();
    var id = currentUniteId;
    var data = {
        code: document.getElementById('uniteCode').value.trim(),
        nom: document.getElementById('uniteNom').value.trim(),
        actif: parseInt(document.getElementById('uniteActif').value) === 1
    };

    var valid = true;
    clearErrors();
    if (!data.code) { showError('uniteCode', 'Le code est requis'); valid = false; }
    if (!data.nom) { showError('uniteNom', 'Le nom est requis'); valid = false; }
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
            showToast('Succès', result.message || (id ? 'Unité modifiée' : 'Unité ajoutée'), 'success');
            closeUniteModal();
            loadUnites();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Une erreur est survenue', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

async function deleteUnite(id) {
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer cette unité ?',
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
            showToast('Succès', 'Unité supprimée', 'success');
            loadUnites();
            loadStats();
        } else {
            showToast('Attention', result.message || 'Échec de la suppression', 'error');
        }
    } catch (e) {
        showToast('Attention', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

function closeUniteModal() {
    document.getElementById('uniteModal').style.display = 'none';
    currentUniteId = null;
    clearErrors();
}

function showError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
}

function clearErrors() {
    var errors = document.querySelectorAll('.field-error');
    for (var i = 0; i < errors.length; i++) {
        errors[i].textContent = '';
        errors[i].style.display = 'none';
    }
}

// Expositions
window.openAddUniteModal = openAddUniteModal;
window.editUnite = editUnite;
window.saveUnite = saveUnite;
window.deleteUnite = deleteUnite;
window.closeUniteModal = closeUniteModal;
window.clearErrors = clearErrors;
window.currentUniteId = currentUniteId;
