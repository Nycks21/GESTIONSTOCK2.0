// crud.js - Module Entrées avec génération automatique du NUMÉRO
var currentMode = 'add'; // 'add', 'edit', 'view'

// ============================================================
// UTILITAIRE : activer / désactiver les champs du modal
// ============================================================
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
    // Désactiver les boutons d'ajout/suppression de lignes
    var ligneBtns = document.querySelectorAll('#entreeModal .btn-success, #entreeModal .btn-danger');
    for (var j = 0; j < ligneBtns.length; j++) {
        ligneBtns[j].disabled = !enabled;
    }
}

// Masquer/afficher le bouton Annuler (ID spécifique)
function setAnnulerButtonVisible(visible) {
    var btnAnnuler = document.getElementById('btnAnnulerButton');
    if (btnAnnuler) {
        btnAnnuler.style.display = visible ? '' : 'none';
    }
}

// ============================================================
// UTILITAIRE : appliquer le style readonly au champ Numéro
// ============================================================
function setNumeroReadOnly() {
    var numEl = document.getElementById('entreeNumero');
    if (!numEl) return;
    numEl.readOnly = true;
    numEl.style.backgroundColor = '#e9ecef';
    numEl.style.cursor = 'not-allowed';
}

// ============================================================
// AJOUT
// ============================================================
function openAddEntreeModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck-loading"></i> Nouveau bon d\'entrée';
    document.getElementById('entreeForm').reset();

    var now = new Date().toISOString().slice(0, 16);
    document.getElementById('entreeDate').value = now;

    // 🔒 Le NUMÉRO est généré côté serveur → champ vide, en lecture seule
    var numEl = document.getElementById('entreeNumero');
    numEl.value = '';
    numEl.placeholder = 'Sera généré automatiquement (ENT-XXX-00001)';
    setNumeroReadOnly();

    document.getElementById('lignesBody').innerHTML = '';

    setFieldsEnabled(true);

    // setFieldsEnabled réactive les champs → on réapplique le readonly sur le numéro
    setNumeroReadOnly();

    document.getElementById('btnSaveEntree').style.display = '';
    setAnnulerButtonVisible(true);
    ajouterLigne();
    clearErrors();
    showModal('entreeModal');
}

// ============================================================
// MODIFICATION
// ============================================================
function editEntree(id) {
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (!entree) return;
    AppState.editingId = id;
    currentMode = 'edit';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier le bon d\'entrée';
    chargerEntreeDansModal(entree);
    setFieldsEnabled(true);
    setNumeroReadOnly(); // le numéro reste immuable
    document.getElementById('btnSaveEntree').style.display = '';
    setAnnulerButtonVisible(true);
    clearErrors();
    showModal('entreeModal');
}

// ============================================================
// VISUALISATION
// ============================================================
function viewEntree(id) {
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (!entree) return;
    AppState.editingId = id;
    currentMode = 'view';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-eye"></i> Détails du bon d\'entrée';
    chargerEntreeDansModal(entree);
    setFieldsEnabled(false);
    setNumeroReadOnly();
    document.getElementById('btnSaveEntree').style.display = 'none';
    setAnnulerButtonVisible(false); // Masquer Annuler en mode VIEW
    clearErrors();
    showModal('entreeModal');
}

