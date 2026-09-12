// ============================================================
// CRUD - SORTIES avec génération automatique du NUMÉRO
// Design moderne + mode VIEW propre (disabled)
// ============================================================

var currentMode = 'add'; // 'add', 'edit', 'view'

// ============================================================
// UTILITAIRE : activer / désactiver les champs du modal
// ============================================================
function setFieldsEnabled(enabled) {
    // ─── Champs de saisie ───
    var inputs = document.querySelectorAll('#sortieModal input, #sortieModal select, #sortieModal textarea');
    for (var i = 0; i < inputs.length; i++) {
        // ⚠️ Le numéro reste TOUJOURS readonly (jamais disabled)
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

    // ─── Boutons icônes (lignes + bouton +) ───
    var iconBtns = document.querySelectorAll('#sortieModal .btn-icon');
    for (var j = 0; j < iconBtns.length; j++) {
        iconBtns[j].disabled = !enabled;
    }

    // ─── Styles spécifiques pour les selects article ───
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

// ============================================================
// UTILITAIRE : masquer/afficher le bouton Annuler
// ============================================================
function setAnnulerButtonVisible(visible) {
    var btnAnnuler = document.getElementById('btnAnnulerSortie');
    if (btnAnnuler) {
        btnAnnuler.style.display = visible ? '' : 'none';
    }
}

// ============================================================
// UTILITAIRE : style readonly sur le champ Numéro
// ============================================================
function setNumeroReadOnly() {
    var numEl = document.getElementById('sortieNumero');
    if (!numEl) return;
    numEl.readOnly = true;
    numEl.style.backgroundColor = '#e9ecef';
    numEl.style.color = '#6c757d';
    numEl.style.cursor = 'not-allowed';
}

// ============================================================
// UTILITAIRE : état de chargement sur un bouton
// ============================================================
function setButtonLoading(btn, loading, loadingText) {
    if (!btn) return;
    if (loading) {
        if (!btn.dataset.originalHtml) {
            btn.dataset.originalHtml = btn.innerHTML;
        }
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
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck"></i> Nouveau bon de sortie';
    document.getElementById('sortieForm').reset();

    var now = new Date().toISOString().slice(0, 16);
    document.getElementById('sortieDate').value = now;

    // Numéro : vide + readonly
    var numEl = document.getElementById('sortieNumero');
    numEl.value = '';
    numEl.placeholder = 'Sera généré automatiquement (SOR-XXX-00001)';
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
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier le bon de sortie';
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
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-eye"></i> Détails du bon de sortie';
    chargerSortieDansModal(sortie);
    setFieldsEnabled(false); // ⚠️ Désactive TOUT sauf le numéro (readonly)
    setNumeroReadOnly();
    document.getElementById('btnSaveSortie').style.display = 'none';
    setAnnulerButtonVisible(false);
    clearErrors();
    showModal('sortieModal');
}

// ============================================================
// CHARGEMENT DES DONNÉES DANS LE MODAL
// ============================================================
function chargerSortieDansModal(sortie) {
    var numEl = document.getElementById('sortieNumero');
    numEl.value = sortie.NUMERO || '';
    setNumeroReadOnly();

    // Date
    var dateStr = '';
    if (sortie.DATE_SORTIE) {
        try {
            var dateValue = String(sortie.DATE_SORTIE);
            var dotNetDate = dateValue.match(/^\/Date\((-?\d+)\)\/$/);
            var d = dotNetDate ? new Date(Number(dotNetDate[1])) : new Date(dateValue);
            if (!isNaN(d.getTime())) {
                var pad = function (value) { return String(value).padStart(2, '0'); };
                dateStr = d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
                    'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
            }
        } catch (e) { /* ignore */ }
    }
    document.getElementById('sortieDate').value = dateStr;

    document.getElementById('sortieDestination').value = sortie.DESTINATION || '';
    document.getElementById('sortieNom').value = sortie.NOM || '';
    document.getElementById('sortieFonction').value = sortie.FONCTION || '';
    document.getElementById('sortieNotes').value = sortie.NOTES || '';

    // Lignes
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
        showToast('Info', 'Vous êtes en mode consultation, aucune modification n\'est possible.', 'info');
        return;
    }

    var id = AppState.editingId;
    var data = {
        dateSortie: document.getElementById('sortieDate').value,
        destination: document.getElementById('sortieDestination').value.trim(),
        nom: document.getElementById('sortieNom').value.trim(),
        fonction: document.getElementById('sortieFonction').value.trim(),
        notes: document.getElementById('sortieNotes').value.trim(),
        lignes: getLignesFromModal()
    };

    var valid = true;
    clearErrors();
    if (!data.dateSortie) { showError('sortieDate', 'La date est requise'); valid = false; }
    if (!data.destination) { showError('sortieDestination', 'La destination est requise'); valid = false; }
    if (!data.lignes.length) { showToast('Erreur', 'Ajoutez au moins une ligne d\'article', 'error'); valid = false; }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload = id ? Object.assign({}, data, { id: id }) : data;

    var btnSave = document.getElementById('btnSaveSortie');

    try {
        showSpinner();
        setButtonLoading(btnSave, true, 'Enregistrement…');

        var url = API.BASE + API.HANDLERS_PATH + endpoint;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        var result = await resp.json();

        if (result.success) {
            var msg = result.message || (id ? 'Bon modifié' : 'Bon créé');
            if (result.numero && !id) msg = 'Bon de sortie créé avec succès (' + result.numero + ').';
            showToast('Succès', msg, 'success');
            closeSortieModal();
            loadSorties();
            loadSortieStats();
            if (typeof updateSortieBadge === 'function') updateSortieBadge();
        } else {
            showToast('Erreur', result.message || 'Une erreur est survenue', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        setButtonLoading(btnSave, false);
        hideSpinner();
    }
}

// ============================================================
// SUPPRESSION (avec vérification du mot de passe côté serveur)
// ============================================================
async function deleteSortie(id) {
    // Vérification du statut (règle métier existante, inchangée)
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (sortie && sortie.STATUT === 'VALIDE') {
        showToast('Attention', 'Impossible de supprimer un bon de sortie validé.', 'warning');
        return;
    }

    // ============================================================
    // MODAL DE CONFIRMATION AVEC CHAMP MOT DE PASSE
    // La vérification est faite côté serveur (SortieDelete.ashx).
    // Tant que le mot de passe est incorrect, le modal reste ouvert.
    // ============================================================
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        html:
            '<p style="margin-bottom:14px;color:#495057;">' +
                'Voulez-vous vraiment supprimer ce bon de sortie ?' +
            '</p>' +
            '<div style="text-align:left;">' +
                '<label for="swalDeletePwd" ' +
                       'style="font-weight:600;font-size:13px;display:block;margin-bottom:6px;color:#212529;">' +
                    'Mot de passe de suppression <span style="color:#dc3545;">*</span>' +
                '</label>' +
                '<input type="password" id="swalDeletePwd" ' +
                       'class="swal2-input" autocomplete="off" ' +
                       'placeholder="Saisissez le mot de passe" ' +
                       'style="width:100%;margin:0;box-sizing:border-box;" />' +
                '<div id="swalDeletePwdError" ' +
                     'style="color:#dc3545;font-size:12.5px;margin-top:6px;display:none;font-weight:600;">' +
                '</div>' +
            '</div>',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: '<i class="fas fa-trash"></i> Confirmer la suppression',
        cancelButtonText: 'Annuler',
        reverseButtons: true,
        focusConfirm: false,
        didOpen: function () {
            // Focus automatique sur le champ mot de passe
            var pwd = document.getElementById('swalDeletePwd');
            if (pwd) pwd.focus();
        },
        preConfirm: async function () {
            var pwdInput = document.getElementById('swalDeletePwd');
            var errEl = document.getElementById('swalDeletePwdError');
            var pwd = pwdInput ? pwdInput.value : '';

            // Validation locale : champ obligatoire
            if (!pwd) {
                if (errEl) {
                    errEl.textContent = 'Veuillez saisir le mot de passe.';
                    errEl.style.display = 'block';
                }
                return false; // ← le modal reste ouvert
            }

            // ============================================================
            // Appel au serveur : le mot de passe est vérifié côté handler.
            // Si correct → suppression effectuée.
            // Si incorrect → retour d'erreur, modal reste ouvert.
            // ============================================================
            try {
                var url = API.BASE + API.HANDLERS_PATH + API.DELETE;
                var resp = await fetch(url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ id: id, password: pwd })
                });
                var result = await resp.json();

                if (result && result.success) {
                    // Succès : on retourne le message pour l'afficher après
                    return { message: result.message || 'Bon supprimé' };
                } else {
                    // Échec (mot de passe incorrect ou autre)
                    if (errEl) {
                        errEl.textContent = result.message || 'Mot de passe incorrect. Veuillez réessayer.';
                        errEl.style.display = 'block';
                    }
                    // Vider le champ pour permettre une nouvelle saisie
                    if (pwdInput) {
                        pwdInput.value = '';
                        pwdInput.focus();
                    }
                    return false; // ← le modal reste ouvert
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

    // ============================================================
    // SUCCÈS (la suppression a déjà été effectuée côté serveur)
    // ============================================================
    showToast('Succès', confirmResult.value.message || 'Bon supprimé', 'success');
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
        showToast('Info', 'Ce bon est déjà validé.', 'info');
        return;
    }

    var confirm = await Swal.fire({
        title: 'Valider le bon de sortie',
        text: 'Valider ce bon va déduire les quantités (Qté Reçue) du stock. Continuer ?',
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#28a745',
        cancelButtonColor: '#6c757d',
        confirmButtonText: '<i class="fas fa-check"></i> Oui, valider',
        cancelButtonText: 'Annuler',
        reverseButtons: true
    });
    if (!confirm.isConfirmed) return;

    var clickedBtn = document.querySelector('button[onclick*="validerSortie(\'' + id + '\')"]');
    setButtonLoading(clickedBtn, true, '');

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.VALIDATE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        });
        var result = await resp.json();
        if (result.success) {
            showToast('Succès', 'Bon validé et stock mis à jour', 'success');
            loadSorties();
            loadSortieStats();
            if (typeof updateSortieBadge === 'function') updateSortieBadge();
        } else {
            showToast('Erreur', result.message || 'Échec de la validation', 'error');
            setButtonLoading(clickedBtn, false);
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
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
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck"></i> Nouveau bon de sortie';

    setFieldsEnabled(true);

    var numEl = document.getElementById('sortieNumero');
    if (numEl) {
        numEl.value = '';
        numEl.placeholder = 'Sera généré automatiquement (SOR-XXX-00001)';
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
// GESTION DES ERREURS DE CHAMP
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
// EXPOSITIONS GLOBALES
// ============================================================
window.openAddSortieModal = openAddSortieModal;
window.editSortie = editSortie;
window.viewSortie = viewSortie;
window.saveSortie = saveSortie;
window.deleteSortie = deleteSortie;
window.validerSortie = validerSortie;
window.closeSortieModal = closeSortieModal;
window.showError = showError;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
window.setAnnulerButtonVisible = setAnnulerButtonVisible;
window.chargerSortieDansModal = chargerSortieDansModal;
window.setNumeroReadOnly = setNumeroReadOnly;
window.setButtonLoading = setButtonLoading;
