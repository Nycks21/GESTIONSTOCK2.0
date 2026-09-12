// crud.js – Version avec génération automatique du CODE côté serveur
var currentUniteId = null;
var currentMode = 'add'; // 'add', 'edit', 'view'

// ============================================================
// UTILITAIRE : activer / désactiver les champs du modal
// ============================================================
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#uniteModal input, #uniteModal select, #uniteModal textarea');
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
function openAddUniteModal(e) {
    if (e) e.preventDefault();
    currentUniteId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-ruler"></i> Ajouter une unité';
    document.getElementById('uniteForm').reset();
    document.getElementById('uniteActif').value = '1';

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('uniteCode');
    codeEl.value = '';
    codeEl.placeholder = 'Sera généré automatiquement (UNT-XXX-00001)';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    setFieldsEnabled(true);

    // setFieldsEnabled réactive les champs → on réapplique le readonly sur le code
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveUnite').style.display = '';
    clearErrors();
    document.getElementById('uniteModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editUnite(id) {
    var unite = AppState.unites.find(function (u) { return u.ID === id; });
    if (!unite) return;
    currentUniteId = id;
    currentMode = 'edit';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier une unité';

    var codeEl = document.getElementById('uniteCode');
    codeEl.value = unite.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('uniteNom').value = unite.NOM || '';
    document.getElementById('uniteActif').value = unite.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);

    // Réapplication du readonly sur le code (le code est immuable)
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveUnite').style.display = '';
    clearErrors();
    document.getElementById('uniteModal').style.display = 'flex';
}

// ============================================================
// VISUALISATION
// ============================================================
function viewUnite(id) {
    var unite = AppState.unites.find(function (u) { return u.ID === id; });
    if (!unite) return;
    currentUniteId = id;
    currentMode = 'view';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-eye"></i> Détails de l\'unité';

    var codeEl = document.getElementById('uniteCode');
    codeEl.value = unite.CODE || '';

    document.getElementById('uniteNom').value = unite.NOM || '';
    document.getElementById('uniteActif').value = unite.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveUnite').style.display = 'none';
    clearErrors();
    document.getElementById('uniteModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT (ajout ou modification)
// ============================================================
async function saveUnite(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast('Info', 'Vous êtes en mode consultation, aucune modification n\'est possible.', 'info');
        return;
    }

    var id = currentUniteId;

    // ⚠️ Le CODE n'est plus envoyé :
    //    - à l'ajout → généré côté serveur (UN-PROJET-00001)
    //    - en modification → immuable, non modifiable
    var data = {
        nom: document.getElementById('uniteNom').value.trim(),
        actif: parseInt(document.getElementById('uniteActif').value) === 1
    };

    // Validation : seul le nom est requis
    var valid = true;
    clearErrors();
    if (!data.nom) { showError('uniteNom', 'Le nom est requis'); valid = false; }
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
            // Afficher le code généré s'il est renvoyé par le serveur
            var msg = result.message || (id ? 'Unité modifiée' : 'Unité ajoutée');
            if (result.code && !id) msg = 'Unité ajoutée avec succès (' + result.code + ').';
            showToast('Succès', msg, 'success');
            closeUniteModal();
            loadUnites();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Une erreur est survenue', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// SUPPRESSION
// ============================================================
async function deleteUnite(id) {
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer cette unité ?',
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
            showToast('Succès', 'Unité supprimée', 'success');
            loadUnites();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Échec de la suppression', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// FERMETURE DU MODAL
// ============================================================
function closeUniteModal() {
    document.getElementById('uniteModal').style.display = 'none';

    // Réinitialiser l'état pour le prochain usage
    currentUniteId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-ruler"></i> Ajouter une unité';

    setFieldsEnabled(true);

    // Repasser le champ code en mode "généré auto"
    var codeEl = document.getElementById('uniteCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = 'Sera généré automatiquement (UNT-XXX-00001)';
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    }

    document.getElementById('btnSaveUnite').style.display = '';
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
    var errors = document.querySelectorAll('.field-error');
    for (var i = 0; i < errors.length; i++) {
        errors[i].textContent = '';
        errors[i].style.display = 'none';
    }
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.openAddUniteModal = openAddUniteModal;
window.editUnite = editUnite;
window.viewUnite = viewUnite;
window.saveUnite = saveUnite;
window.deleteUnite = deleteUnite;
window.closeUniteModal = closeUniteModal;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
