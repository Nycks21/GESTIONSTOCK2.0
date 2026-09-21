// ============================================================
// CRUD - SORTIES
// ============================================================
var currentMode = 'add';

// ============================================================
// UTILITAIRES UI
// ============================================================
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#sortieModal input, #sortieModal select, #sortieModal textarea');
    for (var i = 0; i < inputs.length; i++) {
        if (inputs[i].id === 'sortieNumero') continue;
        inputs[i].disabled = !enabled;
        if (!enabled) {
            inputs[i].style.backgroundColor = '#e9ecef';
            inputs[i].style.color = '#6c757d';
            inputs[i].style.cursor = 'not-allowed';
            inputs[i].style.borderColor = '#dee2e6';
        } else {
            inputs[i].style.backgroundColor = '';
            inputs[i].style.color = '';
            inputs[i].style.cursor = '';
            inputs[i].style.borderColor = '';
        }
    }
    var iconBtns = document.querySelectorAll('#sortieModal .btn-icon');
    for (var j = 0; j < iconBtns.length; j++) iconBtns[j].disabled = !enabled;

    var articleSelects = document.querySelectorAll('#lignesBody .ligne-article');
    for (var m = 0; m < articleSelects.length; m++) {
        if (!enabled) {
            articleSelects[m].style.backgroundColor = '#e9ecef';
            articleSelects[m].style.color = '#6c757d';
            articleSelects[m].style.cursor = 'not-allowed';
        } else {
            articleSelects[m].style.backgroundColor = '';
            articleSelects[m].style.color = '';
            articleSelects[m].style.cursor = '';
        }
    }
}

function setAnnulerButtonVisible(visible) {
    var btnAnnuler = document.getElementById('btnAnnulerSortie');
    if (btnAnnuler) btnAnnuler.style.display = visible ? '' : 'none';
}

function setNumeroReadOnly() {
    var numEl = document.getElementById('sortieNumero');
    if (!numEl) return;
    numEl.readOnly = true;
    numEl.style.backgroundColor = '#e9ecef';
    numEl.style.color = '#6c757d';
    numEl.style.cursor = 'not-allowed';
}

function setButtonLoading(btn, loading, loadingText) {
    if (!btn) return;
    if (loading) {
        if (!btn.dataset.originalHtml) btn.dataset.originalHtml = btn.innerHTML;
        btn.disabled = true;
        btn.style.opacity = '0.75';
        btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> ' + (loadingText || 'Traitement…');
    } else {
        btn.disabled = false;
        btn.style.opacity = '1';
        if (btn.dataset.originalHtml) {
            btn.innerHTML = btn.dataset.originalHtml;
            delete btn.dataset.originalHtml;
        }
    }
}

// ============================================================
// AJOUT
// ============================================================
function openAddSortieModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-truck"></i> ' + T('sorties.modal.add_title', 'Nouveau bon de sortie');

    document.getElementById('sortieForm').reset();

    var now = new Date().toISOString().slice(0, 16);
    document.getElementById('sortieDate').value = now;

    var numEl = document.getElementById('sortieNumero');
    numEl.value = '';
    numEl.placeholder = T('sorties.modal.numero_auto_placeholder', 'Sera généré automatiquement (SOR-XXX-00001)');
    setNumeroReadOnly();

    document.getElementById('lignesBody').innerHTML = '';
    setFieldsEnabled(true);
    setNumeroReadOnly();

    document.getElementById('btnSaveSortie').style.display = '';
    setAnnulerButtonVisible(true);
    ajouterLigne();
    clearErrors();
    showModal('sortieModal');
}

// ============================================================
// MODIFICATION
// ============================================================
function editSortie(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!sortie) return;

    AppState.editingId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + T('sorties.modal.edit_title', 'Modifier le bon de sortie');

    chargerSortieDansModal(sortie);
    setFieldsEnabled(true);
    setNumeroReadOnly();
    document.getElementById('btnSaveSortie').style.display = '';
    setAnnulerButtonVisible(true);
    clearErrors();
    showModal('sortieModal');
}