// ============================================================
// CHARGEMENT DES DONNÉES DANS LE MODAL
// ============================================================
function chargerEntreeDansModal(entree) {
    // Numéro (toujours en lecture seule)
    var numEl = document.getElementById('entreeNumero');
    numEl.value = entree.NUMERO || '';
    setNumeroReadOnly();

    // Date
    var dateStr = '';
    if (entree.DATE_ENTREE) {
        try {
            var d = new Date(entree.DATE_ENTREE);
            if (!isNaN(d.getTime())) {
                dateStr = d.toISOString().slice(0, 16);
            }
        } catch (e) { /* ignore */ }
    }
    document.getElementById('entreeDate').value = dateStr;

    // Fournisseur / référence / notes
    document.getElementById('entreeFournisseur').value = entree.FOURNISSEUR_ID || '';
    document.getElementById('entreeReference').value = entree.REFERENCE || '';
    document.getElementById('entreeNotes').value = entree.NOTES || '';

    // Lignes
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

// ============================================================
// ENREGISTREMENT (ajout ou modification)
// ============================================================
async function saveEntree(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast('Info', 'Vous êtes en mode consultation, aucune modification n\'est possible.', 'info');
        return;
    }

    var id = AppState.editingId;

    // ⚠️ Le NUMERO n'est plus envoyé :
    //    - à l'ajout → généré côté serveur (ENT-PROJET-00001)
    //    - en modification → immuable, non modifiable
    var data = {
        dateEntree: document.getElementById('entreeDate').value,
        fournisseurId: document.getElementById('entreeFournisseur').value,
        reference: document.getElementById('entreeReference').value.trim(),
        notes: document.getElementById('entreeNotes').value.trim(),
        lignes: getLignesFromModal()
    };

    var valid = true;
    clearErrors();
    if (!data.dateEntree) { showError('entreeDate', 'La date est requise'); valid = false; }
    if (!data.fournisseurId) { showError('entreeFournisseur', 'Le fournisseur est requis'); valid = false; }
    if (!data.lignes.length) { showToast('Erreur', 'Ajoutez au moins une ligne d\'article', 'error'); valid = false; }
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
            var msg = result.message || (id ? 'Bon modifié' : 'Bon créé');
            if (result.numero && !id) msg = 'Bon d\'entrée créé avec succès (' + result.numero + ').';
            showToast('Succès', msg, 'success');
            closeEntreeModal();
            loadEntrees();
            loadEntreeStats();
        } else {
            showToast('Erreur', result.message || 'Une erreur est survenue', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// SUPPRESSION (avec vérification du mot de passe côté serveur)
// ⚠️  Identique au pattern SORTIE :
//     - Modal SweetAlert avec champ mot de passe
//     - Vérification côté serveur (EntreeDelete.ashx)
//     - Tant que le mot de passe est incorrect, le modal reste ouvert
// ============================================================
async function deleteEntree(id) {
    // Vérifier si le bon est validé (on ne supprime pas un bon validé)
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (entree && entree.STATUT === 'VALIDE') {
        showToast('Attention', 'Impossible de supprimer un bon d\'entrée validé.', 'warning');
        return;
    }

    // ============================================================
    // MODAL DE CONFIRMATION AVEC CHAMP MOT DE PASSE
    // ============================================================
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        html:
            '<p style="margin-bottom:14px;color:#495057;">' +
                'Voulez-vous vraiment supprimer ce bon d\'entrée ?' +
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
    loadEntrees();
    loadEntreeStats();
}

// ============================================================
// VALIDATION
// ============================================================
async function validerEntree(id) {
    // Vérifier si déjà validé
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (entree && entree.STATUT === 'VALIDE') {
        showToast('Info', 'Ce bon est déjà validé.', 'info');
        return;
    }

    var confirm = await Swal.fire({
        title: 'Valider le bon',
        text: 'Valider ce bon d\'entrée va mettre à jour les stocks. Continuer ?',
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#28a745',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Oui, valider',
        cancelButtonText: 'Annuler'
    });
    if (!confirm.isConfirmed) return;

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
            loadEntrees();
            loadEntreeStats();
        } else {
            showToast('Erreur', result.message || 'Échec de la validation', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// FERMETURE DU MODAL
// ============================================================
function closeEntreeModal() {
    closeModal('entreeModal');
    AppState.editingId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck-loading"></i> Nouveau bon d\'entrée';

    setFieldsEnabled(true);

    // Repasser le champ numéro en mode "généré auto"
    var numEl = document.getElementById('entreeNumero');
    if (numEl) {
        numEl.value = '';
        numEl.placeholder = 'Sera généré automatiquement (ENT-XXX-00001)';
        setNumeroReadOnly();
    }

    document.getElementById('btnSaveEntree').style.display = '';
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
window.openAddEntreeModal = openAddEntreeModal;
window.editEntree = editEntree;
window.viewEntree = viewEntree;
window.saveEntree = saveEntree;
window.deleteEntree = deleteEntree;
window.validerEntree = validerEntree;
window.closeEntreeModal = closeEntreeModal;
window.showError = showError;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
window.setAnnulerButtonVisible = setAnnulerButtonVisible;
window.setNumeroReadOnly = setNumeroReadOnly;
