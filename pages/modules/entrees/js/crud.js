// crud.js — Module Entrées
var currentMode = 'add';

function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#entreeModal input, #entreeModal select, #entreeModal textarea');
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
    var ligneBtns = document.querySelectorAll('#entreeModal .btn-success, #entreeModal .btn-danger');
    for (var j = 0; j < ligneBtns.length; j++) {
        ligneBtns[j].disabled = !enabled;
    }
}

function setAnnulerButtonVisible(visible) {
    var btnAnnuler = document.getElementById('btnAnnulerButton');
    if (btnAnnuler) btnAnnuler.style.display = visible ? '' : 'none';
}

function setNumeroReadOnly() {
    var numEl = document.getElementById('entreeNumero');
    if (!numEl) return;
    numEl.readOnly = true;
    numEl.style.backgroundColor = '#e9ecef';
    numEl.style.cursor = 'not-allowed';
}

function openAddEntreeModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-truck-loading"></i> ' + T('entrees.modal.add_title', "Nouveau bon d'entrée");

    document.getElementById('entreeForm').reset();

    var now = new Date().toISOString().slice(0, 16);
    document.getElementById('entreeDate').value = now;

    var numEl = document.getElementById('entreeNumero');
    numEl.value = '';
    numEl.placeholder = T('entrees.modal.numero_auto_placeholder', 'Sera généré automatiquement (ENT-XXX-00001)');
    setNumeroReadOnly();

    document.getElementById('lignesBody').innerHTML = '';
    setFieldsEnabled(true);
    setNumeroReadOnly();

    document.getElementById('btnSaveEntree').style.display = '';
    setAnnulerButtonVisible(true);
    ajouterLigne();
    clearErrors();
    showModal('entreeModal');
}

function editEntree(id) {
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (!entree) return;

    AppState.editingId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + T('entrees.modal.edit_title', "Modifier le bon d'entrée");

    chargerEntreeDansModal(entree);
    setFieldsEnabled(true);
    setNumeroReadOnly();
    document.getElementById('btnSaveEntree').style.display = '';
    setAnnulerButtonVisible(true);
    clearErrors();
    showModal('entreeModal');
}

function viewEntree(id) {
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (!entree) return;

    AppState.editingId = id;
    currentMode = 'view';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + T('entrees.modal.view_title', "Détails du bon d'entrée");

    chargerEntreeDansModal(entree);
    setFieldsEnabled(false);
    setNumeroReadOnly();
    document.getElementById('btnSaveEntree').style.display = 'none';
    setAnnulerButtonVisible(false);
    clearErrors();
    showModal('entreeModal');
}

function chargerEntreeDansModal(entree) {
    var numEl = document.getElementById('entreeNumero');
    numEl.value = entree.NUMERO || '';
    setNumeroReadOnly();

    var dateStr = '';
    if (entree.DATE_ENTREE) {
        try {
            var d = new Date(entree.DATE_ENTREE);
            if (!isNaN(d.getTime())) dateStr = d.toISOString().slice(0, 16);
        } catch (e) { /* ignore */ }
    }
    document.getElementById('entreeDate').value = dateStr;

    document.getElementById('entreeFournisseur').value = entree.FOURNISSEUR_ID || '';
    document.getElementById('entreeReference').value   = entree.REFERENCE || '';
    document.getElementById('entreeNotes').value       = entree.NOTES || '';

    document.getElementById('lignesBody').innerHTML = '';
    var lignes = entree.Lignes || [];
    if (lignes.length) {
        lignes.forEach(function (l) {
            ajouterLigne(l.ARTICLE_ID, l.QUANTITE, l.PRIX_UNITAIRE_HT, l.TVA_TX);
        });
    } else {
        ajouterLigne();
    }
}

