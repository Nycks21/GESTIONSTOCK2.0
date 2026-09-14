// ============================================================
// SAISIE - CRUD (ADD / EDIT / VIEW)
// ============================================================

var currentMode = 'add'; // 'add', 'edit', 'view'

// ─── Utilitaires ───────────────────────────────────────────
function toLocalISO(date) {
    var pad = function (n) { return String(n).padStart(2, '0'); };
    return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate())
         + 'T' + pad(date.getHours()) + ':' + pad(date.getMinutes());
}

function parseDateValue(value) {
    if (!value) return null;
    try {
        var s = String(value).trim();
        var m = s.match(/^\/Date\((-?\d+)\)\/$/);
        var d = m ? new Date(Number(m[1])) : new Date(s);
        return isNaN(d.getTime()) ? null : d;
    } catch (e) { return null; }
}

function getModalTitle() {
    var title = document.getElementById('modalTitle');
    if (!title) title = document.querySelector('#saisieModal .modal-header h3');
    return title;
}

// ✅ Retourne le NOM de l'utilisateur connecté (injecté par le serveur)
function getCurrentUserNom() {
    var hf = document.getElementById('hfUserNom');
    return (hf && hf.value) ? hf.value : '';
}

// ✅ Force le champ Bénéficiaire à rester readonly
function lockBeneficiaire() {
    var nomInput = document.getElementById('sortieNom');
    if (!nomInput) return;
    nomInput.readOnly = true;
    nomInput.style.backgroundColor = '#e9ecef';
    nomInput.style.cursor = 'not-allowed';
}

// ─── ReadOnly numéro ───────────────────────────────────────
function setNumeroReadOnly() {
    var numEl = document.getElementById('sortieNumero');
    if (!numEl) return;
    numEl.readOnly = true;
    numEl.style.backgroundColor = '#e9ecef';
    numEl.style.color = '#6c757d';
    numEl.style.cursor = 'not-allowed';
}

// ─── Loading bouton ────────────────────────────────────────
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

// ─── Activer/désactiver les champs ─────────────────────────
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#saisieModal input, #saisieModal select, #saisieModal textarea');
    for (var i = 0; i < inputs.length; i++) {
        // Le numéro ET le bénéficiaire restent readonly (jamais disabled)
        if (inputs[i].id === 'sortieNumero' || inputs[i].id === 'sortieNom') continue;

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

    var ligneBtns = document.querySelectorAll('#saisieModal .btn-ligne-action');
    for (var j = 0; j < ligneBtns.length; j++) {
        if (ligneBtns[j].getAttribute('data-keep-active') === 'true') {
            ligneBtns[j].disabled = false;
            continue;
        }
        ligneBtns[j].disabled = !enabled;
    }
}

// ─── Visibilité des boutons d'action ───────────────────────
function setActionButtonsVisible(visible) {
    var btnSave = document.getElementById('btnSaveSaisie');
    if (btnSave) btnSave.style.display = visible ? '' : 'none';
    var btnReset = document.getElementById('btnResetSaisie');
    if (btnReset) btnReset.style.display = visible ? '' : 'none';

    var btnAnnuler = document.getElementById('btnAnnulerDemande');
    if (btnAnnuler) {
        btnAnnuler.style.display = '';
        btnAnnuler.disabled = false;
        btnAnnuler.style.opacity = '1';
        btnAnnuler.style.cursor = 'pointer';
    }
}

// ============================================================
// AJOUT
// ============================================================
function openModalSaisie(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    currentMode = 'add';
    var title = getModalTitle();
    if (title) title.innerHTML = '<i class="fas fa-plus"></i> Nouvelle demande';
    resetFormSaisie();
    setFieldsEnabled(true);
    setNumeroReadOnly();
    lockBeneficiaire();
    setActionButtonsVisible(true);
    document.getElementById('saisieModal').style.display = 'flex';

    // ✅ Rappel discret
    var nomConnecte = getCurrentUserNom();
    if (nomConnecte) {
        showToast('Info', 'Bénéficiaire automatique : ' + nomConnecte, 'info', 2500);
    }
}

// ============================================================
// FERMETURE
// ============================================================
function closeModalSaisie() {
    document.getElementById('saisieModal').style.display = 'none';
    AppState.editingId = null;
    currentMode = 'add';
    setFieldsEnabled(true);
    setActionButtonsVisible(true);
    clearErrors();
}