// ============================================================
// VISUALISATION
// ============================================================
function viewSortie(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!sortie) return;

    AppState.editingId = id;
    currentMode = 'view';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + T('sorties.modal.view_title', 'Détails du bon de sortie');

    chargerSortieDansModal(sortie);
    setFieldsEnabled(false);
    setNumeroReadOnly();
    document.getElementById('btnSaveSortie').style.display = 'none';
    setAnnulerButtonVisible(false);
    clearErrors();
    showModal('sortieModal');
}

// ============================================================
// CHARGEMENT DANS LE MODAL
// ============================================================
function chargerSortieDansModal(sortie) {
    var numEl = document.getElementById('sortieNumero');
    numEl.value = sortie.NUMERO || '';
    setNumeroReadOnly();

    var dateStr = '';
    if (sortie.DATE_SORTIE) {
        try {
            var dateValue = String(sortie.DATE_SORTIE);
            var dotNetDate = dateValue.match(/^\/Date\((-?\d+)\)\/$/);
            var d = dotNetDate ? new Date(Number(dotNetDate[1])) : new Date(dateValue);
            if (!isNaN(d.getTime())) {
                var pad = function (v) { return String(v).padStart(2, '0'); };
                dateStr = d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
                    'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
            }
        } catch (e) { /* ignore */ }
    }
    document.getElementById('sortieDate').value = dateStr;

    document.getElementById('sortieDestination').value = sortie.DESTINATION || '';
    document.getElementById('sortieNom').value         = sortie.NOM         || '';
    document.getElementById('sortieFonction').value    = sortie.FONCTION    || '';
    document.getElementById('sortieNotes').value       = sortie.NOTES       || '';

    document.getElementById('lignesBody').innerHTML = '';
    var lignes = sortie.Lignes || [];
    if (lignes.length) {
        lignes.forEach(function (l) {
            ajouterLigne(l.ARTICLE_ID, l.QUANTITE_D, l.QUANTITE_R, l.OBSERVATIONS);
        });
    } else {
        ajouterLigne();
    }
}

// ============================================================
// ENREGISTREMENT
// ============================================================
async function saveSortie(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast(T('sorties.msg.info', 'Info'),
                  T('sorties.msg.view_mode', "Vous êtes en mode consultation, aucune modification n'est possible."),
                  'info');
        return;
    }

    var id = AppState.editingId;
    var data = {
        dateSortie:  document.getElementById('sortieDate').value,
        destination: document.getElementById('sortieDestination').value.trim(),
        nom:         document.getElementById('sortieNom').value.trim(),
        fonction:    document.getElementById('sortieFonction').value.trim(),
        notes:       document.getElementById('sortieNotes').value.trim(),
        lignes:      getLignesFromModal()
    };

    var valid = true;
    clearErrors();
    if (!data.dateSortie)  { showError('sortieDate',        T('sorties.msg.date_required',        'La date est requise')); valid = false; }
    if (!data.destination) { showError('sortieDestination', T('sorties.msg.destination_required', 'La destination est requise')); valid = false; }
    if (!data.lignes.length) {
        showToast(T('message.error', 'Erreur'),
                  T('sorties.msg.line_required', "Ajoutez au moins une ligne d'article"),
                  'error');
        valid = false;
    }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload  = id ? Object.assign({}, data, { id: id }) : data;
    var btnSave  = document.getElementById('btnSaveSortie');

    try {
        showSpinner();
        setButtonLoading(btnSave, true, 'Enregistrement…');

        var url  = API.BASE + API.HANDLERS_PATH + endpoint;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        var result = await resp.json();

        if (result.success) {
            var msg;
            if (result.numero && !id) {
                msg = T('sorties.msg.added_with_numero',
                        'Bon de sortie créé avec succès ({numero}).',
                        { numero: result.numero });
            } else {
                msg = result.message || (id
                    ? T('sorties.msg.updated', 'Bon modifié')
                    : T('sorties.msg.added',   'Bon de sortie créé'));
            }
            showToast(T('message.success', 'Succès'), msg, 'success');
            closeSortieModal();
            loadSorties();
            loadSortieStats();
            if (typeof updateSortieBadge === 'function') updateSortieBadge();
        } else {
            showToast(T('message.error', 'Erreur'),
                      result.message || T('sorties.msg.save_error', 'Une erreur est survenue'),
                      'error');
        }
    } catch (err) {
        showToast(T('message.error', 'Erreur'), err.message, 'error');
    } finally {
        setButtonLoading(btnSave, false);
        hideSpinner();
    }
}

