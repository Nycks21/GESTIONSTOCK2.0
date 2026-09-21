// crud.js - Module Catégories avec génération automatique du CODE + i18n
var currentCategorieId = null;
var currentMode = 'add'; // 'add', 'edit', 'view'

// ─── Helper i18n défensif ───
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

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

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-tags"></i> ' + _t('categories.modal.add_title');

    document.getElementById('categorieForm').reset();
    document.getElementById('categorieActif').value = '1';
    document.getElementById('categorieParent').value = '';

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('categorieCode');
    codeEl.value = '';
    codeEl.placeholder = _t('categories.modal.code_auto_placeholder');
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    setFieldsEnabled(true);

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

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('categories.modal.edit_title');

    var codeEl = document.getElementById('categorieCode');
    codeEl.value = cat.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('categorieNom').value = cat.NOM || '';
    document.getElementById('categorieDescription').value = cat.DESCRIPTION || '';
    document.getElementById('categorieActif').value = cat.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);

    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveCategorie').style.display = '';

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

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + _t('categories.modal.view_title');

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
// ENREGISTREMENT
// ============================================================
async function saveCategorie(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast(_t('categories.msg.info'), _t('categories.msg.view_mode'), 'info');
        return;
    }

    var id = currentCategorieId;

    var data = {
        nom: document.getElementById('categorieNom').value.trim(),
        description: document.getElementById('categorieDescription').value.trim(),
        parentId: document.getElementById('categorieParent').value || null,
        actif: parseInt(document.getElementById('categorieActif').value) === 1
    };

    var valid = true;
    clearErrors();
    if (!data.nom) {
        showError('categorieNom', _t('categories.msg.name_required'));
        valid = false;
    }
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
            var msg = result.message || (id ? _t('categories.msg.updated') : _t('categories.msg.added'));
            if (result.code && !id) {
                msg = _t('categories.msg.added_with_code').replace('{code}', result.code);
            }
            showToast(_t('message.success'), msg, 'success');
            closeCategorieModal();
            loadCategories();
            loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('message.error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// SUPPRESSION
// ============================================================
async function deleteCategorie(id) {
    var confirmResult = await Swal.fire({
        title: _t('categories.confirm.delete_title'),
        text: _t('categories.confirm.delete_text'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: _t('categories.confirm.delete_yes'),
        cancelButtonText: _t('button.cancel')
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
            showToast(_t('message.success'), _t('categories.msg.deleted'), 'success');
            loadCategories();
            loadStats();
        } else {
            showToast(_t('message.warning'), result.message || _t('categories.msg.delete_failed'), 'error');
        }
    } catch (err) {
        showToast(_t('message.warning'), err.message, 'error');
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

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-tags"></i> ' + _t('categories.modal.add_title');

    setFieldsEnabled(true);

    var codeEl = document.getElementById('categorieCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = _t('categories.modal.code_auto_placeholder');
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
    if (errEl) {
        errEl.textContent = msg;
        errEl.style.display = 'block';
    }
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
