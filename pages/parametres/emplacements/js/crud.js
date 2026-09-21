// crud.js - Module Emplacements avec génération automatique du CODE + i18n
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
    var inputs = document.querySelectorAll('#emplacementModal input, #emplacementModal select, #emplacementModal textarea');
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
function openAddEmplacementModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-warehouse"></i> ' + _t('emplacements.modal.add_title');

    document.getElementById('emplacementForm').reset();
    document.getElementById('emplacementActif').value = '1';
    document.getElementById('emplacementParent').value = '';

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('emplacementCode');
    codeEl.value = '';
    codeEl.placeholder = _t('emplacements.modal.code_auto_placeholder');
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    setFieldsEnabled(true);

    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveEmplacement').style.display = '';
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    document.getElementById('emplacementModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editEmplacement(id) {
    var emplacement = AppState.emplacements.find(function (e) { return e.ID === id; });
    if (!emplacement) return;
    AppState.editingId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('emplacements.modal.edit_title');

    var codeEl = document.getElementById('emplacementCode');
    codeEl.value = emplacement.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('emplacementNom').value = emplacement.NOM || '';
    document.getElementById('emplacementType').value = emplacement.TYPE || '';
    document.getElementById('emplacementParent').value = emplacement.PARENT_ID || '';
    document.getElementById('emplacementActif').value = emplacement.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);

    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveEmplacement').style.display = '';
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    document.getElementById('emplacementModal').style.display = 'flex';
}

// ============================================================
// VISUALISATION
// ============================================================
function viewEmplacement(id) {
    var emplacement = AppState.emplacements.find(function (e) { return e.ID === id; });
    if (!emplacement) return;
    AppState.editingId = id;
    currentMode = 'view';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + _t('emplacements.modal.view_title');

    var codeEl = document.getElementById('emplacementCode');
    codeEl.value = emplacement.CODE || '';

    document.getElementById('emplacementNom').value = emplacement.NOM || '';
    document.getElementById('emplacementType').value = emplacement.TYPE || '';
    document.getElementById('emplacementParent').value = emplacement.PARENT_ID || '';
    document.getElementById('emplacementActif').value = emplacement.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveEmplacement').style.display = 'none';
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    document.getElementById('emplacementModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT
// ============================================================
async function saveEmplacement(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast(_t('emplacements.msg.info'), _t('emplacements.msg.view_mode'), 'info');
        return;
    }

    var id = AppState.editingId;

    var data = {
        nom: document.getElementById('emplacementNom').value.trim(),
        type: document.getElementById('emplacementType').value,
        parentId: document.getElementById('emplacementParent').value || null,
        actif: parseInt(document.getElementById('emplacementActif').value) === 1
    };

    var valid = true;
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    if (!data.nom) {
        showFieldError('emplacementNom', _t('emplacements.msg.name_required'));
        valid = false;
    }
    if (!data.type) {
        showFieldError('emplacementType', _t('emplacements.msg.type_required'));
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
            var msg = result.message || (id ? _t('emplacements.msg.updated') : _t('emplacements.msg.added'));
            if (result.code && !id) {
                msg = _t('emplacements.msg.added_with_code').replace('{code}', result.code);
            }
            showToast(_t('message.success'), msg, 'success');
            closeEmplacementModal();
            loadEmplacements();
            loadStats();
        } else {
            showToast(_t('message.warning'), result.message || _t('message.error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.warning'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// SUPPRESSION
// ============================================================
async function deleteEmplacement(id) {
    var confirmResult = await Swal.fire({
        title: _t('emplacements.confirm.delete_title'),
        text: _t('emplacements.confirm.delete_text'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: _t('emplacements.confirm.delete_yes'),
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
            showToast(_t('message.success'), _t('emplacements.msg.deleted'), 'success');
            loadEmplacements();
            loadStats();
        } else {
            showToast(_t('message.warning'), result.message || _t('emplacements.msg.delete_failed'), 'error');
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
function closeEmplacementModal() {
    document.getElementById('emplacementModal').style.display = 'none';
    AppState.editingId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-warehouse"></i> ' + _t('emplacements.modal.add_title');

    setFieldsEnabled(true);

    var codeEl = document.getElementById('emplacementCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = _t('emplacements.modal.code_auto_placeholder');
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    }

    document.getElementById('btnSaveEmplacement').style.display = '';
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
}

// ============================================================
// GESTION DES ERREURS DE CHAMP
// ============================================================
function showFieldError(fieldId, msg) {
    var err = document.getElementById('err-' + fieldId);
    if (err) {
        err.textContent = msg;
        err.style.display = 'block';
    }
}

function clearFieldErrors(ids) {
    if (!ids) return;
    ids.forEach(function (id) {
        var err = document.getElementById('err-' + id);
        if (err) {
            err.textContent = '';
            err.style.display = 'none';
        }
    });
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.openAddEmplacementModal = openAddEmplacementModal;
window.editEmplacement = editEmplacement;
window.viewEmplacement = viewEmplacement;
window.saveEmplacement = saveEmplacement;
window.deleteEmplacement = deleteEmplacement;
window.closeEmplacementModal = closeEmplacementModal;
window.setFieldsEnabled = setFieldsEnabled;
window.clearFieldErrors = clearFieldErrors;
