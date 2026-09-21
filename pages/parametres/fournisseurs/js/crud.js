// crud.js - Module Fournisseurs avec génération automatique du CODE + i18n
var currentFournisseurId = null;
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
    var inputs = document.querySelectorAll('#fournisseurModal input, #fournisseurModal select, #fournisseurModal textarea');
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
function openAddFournisseurModal(e) {
    if (e) e.preventDefault();
    currentFournisseurId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-truck"></i> ' + _t('fournisseurs.modal.add_title');

    document.getElementById('fournisseurForm').reset();
    document.getElementById('fournisseurActif').value = '1';

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('fournisseurCode');
    codeEl.value = '';
    codeEl.placeholder = _t('fournisseurs.modal.code_auto_placeholder');
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    setFieldsEnabled(true);

    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveFournisseur').style.display = '';
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    document.getElementById('fournisseurModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editFournisseur(id) {
    var fournisseur = AppState.fournisseurs.find(function (f) { return f.ID === id; });
    if (!fournisseur) return;
    currentFournisseurId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('fournisseurs.modal.edit_title');

    var codeEl = document.getElementById('fournisseurCode');
    codeEl.value = fournisseur.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('fournisseurNom').value = fournisseur.NOM || '';
    document.getElementById('fournisseurAdresse').value = fournisseur.ADRESSE || '';
    document.getElementById('fournisseurTelephone').value = fournisseur.TELEPHONE || '';
    document.getElementById('fournisseurEmail').value = fournisseur.EMAIL || '';
    document.getElementById('fournisseurContactNom').value = fournisseur.CONTACT_NOM || '';
    document.getElementById('fournisseurContactTelephone').value = fournisseur.CONTACT_TELEPHONE || '';
    document.getElementById('fournisseurSiret').value = fournisseur.SIRET || '';
    document.getElementById('fournisseurActif').value = fournisseur.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);

    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveFournisseur').style.display = '';
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    document.getElementById('fournisseurModal').style.display = 'flex';
}

// ============================================================
// VISUALISATION
// ============================================================
function viewFournisseur(id) {
    var fournisseur = AppState.fournisseurs.find(function (f) { return f.ID === id; });
    if (!fournisseur) return;
    currentFournisseurId = id;
    currentMode = 'view';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + _t('fournisseurs.modal.view_title');

    var codeEl = document.getElementById('fournisseurCode');
    codeEl.value = fournisseur.CODE || '';

    document.getElementById('fournisseurNom').value = fournisseur.NOM || '';
    document.getElementById('fournisseurAdresse').value = fournisseur.ADRESSE || '';
    document.getElementById('fournisseurTelephone').value = fournisseur.TELEPHONE || '';
    document.getElementById('fournisseurEmail').value = fournisseur.EMAIL || '';
    document.getElementById('fournisseurContactNom').value = fournisseur.CONTACT_NOM || '';
    document.getElementById('fournisseurContactTelephone').value = fournisseur.CONTACT_TELEPHONE || '';
    document.getElementById('fournisseurSiret').value = fournisseur.SIRET || '';
    document.getElementById('fournisseurActif').value = fournisseur.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveFournisseur').style.display = 'none';
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    document.getElementById('fournisseurModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT
// ============================================================
async function saveFournisseur(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast(_t('fournisseurs.msg.info'), _t('fournisseurs.msg.view_mode'), 'info');
        return;
    }

    var id = currentFournisseurId;

    var data = {
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
    if (!data.nom) {
        showFieldError('fournisseurNom', _t('fournisseurs.msg.name_required'));
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
            var msg = result.message || (id ? _t('fournisseurs.msg.updated') : _t('fournisseurs.msg.added'));
            if (result.code && !id) {
                msg = _t('fournisseurs.msg.added_with_code').replace('{code}', result.code);
            }
            showToast(_t('message.success'), msg, 'success');
            closeFournisseurModal();
            loadFournisseurs();
            loadFournisseurStats();
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
async function deleteFournisseur(id) {
    var confirmResult = await Swal.fire({
        title: _t('fournisseurs.confirm.delete_title'),
        text: _t('fournisseurs.confirm.delete_text'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: _t('fournisseurs.confirm.delete_yes'),
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
            showToast(_t('message.success'), _t('fournisseurs.msg.deleted'), 'success');
            loadFournisseurs();
            loadFournisseurStats();
        } else {
            showToast(_t('message.warning'), result.message || _t('fournisseurs.msg.delete_failed'), 'error');
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
function closeFournisseurModal() {
    document.getElementById('fournisseurModal').style.display = 'none';

    currentFournisseurId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-truck"></i> ' + _t('fournisseurs.modal.add_title');

    setFieldsEnabled(true);

    var codeEl = document.getElementById('fournisseurCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = _t('fournisseurs.modal.code_auto_placeholder');
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    }

    document.getElementById('btnSaveFournisseur').style.display = '';
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
}

// ============================================================
// GESTION DES ERREURS DE CHAMP
// ============================================================
function showFieldError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) {
        errEl.textContent = msg;
        errEl.style.display = 'block';
    }
}

function clearFieldErrors(fieldIds) {
    if (!fieldIds) return;
    fieldIds.forEach(function (id) {
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
window.openAddFournisseurModal = openAddFournisseurModal;
window.editFournisseur = editFournisseur;
window.viewFournisseur = viewFournisseur;
window.saveFournisseur = saveFournisseur;
window.deleteFournisseur = deleteFournisseur;
window.closeFournisseurModal = closeFournisseurModal;
window.setFieldsEnabled = setFieldsEnabled;
window.clearFieldErrors = clearFieldErrors;
window.currentFournisseurId = currentFournisseurId;
