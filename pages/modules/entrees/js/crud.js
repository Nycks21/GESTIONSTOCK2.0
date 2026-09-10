// crud.js
var currentMode = 'add'; // 'add', 'edit', 'view'

// Fonction pour activer/désactiver les champs du modal
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

// Fonction pour masquer/afficher le bouton Annuler (utilisation de l'ID spécifique)
function setAnnulerButtonVisible(visible) {
    var btnAnnuler = document.getElementById('btnAnnulerButton');
    if (btnAnnuler) {
        btnAnnuler.style.display = visible ? '' : 'none';
    }
}

function openAddEntreeModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck-loading"></i> Nouveau bon d\'entrée';
    document.getElementById('entreeForm').reset();
    var now = new Date().toISOString().slice(0, 16);
    document.getElementById('entreeDate').value = now;
    document.getElementById('lignesBody').innerHTML = '';
    setFieldsEnabled(true);
    document.getElementById('btnSaveEntree').style.display = '';
    setAnnulerButtonVisible(true); // Afficher Annuler
    ajouterLigne();
    clearErrors();
    showModal('entreeModal');
}

function editEntree(id) {
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (!entree) return;
    AppState.editingId = id;
    currentMode = 'edit';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier le bon d\'entrée';
    chargerEntreeDansModal(entree);
    setFieldsEnabled(true);
    document.getElementById('btnSaveEntree').style.display = '';
    setAnnulerButtonVisible(true); // Afficher Annuler
    clearErrors();
    showModal('entreeModal');
}

function viewEntree(id) {
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (!entree) return;
    AppState.editingId = id;
    currentMode = 'view';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-eye"></i> Détails du bon d\'entrée';
    chargerEntreeDansModal(entree);
    setFieldsEnabled(false);
    document.getElementById('btnSaveEntree').style.display = 'none';
    setAnnulerButtonVisible(false); // Masquer Annuler en mode VIEW
    clearErrors();
    showModal('entreeModal');
}

// Fonction utilitaire pour charger les données dans le modal
function chargerEntreeDansModal(entree) {
    document.getElementById('entreeNumero').value = entree.NUMERO || '';
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
    document.getElementById('entreeFournisseur').value = entree.FOURNISSEUR_ID || '';
    document.getElementById('entreeReference').value = entree.REFERENCE || '';
    document.getElementById('entreeNotes').value = entree.NOTES || '';

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
        showToast('Info', 'Vous êtes en mode consultation, aucune modification n\'est possible.', 'info');
        return;
    }
    var id = AppState.editingId;
    var data = {
        numero: document.getElementById('entreeNumero').value.trim(),
        dateEntree: document.getElementById('entreeDate').value,
        fournisseurId: document.getElementById('entreeFournisseur').value,
        reference: document.getElementById('entreeReference').value.trim(),
        notes: document.getElementById('entreeNotes').value.trim(),
        lignes: getLignesFromModal()
    };

    var valid = true;
    clearErrors();
    if (!data.numero) { showError('entreeNumero', 'Le numéro est requis'); valid = false; }
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
            showToast('Succès', result.message || (id ? 'Bon modifié' : 'Bon créé'), 'success');
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

async function deleteEntree(id) {
    // Vérifier si le bon est validé (on ne supprime pas un bon validé)
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (entree && entree.STATUT === 'VALIDE') {
        showToast('Attention', 'Impossible de supprimer un bon d\'entrée validé.', 'warning');
        return;
    }

    var confirm = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer ce bon d\'entrée ?',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    });
    if (!confirm.isConfirmed) return;

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
            showToast('Succès', 'Bon supprimé', 'success');
            loadEntrees();
            loadEntreeStats();
        } else {
            showToast('Attention', result.message || 'Échec de la suppression', 'error');
        }
    } catch (err) {
        showToast('Attention', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

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

function closeEntreeModal() {
    closeModal('entreeModal');
    AppState.editingId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck-loading"></i> Nouveau bon d\'entrée';
    setFieldsEnabled(true);
    document.getElementById('btnSaveEntree').style.display = '';
    setAnnulerButtonVisible(true); // Réafficher Annuler
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

// Expositions globales
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
