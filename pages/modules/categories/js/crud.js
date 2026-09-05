var currentCategorieId = null;

function openAddCategorieModal(e) {
    if (e) e.preventDefault();
    currentCategorieId = null;
    document.getElementById('modalTitle').textContent = 'Ajouter une catégorie';
    document.getElementById('categorieForm').reset();
    document.getElementById('categorieActif').value = '1';
    document.getElementById('categorieParent').value = '';
    clearErrors();
    loadParentDropdown();
    document.getElementById('categorieModal').style.display = 'flex';
}

function editCategorie(id) {
    var cat = AppState.categories.find(function (c) { return c.ID === id; });
    if (!cat) return;
    currentCategorieId = id;
    document.getElementById('modalTitle').textContent = 'Modifier une catégorie';
    document.getElementById('categorieCode').value = cat.CODE || '';
    document.getElementById('categorieNom').value = cat.NOM || '';
    document.getElementById('categorieDescription').value = cat.DESCRIPTION || '';
    document.getElementById('categorieActif').value = cat.ACTIVE ? '1' : '0';
    // Charger le dropdown parent et sélectionner la valeur actuelle
    loadParentDropdown(function() {
        document.getElementById('categorieParent').value = cat.PARENT_ID || '';
    });
    clearErrors();
    document.getElementById('categorieModal').style.display = 'flex';
}

async function saveCategorie(e) {
    e.preventDefault();
    var id = currentCategorieId;
    var data = {
        code: document.getElementById('categorieCode').value.trim(),
        nom: document.getElementById('categorieNom').value.trim(),
        description: document.getElementById('categorieDescription').value.trim(),
        parentId: document.getElementById('categorieParent').value || null,
        actif: parseInt(document.getElementById('categorieActif').value) === 1
    };

    var valid = true;
    clearErrors();
    if (!data.code) { showError('categorieCode', 'Le code est requis'); valid = false; }
    if (!data.nom) { showError('categorieNom', 'Le nom est requis'); valid = false; }
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
            showToast('Succès', result.message || (id ? 'Catégorie modifiée' : 'Catégorie ajoutée'), 'success');
            closeCategorieModal();
            loadCategories();
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

async function deleteCategorie(id) {
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer cette catégorie ?',
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
            showToast('Succès', 'Catégorie supprimée', 'success');
            loadCategories();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Échec de la suppression', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

function closeCategorieModal() {
    document.getElementById('categorieModal').style.display = 'none';
    currentCategorieId = null;
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
window.openAddCategorieModal = openAddCategorieModal;
window.editCategorie = editCategorie;
window.saveCategorie = saveCategorie;
window.deleteCategorie = deleteCategorie;
window.closeCategorieModal = closeCategorieModal;
window.clearErrors = clearErrors;
window.currentCategorieId = currentCategorieId;