// ============================================================
// SUPPRESSION
// ============================================================
async function deleteSortie(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (sortie && sortie.STATUT === 'VALIDE') {
        showToast(T('message.warning', 'Attention'),
                  T('sorties.msg.delete_validated', 'Impossible de supprimer un bon de sortie validé.'),
                  'warning');
        return;
    }

    var confirmResult = await Swal.fire({
        title: T('sorties.confirm.delete_title', 'Confirmer la suppression'),
        html:
            '<p style="margin-bottom:14px;color:#495057;">' +
                T('sorties.msg.delete_confirm', 'Voulez-vous vraiment supprimer ce bon de sortie ?') +
            '</p>' +
            '<div style="text-align:left;">' +
                '<label for="swalDeletePwd" style="font-weight:600;font-size:13px;display:block;margin-bottom:6px;color:#212529;">' +
                    T('sorties.msg.delete_pwd_label', 'Mot de passe de suppression') +
                    ' <span style="color:#dc3545;">*</span>' +
                '</label>' +
                '<input type="password" id="swalDeletePwd" class="swal2-input" autocomplete="off" ' +
                       'placeholder="' + T('sorties.msg.delete_pwd_placeholder', 'Saisissez le mot de passe') + '" ' +
                       'style="width:100%;margin:0;box-sizing:border-box;" />' +
                '<div id="swalDeletePwdError" style="color:#dc3545;font-size:12.5px;margin-top:6px;display:none;font-weight:600;"></div>' +
            '</div>',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: '<i class="fas fa-trash"></i> ' +
            T('sorties.msg.delete_confirm_btn', 'Confirmer la suppression'),
        cancelButtonText: T('button.cancel', 'Annuler'),
        reverseButtons: true,
        focusConfirm: false,
        didOpen: function () {
            var pwd = document.getElementById('swalDeletePwd');
            if (pwd) pwd.focus();
        },
        preConfirm: async function () {
            var pwdInput = document.getElementById('swalDeletePwd');
            var errEl    = document.getElementById('swalDeletePwdError');
            var pwd      = pwdInput ? pwdInput.value : '';

            if (!pwd) {
                if (errEl) {
                    errEl.textContent = T('sorties.msg.delete_pwd_required', 'Veuillez saisir le mot de passe.');
                    errEl.style.display = 'block';
                }
                return false;
            }

            try {
                var url  = API.BASE + API.HANDLERS_PATH + API.DELETE;
                var resp = await fetch(url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ id: id, password: pwd })
                });
                var result = await resp.json();

                if (result && result.success) {
                    return { message: result.message || T('sorties.msg.deleted', 'Bon supprimé') };
                } else {
                    if (errEl) {
                        errEl.textContent = result.message
                            || T('sorties.msg.delete_pwd_bad', 'Mot de passe incorrect. Veuillez réessayer.');
                        errEl.style.display = 'block';
                    }
                    if (pwdInput) { pwdInput.value = ''; pwdInput.focus(); }
                    return false;
                }
            } catch (err) {
                if (errEl) {
                    errEl.textContent = 'Erreur de communication avec le serveur.';
                    errEl.style.display = 'block';
                }
                return false;
            }
        }
    });

    if (!confirmResult.isConfirmed || !confirmResult.value) return;

    showToast(T('message.success', 'Succès'),
              confirmResult.value.message || T('sorties.msg.deleted', 'Bon supprimé'),
              'success');
    loadSorties();
    loadSortieStats();
    if (typeof updateSortieBadge === 'function') updateSortieBadge();
}