// ============================================================
// RÉINITIALISATION
// ============================================================
function resetFormSaisie() {
    var numero = document.getElementById('sortieNumero');
    if (numero) {
        numero.value = '';
        numero.placeholder = 'Sera généré automatiquement';
    }
    var date = document.getElementById('sortieDate');
    if (date) date.value = toLocalISO(new Date());
    var dest = document.getElementById('sortieDestination');
    if (dest) dest.value = '';

    // ✅ Bénéficiaire : rempli automatiquement avec l'utilisateur connecté
    var nom = document.getElementById('sortieNom');
    if (nom) nom.value = getCurrentUserNom();

    var fonction = document.getElementById('sortieFonction');
    if (fonction) fonction.value = '';
    var notes = document.getElementById('sortieNotes');
    if (notes) notes.value = '';
    var lignesBody = document.getElementById('lignesBody');
    if (lignesBody) lignesBody.innerHTML = '';
    ajouterLigne();
    setNumeroReadOnly();
    lockBeneficiaire();
    clearErrors();
}

// ============================================================
// CHARGEMENT DANS LE MODAL
// ============================================================
function chargerDemandeDansModal(demande) {
    var numero = document.getElementById('sortieNumero');
    if (numero) numero.value = demande.NUMERO || '';
    setNumeroReadOnly();

    var date = document.getElementById('sortieDate');
    if (date) {
        var d = parseDateValue(demande.DATE_SORTIE);
        date.value = d ? toLocalISO(d) : '';
    }
    var dest = document.getElementById('sortieDestination');
    if (dest) dest.value = demande.DESTINATION || '';

    // ✅ Bénéficiaire : valeur historique (VIEW/EDIT)
    var nom = document.getElementById('sortieNom');
    if (nom) nom.value = demande.NOM || getCurrentUserNom();

    var fonction = document.getElementById('sortieFonction');
    if (fonction) fonction.value = demande.FONCTION || '';
    var notes = document.getElementById('sortieNotes');
    if (notes) notes.value = demande.NOTES || '';

    var lignesBody = document.getElementById('lignesBody');
    if (lignesBody) lignesBody.innerHTML = '';
    var lignes = demande.Lignes || [];
    if (lignes.length) {
        lignes.forEach(function (l) {
            ajouterLigne(l.ARTICLE_ID, l.QUANTITE_D, l.OBSERVATIONS);
        });
    } else {
        ajouterLigne();
    }
    lockBeneficiaire();
}

// ============================================================
// SAUVEGARDE
// ============================================================
async function saveSaisie(e) {
    e.preventDefault();
    if (currentMode === 'view') {
        showToast('Info', 'Vous êtes en consultation, aucune modification possible.', 'info');
        return;
    }

    var id = AppState.editingId;
    var data = {
        dateSortie: document.getElementById('sortieDate').value,
        destination: document.getElementById('sortieDestination').value.trim(),
        // ✅ Envoie le nom de la session (le serveur le revérifie de toute façon)
        nom: getCurrentUserNom(),
        fonction: document.getElementById('sortieFonction').value.trim(),
        notes: document.getElementById('sortieNotes').value.trim(),
        lignes: getLignesFromModal(),
        // ✅ Marqueur : le serveur doit utiliser AuthHelper.GetUserFullName()
        source: 'saisie'
    };

    if (id) {
        var numEl = document.getElementById('sortieNumero');
        data.numero = numEl ? numEl.value.trim() : '';
    }

    var valid = true;
    clearErrors();
    if (!data.dateSortie) { showError('sortieDate', 'La date est requise'); valid = false; }
    if (!data.destination) { showError('sortieDestination', 'La destination est requise'); valid = false; }
    if (!data.lignes.length) { showToast('Erreur', 'Ajoutez au moins une ligne d\'article', 'error'); valid = false; }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload = id ? Object.assign({}, data, { id: id }) : data;
    var btnSave = document.getElementById('btnSaveSaisie');

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
            var msg = result.message || (id ? 'Demande modifiée' : 'Demande créée');
            if (result.numero && !id) msg = 'Demande créée avec succès (' + result.numero + ').';
            showToast('Succès', msg, 'success');
            closeModalSaisie();
            loadDemandes();
            loadDemandesStats();
        } else {
            showToast('Erreur', result.message || 'Échec de l\'opération', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        setButtonLoading(btnSave, false);
        hideSpinner();
    }
}

