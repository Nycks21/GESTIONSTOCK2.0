// crud.js - Module Catégories avec visualisation
var currentCategorieId = null;
var currentMode = 'add'; // 'add', 'edit', 'view'

// Fonction utilitaire pour activer/désactiver les champs
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#categorieModal input, #categorieModal select, #categorieModal textarea');
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
}

function openAddCategorieModal(e) {
    if (e) e.preventDefault();
    currentCategorieId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-tag"></i> Ajouter une catégorie';
    document.getElementById('categorieForm').reset();
    document.getElementById('categorieActif').value = '1';
    document.getElementById('categorieParent').value = '';
    setFieldsEnabled(true);
    document.getElementById('btnSaveCategorie').style.display = '';
    clearErrors();
    loadParentDropdown();
    document.getElementById('categorieModal').style.display = 'flex';
}

function editCategorie(id) {
    var cat = AppState.categories.find(function (c) { return c.ID === id; });
    if (!cat) return;
    currentCategorieId = id;
    currentMode = 'edit';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier une catégorie';
    document.getElementById('categorieCode').value = cat.CODE || '';
    document.getElementById('categorieNom').value = cat.NOM || '';
    document.getElementById('categorieDescription').value = cat.DESCRIPTION || '';
    document.getElementById('categorieActif').value = cat.ACTIVE ? '1' : '0';
    setFieldsEnabled(true);
    document.getElementById('btnSaveCategorie').style.display = '';
    // Charger le dropdown parent et sélectionner la valeur actuelle
    loadParentDropdown(function() {
        document.getElementById('categorieParent').value = cat.PARENT_ID || '';
    });
    clearErrors();
    document.getElementById('categorieModal').style.display = 'flex';
}

function viewCategorie(id) {
    var cat = AppState.categories.find(function (c) { return c.ID === id; });
    if (!cat) return;
    currentCategorieId = id;
    currentMode = 'view';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-eye"></i> Détails de la catégorie';
    document.getElementById('categorieCode').value = cat.CODE || '';
    document.getElementById('categorieNom').value = cat.NOM || '';
    document.getElementById('categorieDescription').value = cat.DESCRIPTION || '';
    document.getElementById('categorieActif').value = cat.ACTIVE ? '1' : '0';
    // Charger le dropdown parent pour afficher le parent, mais désactivé
    loadParentDropdown(function() {
        document.getElementById('categorieParent').value = cat.PARENT_ID || '';
    });
    setFieldsEnabled(false);
    document.getElementById('btnSaveCategorie').style.display = 'none';
    clearErrors();
    document.getElementById('categorieModal').style.display = 'flex';
}

async function saveCategorie(e) {
    e.preventDefault();
    if (currentMode === 'view') {
        showToast('Info', 'Vous êtes en mode consultation, aucune modification n\'est possible.', 'info');
        return;
    }
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
            showToast('Attention', result.message || 'Échec de la suppression', 'error');
        }
    } catch (e) {
        showToast('Attention', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

function closeCategorieModal() {
    document.getElementById('categorieModal').style.display = 'none';
    currentCategorieId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-tag"></i> Ajouter une catégorie';
    setFieldsEnabled(true);
    document.getElementById('btnSaveCategorie').style.display = '';
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
window.viewCategorie = viewCategorie;
window.saveCategorie = saveCategorie;
window.deleteCategorie = deleteCategorie;
window.closeCategorieModal = closeCategorieModal;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
window.currentCategorieId = currentCategorieId;
