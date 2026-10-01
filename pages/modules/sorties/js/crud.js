// ============================================================
// CRUD - SORTIES  —  v3 (Default Deny + inert + CSS)
// ============================================================
var currentMode = 'add';

// ═══════════════════════════════════════════════════════════════
// ✅ WHITELIST INVERSÉE — seuls ces sélecteurs sont ACTIFS
// ─────────────────────────────────────────────────────────────
// En ADD  : tout est actif (pas de gel).
// En EDIT : tout est gelé SAUF les sélecteurs ci-dessous.
// En VIEW : tout est gelé, aucune exception.
//
// 👉 Pour rendre un champ éditable en EDIT : ajoutez son sélecteur
//    à EDITABLE_IN_EDIT. Rien d'autre à toucher.
// ═══════════════════════════════════════════════════════════════
var EDITABLE_IN_EDIT = [
    '.ligne-quantite-r'          // ← SEUL champ modifiable en EDIT
];

var EDITABLE_IN_VIEW = [
    // (aucun champ actif en consultation)
];

// Boutons d'action de ligne (ajouter/supprimer) actifs uniquement en ADD
var LINE_ACTION_POLICY = { add: true, edit: false, view: false };

// ═══════════════════════════════════════════════════════════════
// ✅ GEL / DÉGEL D'UN ÉLÉMENT
// ─────────────────────────────────────────────────────────────
// `inert` gèle l'élément ET ses descendants au niveau navigateur
// (bloque clic, focus, tab, plugins Select2/TomSelect…).
// `disabled` reste posé pour la compat API + accessibilité.
// Le style visuel est porté par la classe CSS .fld-frozen.
// ═══════════════════════════════════════════════════════════════
function freezeElement(el) {
    if (!el) return;
    try { el.inert = true; } catch (e) {}
    if (/^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(el.tagName)) {
        el.disabled = true;
    } else {
        var inner = el.querySelectorAll('input, select, textarea, button');
        for (var i = 0; i < inner.length; i++) inner[i].disabled = true;
    }
    el.classList.add('fld-frozen');
    el.classList.remove('fld-editable');
    el.setAttribute('aria-disabled', 'true');
}

function unfreezeElement(el, highlight) {
    if (!el) return;
    try { el.inert = false; } catch (e) {}
    if (/^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(el.tagName)) {
        el.disabled = false;
    } else {
        var inner = el.querySelectorAll('input, select, textarea, button');
        for (var i = 0; i < inner.length; i++) inner[i].disabled = false;
    }
    el.classList.remove('fld-frozen');
    if (highlight) el.classList.add('fld-editable');
    else           el.classList.remove('fld-editable');
    el.removeAttribute('aria-disabled');
}

