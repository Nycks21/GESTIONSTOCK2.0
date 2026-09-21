// crud.js – Version avec génération automatique du CODE côté serveur + i18n
var currentUniteId = null;
var currentMode = 'add'; // 'add', 'edit', 'view'

// ─── Helper i18n défensif (au cas où i18n.js n'est pas encore prêt) ───
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// UTILITAIRE : activer / désactiver les champs du modal
// ============================================================
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#uniteModal input, #uniteModal select, #uniteModal textarea');
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
function openAddUniteModal(e) {
    if (e) e.preventDefault();
    currentUniteId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-ruler"></i> ' + _t('unites.modal.add_title');

    document.getElementById('uniteForm').reset();
    document.getElementById('uniteActif').value = '1';

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('uniteCode');
    codeEl.value = '';
    codeEl.placeholder = _t('unites.modal.code_auto_placeholder');
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    setFieldsEnabled(true);

    // setFieldsEnabled réactive les champs → on réapplique le readonly sur le code
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveUnite').style.display = '';
    clearErrors();
    document.getElementById('uniteModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editUnite(id) {
    var unite = AppState.unites.find(function (u) { return u.ID === id; });
    if (!unite) return;
    currentUniteId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('unites.modal.edit_title');

    var codeEl = document.getElementById('uniteCode');
    codeEl.value = unite.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('uniteNom').value = unite.NOM || '';
    document.getElementById('uniteActif').value = unite.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);

    // Réapplication du readonly sur le code (le code est immuable)
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveUnite').style.display = '';
    clearErrors();
    document.getElementById('uniteModal').style.display = 'flex';
}

// ============================================================
// VISUALISATION
// ============================================================
function viewUnite(id) {
    var unite = AppState.unites.find(function (u) { return u.ID === id; });
    if (!unite) return;
    currentUniteId = id;
    currentMode = 'view';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + _t('unites.modal.view_title');

    var codeEl = document.getElementById('uniteCode');
    codeEl.value = unite.CODE || '';

    document.getElementById('uniteNom').value = unite.NOM || '';
    document.getElementById('uniteActif').value = unite.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveUnite').style.display = 'none';
    clearErrors();
    document.getElementById('uniteModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT (ajout ou modification)
// ============================================================
async function saveUnite(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast(_t('unites.msg.info'), _t('unites.msg.view_mode'), 'info');
        return;
    }

    var id = currentUniteId;

    // ⚠️ Le CODE n'est plus envoyé :
    //    - à l'ajout → généré côté serveur (UN-PROJET-00001)
    //    - en modification → immuable, non modifiable
    var data = {
        nom: document.getElementById('uniteNom').value.trim(),
        actif: parseInt(document.getElementById('uniteActif').value) === 1
    };

    // Validation : seul le nom est requis
    var valid = true;
    clearErrors();
    if (!data.nom) {
        showError('uniteNom', _t('unites.msg.name_required'));
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
            var msg = result.message || (id ? _t('unites.msg.updated') : _t('unites.msg.added'));
            if (result.code && !id) {
                msg = _t('unites.msg.added_with_code').replace('{code}', result.code);
            }
            showToast(_t('message.success'), msg, 'success');
            closeUniteModal();
            loadUnites();
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
async function deleteUnite(id) {
    var confirmResult = await Swal.fire({
        title: _t('unites.confirm.delete_title'),
        text: _t('unites.confirm.delete_text'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: _t('unites.confirm.delete_yes'),
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
            showToast(_t('message.success'), _t('unites.msg.deleted'), 'success');
            loadUnites();
            loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('unites.msg.delete_failed'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// FERMETURE DU MODAL
// ============================================================
function closeUniteModal() {
    document.getElementById('uniteModal').style.display = 'none';

    // Réinitialiser l'état pour le prochain usage
    currentUniteId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-ruler"></i> ' + _t('unites.modal.add_title');

    setFieldsEnabled(true);

    // Repasser le champ code en mode "généré auto"
    var codeEl = document.getElementById('uniteCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = _t('unites.modal.code_auto_placeholder');
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    }

    document.getElementById('btnSaveUnite').style.display = '';
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
window.openAddUniteModal = openAddUniteModal;
window.editUnite = editUnite;
window.viewUnite = viewUnite;
window.saveUnite = saveUnite;
window.deleteUnite = deleteUnite;
window.closeUniteModal = closeUniteModal;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