// ============================================================
// VISUALISATION
// ============================================================
function viewDemande(id) {
    var demande = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!demande) return;
    AppState.editingId = id;
    currentMode = 'view';

    var title = getModalTitle();
    if (title) title.innerHTML = '<i class="fas fa-eye"></i> Détails de la demande';

    chargerDemandeDansModal(demande);
    setFieldsEnabled(false);
    setNumeroReadOnly();
    lockBeneficiaire();
    setActionButtonsVisible(false);

    var btnAnnuler = document.getElementById('btnAnnulerDemande');
    if (btnAnnuler) {
        btnAnnuler.disabled = false;
        btnAnnuler.style.opacity = '1';
        btnAnnuler.style.cursor = 'pointer';
        btnAnnuler.style.display = '';
    }

    clearErrors();
    document.getElementById('saisieModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editDemande(id) {
    var demande = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!demande) return;
    if (demande.STATUT !== 'BROUILLON') {
        showToast('Attention', 'Cette demande est déjà validée et ne peut pas être modifiée.', 'warning');
        return;
    }
    AppState.editingId = id;
    currentMode = 'edit';
    var title = getModalTitle();
    if (title) title.innerHTML = '<i class="fas fa-edit"></i> Modifier la demande';
    chargerDemandeDansModal(demande);
    setFieldsEnabled(true);
    setNumeroReadOnly();
    lockBeneficiaire();
    setActionButtonsVisible(true);
    clearErrors();
    document.getElementById('saisieModal').style.display = 'flex';
}

// ============================================================
// SUPPRESSION (avec mot de passe)
// ============================================================
async function deleteDemande(id) {
    var demande = AppState.sorties.find(function (s) { return s.ID === id; });
    if (demande && demande.STATUT !== 'BROUILLON') {
        showToast('Attention', 'Impossible de supprimer une demande validée.', 'warning');
        return;
    }

    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        html:
            '<p style="margin-bottom:14px;color:#495057;">' +
                'Voulez-vous vraiment supprimer cette demande ?' +
            '</p>' +
            '<div style="text-align:left;">' +
                '<label for="swalDeletePwd" style="font-weight:600;font-size:13px;display:block;margin-bottom:6px;color:#212529;">' +
                    'Mot de passe de suppression <span style="color:#dc3545;">*</span>' +
                '</label>' +
                '<input type="password" id="swalDeletePwd" class="swal2-input" autocomplete="off" ' +
                    'placeholder="Saisissez le mot de passe" style="width:100%;margin:0;box-sizing:border-box;" />' +
                '<div id="swalDeletePwdError" style="color:#dc3545;font-size:12.5px;margin-top:6px;display:none;font-weight:600;"></div>' +
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
            var pwd = document.getElementById('swalDeletePwd');
            if (pwd) pwd.focus();
        },
        preConfirm: async function () {
            var pwdInput = document.getElementById('swalDeletePwd');
            var errEl = document.getElementById('swalDeletePwdError');
            var pwd = pwdInput ? pwdInput.value : '';

            if (!pwd) {
                if (errEl) {
                    errEl.textContent = 'Veuillez saisir le mot de passe.';
                    errEl.style.display = 'block';
                }
                return false;
            }

            try {
                var url = API.BASE + API.HANDLERS_PATH + API.DELETE;
                var resp = await fetch(url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ id: id, password: pwd })
                });
                var result = await resp.json();
                if (result && result.success) {
                    return { message: result.message || 'Demande supprimée' };
                }
                if (errEl) {
                    errEl.textContent = result.message || 'Mot de passe incorrect.';
                    errEl.style.display = 'block';
                }
                if (pwdInput) { pwdInput.value = ''; pwdInput.focus(); }
                return false;
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

    showToast('Succès', confirmResult.value.message || 'Demande supprimée', 'success');
    loadDemandes();
    loadDemandesStats();
}

// ============================================================
// ERREURS
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
window.openModalSaisie = openModalSaisie;
window.closeModalSaisie = closeModalSaisie;
window.resetFormSaisie = resetFormSaisie;
window.saveSaisie = saveSaisie;
window.viewDemande = viewDemande;
window.editDemande = editDemande;
window.deleteDemande = deleteDemande;
window.showError = showError;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
window.setActionButtonsVisible = setActionButtonsVisible;
window.getModalTitle = getModalTitle;
window.setNumeroReadOnly = setNumeroReadOnly;
window.setButtonLoading = setButtonLoading;
window.getCurrentUserNom = getCurrentUserNom;
window.lockBeneficiaire = lockBeneficiaire;