async function saveEntree(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast(T('entrees.msg.info', 'Info'),
                  T('entrees.msg.view_mode', "Vous êtes en mode consultation, aucune modification n'est possible."),
                  'info');
        return;
    }

    var id = AppState.editingId;

    var data = {
        dateEntree:    document.getElementById('entreeDate').value,
        fournisseurId: document.getElementById('entreeFournisseur').value,
        reference:     document.getElementById('entreeReference').value.trim(),
        notes:         document.getElementById('entreeNotes').value.trim(),
        lignes:        getLignesFromModal()
    };

    var valid = true;
    clearErrors();

    if (!data.dateEntree) {
        showError('entreeDate', T('entrees.msg.date_required', 'La date est requise'));
        valid = false;
    }
    if (!data.fournisseurId) {
        showError('entreeFournisseur', T('entrees.msg.fournisseur_required', 'Le fournisseur est requis'));
        valid = false;
    }
    if (!data.lignes.length) {
        showToast(T('message.error', 'Erreur'),
                  T('entrees.msg.line_required', "Ajoutez au moins une ligne d'article"),
                  'error');
        valid = false;
    }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload  = id ? Object.assign({}, data, { id: id }) : data;

    try {
        showSpinner();
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
                msg = T('entrees.msg.added_with_numero',
                        "Bon d'entrée créé avec succès ({numero}).",
                        { numero: result.numero });
            } else {
                msg = result.message || (id
                    ? T('entrees.msg.updated', 'Bon modifié')
                    : T('entrees.msg.added', "Bon d'entrée créé avec succès"));
            }
            showToast(T('message.success', 'Succès'), msg, 'success');
            closeEntreeModal();
            loadEntrees();
            loadEntreeStats();
        } else {
            showToast(T('message.error', 'Erreur'),
                      result.message || T('entrees.msg.save_error', 'Une erreur est survenue'),
                      'error');
        }
    } catch (err) {
        showToast(T('message.error', 'Erreur'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

async function deleteEntree(id) {
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (entree && entree.STATUT === 'VALIDE') {
        showToast(T('message.warning', 'Attention'),
                  T('entrees.msg.delete_validated', "Impossible de supprimer un bon d'entrée validé."),
                  'warning');
        return;
    }

    var confirmResult = await Swal.fire({
        title: T('entrees.confirm.delete_title', 'Confirmer la suppression'),
        html:
            '<p style="margin-bottom:14px;color:#495057;">' +
                T('entrees.msg.delete_confirm', "Voulez-vous vraiment supprimer ce bon d'entrée ?") +
            '</p>' +
            '<div style="text-align:left;">' +
                '<label for="swalDeletePwd" ' +
                       'style="font-weight:600;font-size:13px;display:block;margin-bottom:6px;color:#212529;">' +
                    T('entrees.msg.delete_pwd_label', 'Mot de passe de suppression') +
                    ' <span style="color:#dc3545;">*</span>' +
                '</label>' +
                '<input type="password" id="swalDeletePwd" ' +
                       'class="swal2-input" autocomplete="off" ' +
                       'placeholder="' + T('entrees.msg.delete_pwd_placeholder', 'Saisissez le mot de passe') + '" ' +
                       'style="width:100%;margin:0;box-sizing:border-box;" />' +
                '<div id="swalDeletePwdError" ' +
                     'style="color:#dc3545;font-size:12.5px;margin-top:6px;display:none;font-weight:600;">' +
                '</div>' +
            '</div>',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: '<i class="fas fa-trash"></i> ' +
            T('entrees.msg.delete_confirm_btn', 'Confirmer la suppression'),
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
                    errEl.textContent = T('entrees.msg.delete_pwd_required', 'Veuillez saisir le mot de passe.');
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
                    return { message: result.message || T('entrees.msg.deleted', 'Bon supprimé') };
                } else {
                    if (errEl) {
                        errEl.textContent = result.message
                            || T('entrees.msg.delete_pwd_bad', 'Mot de passe incorrect. Veuillez réessayer.');
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
              confirmResult.value.message || T('entrees.msg.deleted', 'Bon supprimé'),
              'success');
    loadEntrees();
    loadEntreeStats();
}

async function validerEntree(id) {
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (entree && entree.STATUT === 'VALIDE') {
        showToast(T('entrees.msg.info', 'Info'),
                  T('entrees.msg.validate_already', 'Ce bon est déjà validé.'),
                  'info');
        return;
    }

    var confirm = await Swal.fire({
        title: T('button.validate', 'Valider'),
        text:  T('entrees.msg.validate_ask', "Valider ce bon d'entrée va mettre à jour les stocks. Continuer ?"),
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#28a745',
        cancelButtonColor: '#6c757d',
        confirmButtonText: T('entrees.msg.validate_yes', 'Oui, valider'),
        cancelButtonText:  T('button.cancel', 'Annuler')
    });
    if (!confirm.isConfirmed) return;

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
                      T('entrees.msg.validate_ok', 'Bon validé et stock mis à jour'),
                      'success');
            loadEntrees();
            loadEntreeStats();
        } else {
            showToast(T('message.error', 'Erreur'),
                      result.message || T('entrees.msg.validate_error', 'Échec de la validation'),
                      'error');
        }
    } catch (err) {
        showToast(T('message.error', 'Erreur'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

function closeEntreeModal() {
    closeModal('entreeModal');
    AppState.editingId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-truck-loading"></i> ' + T('entrees.modal.add_title', "Nouveau bon d'entrée");

    setFieldsEnabled(true);

    var numEl = document.getElementById('entreeNumero');
    if (numEl) {
        numEl.value = '';
        numEl.placeholder = T('entrees.modal.numero_auto_placeholder', 'Sera généré automatiquement (ENT-XXX-00001)');
        setNumeroReadOnly();
    }

    document.getElementById('btnSaveEntree').style.display = '';
    setAnnulerButtonVisible(true);
    clearErrors();
}

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

window.openAddEntreeModal      = openAddEntreeModal;
window.editEntree              = editEntree;
window.viewEntree              = viewEntree;
window.saveEntree              = saveEntree;
window.deleteEntree            = deleteEntree;
window.validerEntree           = validerEntree;
window.closeEntreeModal        = closeEntreeModal;
window.showError               = showError;
window.clearErrors             = clearErrors;
window.setFieldsEnabled        = setFieldsEnabled;
window.setAnnulerButtonVisible = setAnnulerButtonVisible;
window.setNumeroReadOnly       = setNumeroReadOnly;