// ═══════════════════════════════════════════════════════════════
// ✅ SYNCHRO WIDGETS TIERS (Select2 / Chosen / TomSelect)
// ═══════════════════════════════════════════════════════════════
function syncWidgetsState() {
    if (window.jQuery && jQuery.fn && jQuery.fn.select2) {
        jQuery('#sortieModal select').each(function () {
            var $s = jQuery(this);
            if ($s.data('select2')) $s.prop('disabled', this.disabled).trigger('change.select2');
        });
    }
    if (window.jQuery && jQuery.fn && jQuery.fn.chosen) {
        jQuery('#sortieModal select').each(function () {
            var $s = jQuery(this);
            if ($s.data('chosen')) $s.prop('disabled', this.disabled).trigger('chosen:updated');
        });
    }
    var sels = document.querySelectorAll('#sortieModal select');
    for (var i = 0; i < sels.length; i++) {
        var s = sels[i];
        if (s.tomselect && typeof s.tomselect.sync === 'function') {
            try { s.disabled ? s.tomselect.disable() : s.tomselect.enable(); } catch (e) {}
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// ✅ APPLICATION DE LA POLITIQUE (Default Deny + wrappers)
// ─────────────────────────────────────────────────────────────
// En EDIT/VIEW :
//   1. Gèle tous les champs (input, select, textarea)
//   2. Gèle les <td> parents dans #lignesBody → bloque AUSSI
//      les widgets tiers (article-picker, Select2…) qui ne sont
//      pas de vrais <select>.
//   3. Dégèle uniquement les <td> contenant un élément de la
//      whitelist (EDITABLE_IN_EDIT / EDITABLE_IN_VIEW).
// ═══════════════════════════════════════════════════════════════
function applyModePolicy(mode) {
    if (mode !== 'add' && mode !== 'edit' && mode !== 'view') {
        console.warn('[applyModePolicy] Mode inconnu :', mode);
        return;
    }

    var modal = document.getElementById('sortieModal');
    if (!modal) return;

    modal.classList.remove('mode-add', 'mode-edit', 'mode-view');
    modal.classList.add('mode-' + mode);

    // ─── Cas ADD : tout actif ───
    if (mode === 'add') {
        var allFields = modal.querySelectorAll('input, select, textarea, button');
        for (var a = 0; a < allFields.length; a++) unfreezeElement(allFields[a], false);

        // Dégèle aussi les conteneurs précédemment gelés
        var frozenEls = modal.querySelectorAll('.fld-frozen');
        for (var k = 0; k < frozenEls.length; k++) {
            frozenEls[k].classList.remove('fld-frozen');
            try { frozenEls[k].inert = false; } catch (e) {}
            frozenEls[k].removeAttribute('aria-disabled');
        }

        setNumeroReadOnly();
        applyLineActionPolicy(mode);
        syncWidgetsState();
        return;
    }

    // ─── Cas EDIT / VIEW : Default Deny ───
    var whitelist = (mode === 'edit') ? EDITABLE_IN_EDIT : EDITABLE_IN_VIEW;

    // 1) Gèle tous les champs de formulaire
    var fields = modal.querySelectorAll('input, select, textarea');
    for (var f = 0; f < fields.length; f++) freezeElement(fields[f]);

    // 2) Gèle / dégèle les <td> des lignes selon la whitelist
    //    → c'est ce qui bloque les widgets custom (article-picker)
    var tds = modal.querySelectorAll('#lignesBody td');
    for (var t = 0; t < tds.length; t++) {
        var td = tds[t];

        var containsEditable = false;
        for (var w = 0; w < whitelist.length; w++) {
            try {
                if (td.matches(whitelist[w]) || td.querySelector(whitelist[w])) {
                    containsEditable = true;
                    break;
                }
            } catch (e) { /* sélecteur invalide, on ignore */ }
        }

        if (containsEditable) {
            unfreezeElement(td, true);   // td entièrement active (Qté Reçue)
        } else {
            freezeElement(td);           // td + ses enfants gelés (article, obs, …)
        }
    }

    // 3) Sécurité : dégèle les éléments whitelistés hors td (ex: un champ
    //    ailleurs dans la modale ajouté à EDITABLE_IN_EDIT)
    whitelist.forEach(function (selector) {
        var els;
        try { els = modal.querySelectorAll(selector); }
        catch (e) { return; }
        for (var i = 0; i < els.length; i++) {
            var el = els[i];
            if (/^(INPUT|SELECT|TEXTAREA)$/.test(el.tagName)) {
                unfreezeElement(el, true);
            }
        }
    });

    // ─── Numéro TOUJOURS RO ───
    setNumeroReadOnly();

    // ─── Boutons ligne ───
    applyLineActionPolicy(mode);

    // ─── Synchro widgets tiers ───
    syncWidgetsState();
}

// ═══════════════════════════════════════════════════════════════
// ✅ BOUTONS D'ACTION DE LIGNE
// ═══════════════════════════════════════════════════════════════
function applyLineActionPolicy(mode) {
    var modal = document.getElementById('sortieModal');
    if (!modal) return;
    var canUse = LINE_ACTION_POLICY[mode] === true;
    var btns = modal.querySelectorAll('.btn-icon');
    for (var i = 0; i < btns.length; i++) {
        btns[i].disabled = !canUse;
        try { btns[i].inert = !canUse; } catch (e) {}
    }
}

// ═══════════════════════════════════════════════════════════════
// ✅ OBSERVER — ré-applique après ajout de lignes dynamiques
// ═══════════════════════════════════════════════════════════════
var _lignesObserver = null;

function installLignesObserver() {
    if (_lignesObserver) return;
    var tbody = document.getElementById('lignesBody');
    if (!tbody) return;

    _lignesObserver = new MutationObserver(function (mutations) {
        var added = false;
        for (var i = 0; i < mutations.length; i++) {
            if (mutations[i].type === 'childList' && mutations[i].addedNodes.length) {
                added = true; break;
            }
        }
        if (!added || currentMode === 'add') return;

        applyModePolicy(currentMode);
        // Filet de sécurité : certains widgets s'initialisent après coup
        setTimeout(function () {
            if (currentMode !== 'add') applyModePolicy(currentMode);
        }, 80);
    });

    _lignesObserver.observe(tbody, { childList: true });
}

// ============================================================
// ⚠️ DÉPRÉCIÉES (compat)
// ============================================================
function setFieldsEnabled(enabled) { applyModePolicy(enabled ? 'add' : 'view'); }
function setFieldsEnabledForEdit() { applyModePolicy('edit'); }

// ============================================================
// UTILITAIRES UI
// ============================================================
function setAnnulerButtonVisible(visible) {
    var b = document.getElementById('btnAnnulerSortie');
    if (b) b.style.display = visible ? '' : 'none';
}

function setNumeroReadOnly() {
    var n = document.getElementById('sortieNumero');
    if (!n) return;
    n.readOnly = true;
    n.classList.add('fld-frozen');
    n.setAttribute('aria-disabled', 'true');
    try { n.inert = true; } catch (e) {}
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
    document.getElementById('sortieDate').value = new Date().toISOString().slice(0, 16);

    var numEl = document.getElementById('sortieNumero');
    numEl.value = '';
    numEl.placeholder = T('sorties.modal.numero_auto_placeholder', 'Sera généré automatiquement (SOR-XXX-00001)');

    document.getElementById('lignesBody').innerHTML = '';

    applyModePolicy('add');
    installLignesObserver();

    document.getElementById('btnSaveSortie').style.display = '';
    setAnnulerButtonVisible(true);

    ajouterLigne();

    clearErrors();
    showModal('sortieModal');
}

// ============================================================
// MODIFICATION — seul Quantité Reçue modifiable
// ============================================================
function editSortie(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!sortie) return;

    AppState.editingId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + T('sorties.modal.edit_title', 'Modifier le bon de sortie');

    installLignesObserver();
    chargerSortieDansModal(sortie);
    applyModePolicy('edit');

    document.getElementById('btnSaveSortie').style.display = '';
    setAnnulerButtonVisible(true);
    clearErrors();
    showModal('sortieModal');

    // Ré-application différée (init tardive des widgets)
    setTimeout(function () { if (currentMode === 'edit') applyModePolicy('edit'); }, 60);
    setTimeout(function () { if (currentMode === 'edit') applyModePolicy('edit'); }, 200);
}

// ============================================================
// VISUALISATION — tout figé
// ============================================================
function viewSortie(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!sortie) return;

    AppState.editingId = id;
    currentMode = 'view';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + T('sorties.modal.view_title', 'Détails du bon de sortie');

    installLignesObserver();
    chargerSortieDansModal(sortie);
    applyModePolicy('view');

    document.getElementById('btnSaveSortie').style.display = 'none';
    setAnnulerButtonVisible(false);
    clearErrors();
    showModal('sortieModal');

    setTimeout(function () { if (currentMode === 'view') applyModePolicy('view'); }, 60);
    setTimeout(function () { if (currentMode === 'view') applyModePolicy('view'); }, 200);
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
            var v = String(sortie.DATE_SORTIE);
            var m = v.match(/^\/Date\((-?\d+)\)\/$/);
            var d = m ? new Date(Number(m[1])) : new Date(v);
            if (!isNaN(d.getTime())) {
                var pad = function (x) { return String(x).padStart(2, '0'); };
                dateStr = d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
                          'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
            }
        } catch (e) {}
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
                  T('sorties.msg.view_mode', "Mode consultation : aucune modification possible."),
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
                  T('sorties.msg.line_required', "Ajoutez au moins une ligne d'article"), 'error');
        valid = false;
    }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload  = id ? Object.assign({}, data, { id: id }) : data;
    var btnSave  = document.getElementById('btnSaveSortie');

    try {
        showSpinner();
        setButtonLoading(btnSave, true, 'Enregistrement…');

        var resp = await fetch(API.BASE + API.HANDLERS_PATH + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        var result = await resp.json();

        if (result.success) {
            var msg = (result.numero && !id)
                ? T('sorties.msg.added_with_numero', 'Bon de sortie créé avec succès ({numero}).', { numero: result.numero })
                : (result.message || (id ? T('sorties.msg.updated', 'Bon modifié')
                                        : T('sorties.msg.added', 'Bon de sortie créé')));
            showToast(T('message.success', 'Succès'), msg, 'success');
            closeSortieModal();
            loadSorties();
            loadSortieStats();
            if (typeof updateSortieBadge === 'function') updateSortieBadge();
        } else {
            showToast(T('message.error', 'Erreur'),
                      result.message || T('sorties.msg.save_error', 'Une erreur est survenue'), 'error');
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
                  T('sorties.msg.delete_validated', 'Impossible de supprimer un bon validé.'), 'warning');
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
                    ' <span style="color:#dc3545;">*</span></label>' +
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
            var p = document.getElementById('swalDeletePwd'); if (p) p.focus();
        },
        preConfirm: async function () {
            var pwdInput = document.getElementById('swalDeletePwd');
            var errEl    = document.getElementById('swalDeletePwdError');
            var pwd      = pwdInput ? pwdInput.value : '';

            if (!pwd) {
                if (errEl) { errEl.textContent = T('sorties.msg.delete_pwd_required', 'Veuillez saisir le mot de passe.'); errEl.style.display = 'block'; }
                return false;
            }
            try {
                var resp = await fetch(API.BASE + API.HANDLERS_PATH + API.DELETE, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ id: id, password: pwd })
                });
                var result = await resp.json();
                if (result && result.success) {
                    return { message: result.message || T('sorties.msg.deleted', 'Bon supprimé') };
                }
                if (errEl) {
                    errEl.textContent = result.message || T('sorties.msg.delete_pwd_bad', 'Mot de passe incorrect. Veuillez réessayer.');
                    errEl.style.display = 'block';
                }
                if (pwdInput) { pwdInput.value = ''; pwdInput.focus(); }
                return false;
            } catch (err) {
                if (errEl) { errEl.textContent = 'Erreur de communication avec le serveur.'; errEl.style.display = 'block'; }
                return false;
            }
        }
    });

    if (!confirmResult.isConfirmed || !confirmResult.value) return;

    showToast(T('message.success', 'Succès'),
              confirmResult.value.message || T('sorties.msg.deleted', 'Bon supprimé'), 'success');
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
                  T('sorties.msg.validate_already', 'Ce bon est déjà validé.'), 'info');
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
        var resp = await fetch(API.BASE + API.HANDLERS_PATH + API.VALIDATE, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        });
        var result = await resp.json();
        if (result.success) {
            showToast(T('message.success', 'Succès'),
                      T('sorties.msg.validate_ok', 'Bon validé et stock mis à jour'), 'success');
            loadSorties();
            loadSortieStats();
            if (typeof updateSortieBadge === 'function') updateSortieBadge();
        } else {
            showToast(T('message.error', 'Erreur'),
                      result.message || T('sorties.msg.validate_error', 'Échec de la validation'), 'error');
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
// FERMETURE
// ============================================================
function closeSortieModal() {
    closeModal('sortieModal');
    AppState.editingId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-truck"></i> ' + T('sorties.modal.add_title', 'Nouveau bon de sortie');

    applyModePolicy('add');

    var numEl = document.getElementById('sortieNumero');
    if (numEl) {
        numEl.value = '';
        numEl.placeholder = T('sorties.modal.numero_auto_placeholder', 'Sera généré automatiquement (SOR-XXX-00001)');
        setNumeroReadOnly();
    }

    var btnSave = document.getElementById('btnSaveSortie');
    if (btnSave) { setButtonLoading(btnSave, false); btnSave.style.display = ''; }

    setAnnulerButtonVisible(true);
    clearErrors();
}

// ============================================================
// ERREURS
// ============================================================
function showError(fieldId, msg) {
    var el = document.getElementById('err-' + fieldId);
    if (el) { el.textContent = msg; el.style.display = 'block'; }
}
function clearErrors() {
    document.querySelectorAll('.field-error').forEach(function (el) {
        el.textContent = ''; el.style.display = 'none';
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

window.applyModePolicy         = applyModePolicy;
window.freezeElement           = freezeElement;
window.unfreezeElement         = unfreezeElement;
window.syncWidgetsState        = syncWidgetsState;
window.EDITABLE_IN_EDIT        = EDITABLE_IN_EDIT;
window.EDITABLE_IN_VIEW        = EDITABLE_IN_VIEW;
window.LINE_ACTION_POLICY      = LINE_ACTION_POLICY;
window.installLignesObserver   = installLignesObserver;

window.setFieldsEnabled        = setFieldsEnabled;
window.setFieldsEnabledForEdit = setFieldsEnabledForEdit;

window.setAnnulerButtonVisible = setAnnulerButtonVisible;
window.chargerSortieDansModal  = chargerSortieDansModal;
window.setNumeroReadOnly       = setNumeroReadOnly;
window.setButtonLoading        = setButtonLoading;
