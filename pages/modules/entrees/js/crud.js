function openAddEntreeModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    document.getElementById('modalTitle').textContent = 'Nouveau bon d\'entrée';
    document.getElementById('entreeForm').reset();
    var now = new Date().toISOString().slice(0, 16);
    document.getElementById('entreeDate').value = now;
    document.getElementById('lignesBody').innerHTML = '';
    ajouterLigne();
    clearErrors();
    showModal('entreeModal');
}

function editEntree(id) {
    var entree = AppState.entrees.find(function (e) { return e.ID === id; });
    if (!entree) return;
    AppState.editingId = id;
    document.getElementById('modalTitle').textContent = 'Modifier le bon d\'entrée';
    document.getElementById('entreeNumero').value = entree.NUMERO || '';
    // Gestion robuste de la date
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
    clearErrors();
    showModal('entreeModal');
}

async function saveEntree(e) {
    e.preventDefault();
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
            closeModal('entreeModal');
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
            showToast('Erreur', result.message || 'Échec de la suppression', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

async function validerEntree(id) {
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
window.saveEntree = saveEntree;
window.deleteEntree = deleteEntree;
window.validerEntree = validerEntree;
window.closeEntreeModal = closeEntreeModal;
window.showError = showError;
window.clearErrors = clearErrors;
