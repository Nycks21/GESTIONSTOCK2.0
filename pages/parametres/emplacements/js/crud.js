// crud.js - Module Emplacements avec génération automatique du CODE
var currentMode = 'add'; // 'add', 'edit', 'view'

// ============================================================
// UTILITAIRE : activer / désactiver les champs
// ============================================================
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#emplacementModal input, #emplacementModal select, #emplacementModal textarea');
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
}

// ============================================================
// AJOUT
// ============================================================
function openAddEmplacementModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-warehouse"></i> Ajouter un emplacement';
    document.getElementById('emplacementForm').reset();
    document.getElementById('emplacementActif').value = '1';
    document.getElementById('emplacementParent').value = '';

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('emplacementCode');
    codeEl.value = '';
    codeEl.placeholder = 'Sera généré automatiquement (EMP-XXX-00001)';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    setFieldsEnabled(true);

    // setFieldsEnabled réactive les champs → on réapplique le readonly sur le code
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveEmplacement').style.display = '';
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    document.getElementById('emplacementModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editEmplacement(id) {
    var emplacement = AppState.emplacements.find(function (e) { return e.ID === id; });
    if (!emplacement) return;
    AppState.editingId = id;
    currentMode = 'edit';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier un emplacement';

    var codeEl = document.getElementById('emplacementCode');
    codeEl.value = emplacement.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('emplacementNom').value = emplacement.NOM || '';
    document.getElementById('emplacementType').value = emplacement.TYPE || '';
    document.getElementById('emplacementParent').value = emplacement.PARENT_ID || '';
    document.getElementById('emplacementActif').value = emplacement.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);

    // Réapplication du readonly sur le code (le code est immuable)
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveEmplacement').style.display = '';
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    document.getElementById('emplacementModal').style.display = 'flex';
}

// ============================================================
// VISUALISATION
// ============================================================
function viewEmplacement(id) {
    var emplacement = AppState.emplacements.find(function (e) { return e.ID === id; });
    if (!emplacement) return;
    AppState.editingId = id;
    currentMode = 'view';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-eye"></i> Détails de l\'emplacement';

    var codeEl = document.getElementById('emplacementCode');
    codeEl.value = emplacement.CODE || '';

    document.getElementById('emplacementNom').value = emplacement.NOM || '';
    document.getElementById('emplacementType').value = emplacement.TYPE || '';
    document.getElementById('emplacementParent').value = emplacement.PARENT_ID || '';
    document.getElementById('emplacementActif').value = emplacement.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveEmplacement').style.display = 'none';
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    document.getElementById('emplacementModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT (ajout ou modification)
// ============================================================
async function saveEmplacement(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast('Info', 'Vous êtes en mode consultation, aucune modification n\'est possible.', 'info');
        return;
    }

    var id = AppState.editingId;

    // ⚠️ Le CODE n'est plus envoyé :
    //    - à l'ajout → généré côté serveur (EMP-PROJET-00001)
    //    - en modification → immuable, non modifiable
    var data = {
        nom: document.getElementById('emplacementNom').value.trim(),
        type: document.getElementById('emplacementType').value,
        parentId: document.getElementById('emplacementParent').value || null,
        actif: parseInt(document.getElementById('emplacementActif').value) === 1
    };

    // Validation : nom et type requis
    var valid = true;
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
    if (!data.nom) { showFieldError('emplacementNom', 'Le nom est requis'); valid = false; }
    if (!data.type) { showFieldError('emplacementType', 'Le type est requis'); valid = false; }
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
            var msg = result.message || (id ? 'Emplacement modifié' : 'Emplacement ajouté');
            if (result.code && !id) msg = 'Emplacement ajouté avec succès (' + result.code + ').';
            showToast('Succès', msg, 'success');
            closeEmplacementModal();
            loadEmplacements();
            loadStats();
        } else {
            showToast('Attention', result.message || 'Une erreur est survenue', 'error');
        }
    } catch (err) {
        showToast('Attention', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// SUPPRESSION
// ============================================================
async function deleteEmplacement(id) {
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer cet emplacement ?',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    });
    if (!confirmResult.isConfirmed) return;

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
            showToast('Succès', 'Emplacement supprimé', 'success');
            loadEmplacements();
            loadStats();
        } else {
            showToast('Attention', result.message || 'Échec de la suppression', 'error');
        }
    } catch (err) {
        showToast('Attention', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// FERMETURE DU MODAL
// ============================================================
function closeEmplacementModal() {
    document.getElementById('emplacementModal').style.display = 'none';
    AppState.editingId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-warehouse"></i> Ajouter un emplacement';

    setFieldsEnabled(true);

    // Repasser le champ code en mode "généré auto"
    var codeEl = document.getElementById('emplacementCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = 'Sera généré automatiquement (EMP-XXX-00001)';
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    }

    document.getElementById('btnSaveEmplacement').style.display = '';
    clearFieldErrors(['emplacementCode', 'emplacementNom', 'emplacementType']);
}

// ============================================================
// GESTION DES ERREURS DE CHAMP
// ============================================================
function showFieldError(fieldId, msg) {
    var err = document.getElementById('err-' + fieldId);
    if (err) { err.textContent = msg; err.style.display = 'block'; }
}

function clearFieldErrors(ids) {
    ids.forEach(function (id) {
        var err = document.getElementById('err-' + id);
        if (err) { err.textContent = ''; err.style.display = 'none'; }
    });
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.openAddEmplacementModal = openAddEmplacementModal;
window.editEmplacement = editEmplacement;
window.viewEmplacement = viewEmplacement;
window.saveEmplacement = saveEmplacement;
window.deleteEmplacement = deleteEmplacement;
window.closeEmplacementModal = closeEmplacementModal;
window.setFieldsEnabled = setFieldsEnabled;
window.clearFieldErrors = clearFieldErrors;
