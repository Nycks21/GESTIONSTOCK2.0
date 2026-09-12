// crud.js - Module Catégories avec génération automatique du CODE
var currentCategorieId = null;
var currentMode = 'add'; // 'add', 'edit', 'view'

// ============================================================
// UTILITAIRE : activer / désactiver les champs
// ============================================================
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

// ============================================================
// AJOUT
// ============================================================
function openAddCategorieModal(e) {
    if (e) e.preventDefault();
    currentCategorieId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-tags"></i> Ajouter une catégorie';
    document.getElementById('categorieForm').reset();
    document.getElementById('categorieActif').value = '1';
    document.getElementById('categorieParent').value = '';

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('categorieCode');
    codeEl.value = '';
    codeEl.placeholder = 'Sera généré automatiquement (CAT-XXX-00001)';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    setFieldsEnabled(true);

    // setFieldsEnabled réactive les champs → on réapplique le readonly sur le code
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveCategorie').style.display = '';
    clearErrors();
    loadParentDropdown();
    document.getElementById('categorieModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editCategorie(id) {
    var cat = AppState.categories.find(function (c) { return c.ID === id; });
    if (!cat) return;
    currentCategorieId = id;
    currentMode = 'edit';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier une catégorie';

    var codeEl = document.getElementById('categorieCode');
    codeEl.value = cat.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('categorieNom').value = cat.NOM || '';
    document.getElementById('categorieDescription').value = cat.DESCRIPTION || '';
    document.getElementById('categorieActif').value = cat.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);

    // Réapplication du readonly sur le code (le code est immuable)
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveCategorie').style.display = '';

    // Charger le dropdown parent et sélectionner la valeur actuelle
    loadParentDropdown(function () {
        document.getElementById('categorieParent').value = cat.PARENT_ID || '';
    });

    clearErrors();
    document.getElementById('categorieModal').style.display = 'flex';
}

// ============================================================
// VISUALISATION
// ============================================================
function viewCategorie(id) {
    var cat = AppState.categories.find(function (c) { return c.ID === id; });
    if (!cat) return;
    currentCategorieId = id;
    currentMode = 'view';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-eye"></i> Détails de la catégorie';

    var codeEl = document.getElementById('categorieCode');
    codeEl.value = cat.CODE || '';

    document.getElementById('categorieNom').value = cat.NOM || '';
    document.getElementById('categorieDescription').value = cat.DESCRIPTION || '';
    document.getElementById('categorieActif').value = cat.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveCategorie').style.display = 'none';

    loadParentDropdown(function () {
        document.getElementById('categorieParent').value = cat.PARENT_ID || '';
    });

    clearErrors();
    document.getElementById('categorieModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT (ajout ou modification)
// ============================================================
async function saveCategorie(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast('Info', 'Vous êtes en mode consultation, aucune modification n\'est possible.', 'info');
        return;
    }

    var id = currentCategorieId;

    // ⚠️ Le CODE n'est plus envoyé :
    //    - à l'ajout → généré côté serveur (CA-PROJET-00001)
    //    - en modification → immuable, non modifiable
    var data = {
        nom: document.getElementById('categorieNom').value.trim(),
        description: document.getElementById('categorieDescription').value.trim(),
        parentId: document.getElementById('categorieParent').value || null,
        actif: parseInt(document.getElementById('categorieActif').value) === 1
    };

    // Validation : seul le nom est requis
    var valid = true;
    clearErrors();
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
            var msg = result.message || (id ? 'Catégorie modifiée' : 'Catégorie ajoutée');
            if (result.code && !id) msg = 'Catégorie ajoutée avec succès (' + result.code + ').';
            showToast('Succès', msg, 'success');
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

// ============================================================
// SUPPRESSION
// ============================================================
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

// ============================================================
// FERMETURE DU MODAL
// ============================================================
function closeCategorieModal() {
    document.getElementById('categorieModal').style.display = 'none';

    currentCategorieId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-tags"></i> Ajouter une catégorie';

    setFieldsEnabled(true);

    // Repasser le champ code en mode "généré auto"
    var codeEl = document.getElementById('categorieCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = 'Sera généré automatiquement (CAT-XXX-00001)';
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    }

    document.getElementById('btnSaveCategorie').style.display = '';
    clearErrors();
}

// ============================================================
// GESTION DES ERREURS DE CHAMP
// ============================================================
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

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.openAddCategorieModal = openAddCategorieModal;
window.editCategorie = editCategorie;
window.viewCategorie = viewCategorie;
window.saveCategorie = saveCategorie;
window.deleteCategorie = deleteCategorie;
window.closeCategorieModal = closeCategorieModal;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
window.currentCategorieId = currentCategorieId;
