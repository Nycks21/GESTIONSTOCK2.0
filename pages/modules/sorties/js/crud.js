// ============================================================
// CRUD - SORTIES
// ============================================================

var currentMode = 'add'; // 'add', 'edit', 'view'

// Fonction pour activer/désactiver les champs du modal
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#sortieModal input, #sortieModal select, #sortieModal textarea');
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
    var ligneBtns = document.querySelectorAll('#sortieModal .btn-success, #sortieModal .btn-danger');
    for (var j = 0; j < ligneBtns.length; j++) {
        ligneBtns[j].disabled = !enabled;
    }
}

// Fonction pour masquer/afficher le bouton Annuler (ID: btnAnnulerSortie)
function setAnnulerButtonVisible(visible) {
    var btnAnnuler = document.getElementById('btnAnnulerSortie');
    if (btnAnnuler) {
        btnAnnuler.style.display = visible ? '' : 'none';
    }
}

function openAddSortieModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck"></i> Nouveau bon de sortie';
    document.getElementById('sortieForm').reset();
    var now = new Date().toISOString().slice(0, 16);
    document.getElementById('sortieDate').value = now;
    document.getElementById('lignesBody').innerHTML = '';
    setFieldsEnabled(true);
    document.getElementById('btnSaveSortie').style.display = '';
    setAnnulerButtonVisible(true);
    ajouterLigne();
    clearErrors();
    showModal('sortieModal');
}

function editSortie(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!sortie) return;
    AppState.editingId = id;
    currentMode = 'edit';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier le bon de sortie';
    chargerSortieDansModal(sortie);
    setFieldsEnabled(true);
    document.getElementById('btnSaveSortie').style.display = '';
    setAnnulerButtonVisible(true);
    clearErrors();
    showModal('sortieModal');
}

function viewSortie(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!sortie) return;
    AppState.editingId = id;
    currentMode = 'view';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-eye"></i> Détails du bon de sortie';
    chargerSortieDansModal(sortie);
    setFieldsEnabled(false);
    document.getElementById('btnSaveSortie').style.display = 'none';
    setAnnulerButtonVisible(false);
    clearErrors();
    showModal('sortieModal');
}

function chargerSortieDansModal(sortie) {
    document.getElementById('sortieNumero').value = sortie.NUMERO || '';
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

async function saveSortie(e) {
    e.preventDefault();
    if (currentMode === 'view') {
        showToast('Info', 'Vous êtes en mode consultation, aucune modification n\'est possible.', 'info');
        return;
    }
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
            closeSortieModal();
            loadSorties();
            loadSortieStats();
            // ✅ Mise à jour du badge
            if (typeof updateSortieBadge === 'function') updateSortieBadge();
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
    // Vérifier si le bon est validé (on ne supprime pas un bon validé)
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (sortie && sortie.STATUT === 'VALIDE') {
        showToast('Attention', 'Impossible de supprimer un bon de sortie validé.', 'warning');
        return;
    }

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
            if (typeof updateSortieBadge === 'function') updateSortieBadge();
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
    // Vérifier si déjà validé
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
            if (typeof updateSortieBadge === 'function') updateSortieBadge();
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
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck"></i> Nouveau bon de sortie';
    setFieldsEnabled(true);
    document.getElementById('btnSaveSortie').style.display = '';
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

// Expositions globales
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