// ============================================================
// VALIDATION
// ============================================================
async function validerSortie(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (sortie && sortie.STATUT === 'VALIDE') {
        showToast(T('sorties.msg.info', 'Info'),
                  T('sorties.msg.validate_already', 'Ce bon est déjà validé.'),
                  'info');
        return;
    }

    var confirm = await Swal.fire({
        title: T('button.validate', 'Valider'),
        text:  T('sorties.msg.validate_ask', 'Valider ce bon va déduire les quantités (Qté Reçue) du stock. Continuer ?'),
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#28a745',
        cancelButtonColor: '#6c757d',
        confirmButtonText: '<i class="fas fa-check"></i> ' + T('sorties.msg.validate_yes', 'Oui, valider'),
        cancelButtonText: T('button.cancel', 'Annuler'),
        reverseButtons: true
    });
    if (!confirm.isConfirmed) return;

    var clickedBtn = document.querySelector('button[onclick*="validerSortie(\'' + id + '\')"]');
    setButtonLoading(clickedBtn, true, '');

    try {
        showSpinner();
        var url  = API.BASE + API.HANDLERS_PATH + API.VALIDATE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        });
        var result = await resp.json();
        if (result.success) {
            showToast(T('message.success', 'Succès'),
                      T('sorties.msg.validate_ok', 'Bon validé et stock mis à jour'),
                      'success');
            loadSorties();
            loadSortieStats();
            if (typeof updateSortieBadge === 'function') updateSortieBadge();
        } else {
            showToast(T('message.error', 'Erreur'),
                      result.message || T('sorties.msg.validate_error', 'Échec de la validation'),
                      'error');
            setButtonLoading(clickedBtn, false);
        }
    } catch (err) {
        showToast(T('message.error', 'Erreur'), err.message, 'error');
        setButtonLoading(clickedBtn, false);
    } finally {
        hideSpinner();
    }
}

// ============================================================
// FERMETURE DU MODAL
// ============================================================
function closeSortieModal() {
    closeModal('sortieModal');
    AppState.editingId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-truck"></i> ' + T('sorties.modal.add_title', 'Nouveau bon de sortie');

    setFieldsEnabled(true);

    var numEl = document.getElementById('sortieNumero');
    if (numEl) {
        numEl.value = '';
        numEl.placeholder = T('sorties.modal.numero_auto_placeholder', 'Sera généré automatiquement (SOR-XXX-00001)');
        setNumeroReadOnly();
    }

    var btnSave = document.getElementById('btnSaveSortie');
    if (btnSave) {
        setButtonLoading(btnSave, false);
        btnSave.style.display = '';
    }

    setAnnulerButtonVisible(true);
    clearErrors();
}

// ============================================================
// ERREURS DE CHAMP
// ============================================================
function showError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
}

function clearErrors() {
    document.querySelectorAll('.field-error').forEach(function (el) {
        el.textContent = '';
        el.style.display = 'none';
    });
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.openAddSortieModal      = openAddSortieModal;
window.editSortie              = editSortie;
window.viewSortie              = viewSortie;
window.saveSortie              = saveSortie;
window.deleteSortie            = deleteSortie;
window.validerSortie           = validerSortie;
window.closeSortieModal        = closeSortieModal;
window.showError               = showError;
window.clearErrors             = clearErrors;
window.setFieldsEnabled        = setFieldsEnabled;
window.setAnnulerButtonVisible = setAnnulerButtonVisible;
window.chargerSortieDansModal  = chargerSortieDansModal;
window.setNumeroReadOnly       = setNumeroReadOnly;
window.setButtonLoading        = setButtonLoading;
