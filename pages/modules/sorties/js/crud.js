// ============================================================
// CRUD - SORTIES
// ============================================================

function openAddSortieModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    document.getElementById('modalTitle').textContent = 'Nouveau bon de sortie';
    document.getElementById('sortieForm').reset();
    var now = new Date().toISOString().slice(0, 16);
    document.getElementById('sortieDate').value = now;
    document.getElementById('lignesBody').innerHTML = '';
    ajouterLigne();
    clearErrors();
    showModal('sortieModal');
}

function editSortie(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!sortie) return;
    AppState.editingId = id;
    document.getElementById('modalTitle').textContent = 'Modifier le bon de sortie';
    document.getElementById('sortieNumero').value = sortie.NUMERO || '';
    var dateStr = '';
    if (sortie.DATE_SORTIE) {
        try {
            var d = new Date(sortie.DATE_SORTIE);
            if (!isNaN(d.getTime())) dateStr = d.toISOString().slice(0, 16);
        } catch (e) { /* ignore */ }
    }
    document.getElementById('sortieDate').value = dateStr;
    document.getElementById('sortieDestination').value = sortie.DESTINATION || '';
    document.getElementById('sortieNom').value = sortie.NOM || '';
    document.getElementById('sortieFonction').value = sortie.FONCTION || '';
    document.getElementById('sortieNotes').value = sortie.NOTES || '';

    document.getElementById('lignesBody').innerHTML = '';
    var lignes = sortie.Lignes || [];
    if (lignes.length) {
        lignes.forEach(function (l) {
            ajouterLigne(l.ARTICLE_ID, l.QUANTITE_D, l.QUANTITE_R, l.OBSERVATIONS);
        });
    } else {
        ajouterLigne();
    }
    clearErrors();
    showModal('sortieModal');
}

async function saveSortie(e) {
    e.preventDefault();
    var id = AppState.editingId;
    var data = {
        numero: document.getElementById('sortieNumero').value.trim(),
        dateSortie: document.getElementById('sortieDate').value,
        destination: document.getElementById('sortieDestination').value.trim(),
        nom: document.getElementById('sortieNom').value.trim(),
        fonction: document.getElementById('sortieFonction').value.trim(),
        notes: document.getElementById('sortieNotes').value.trim(),
        lignes: getLignesFromModal()
    };

    var valid = true;
    clearErrors();
    if (!data.numero) { showError('sortieNumero', 'Le numéro est requis'); valid = false; }
    if (!data.dateSortie) { showError('sortieDate', 'La date est requise'); valid = false; }
    if (!data.destination) { showError('sortieDestination', 'La destination est requise'); valid = false; }
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
            closeModal('sortieModal');
            loadSorties();
            loadSortieStats();
        } else {
            showToast('Erreur', result.message || 'Une erreur est survenue', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

async function deleteSortie(id) {
    var confirm = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer ce bon de sortie ?',
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
            loadSorties();
            loadSortieStats();
        } else {
            showToast('Erreur', result.message || 'Échec de la suppression', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

async function validerSortie(id) {
    var confirm = await Swal.fire({
        title: 'Valider le bon de sortie',
        text: 'Valider ce bon va déduire les quantités (Qté Reçue) du stock. Continuer ?',
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
            loadSorties();
            loadSortieStats();
        } else {
            showToast('Erreur', result.message || 'Échec de la validation', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

function closeSortieModal() {
    closeModal('sortieModal');
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
window.openAddSortieModal = openAddSortieModal;
window.editSortie = editSortie;
window.saveSortie = saveSortie;
window.deleteSortie = deleteSortie;
window.validerSortie = validerSortie;
window.closeSortieModal = closeSortieModal;
window.showError = showError;
window.clearErrors = clearErrors;
