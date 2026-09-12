// crud.js - Module Fournisseurs avec génération automatique du CODE
var currentFournisseurId = null;
var currentMode = 'add'; // 'add', 'edit', 'view'

// ============================================================
// UTILITAIRE : activer / désactiver les champs
// ============================================================
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#fournisseurModal input, #fournisseurModal select, #fournisseurModal textarea');
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
function openAddFournisseurModal(e) {
    if (e) e.preventDefault();
    currentFournisseurId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck"></i> Ajouter un fournisseur';
    document.getElementById('fournisseurForm').reset();
    document.getElementById('fournisseurActif').value = '1';

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('fournisseurCode');
    codeEl.value = '';
    codeEl.placeholder = 'Sera généré automatiquement (FRS-XXX-00001)';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    setFieldsEnabled(true);

    // setFieldsEnabled réactive les champs → on réapplique le readonly sur le code
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveFournisseur').style.display = '';
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    document.getElementById('fournisseurModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editFournisseur(id) {
    var fournisseur = AppState.fournisseurs.find(function (f) { return f.ID === id; });
    if (!fournisseur) return;
    currentFournisseurId = id;
    currentMode = 'edit';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier un fournisseur';

    var codeEl = document.getElementById('fournisseurCode');
    codeEl.value = fournisseur.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('fournisseurNom').value = fournisseur.NOM || '';
    document.getElementById('fournisseurAdresse').value = fournisseur.ADRESSE || '';
    document.getElementById('fournisseurTelephone').value = fournisseur.TELEPHONE || '';
    document.getElementById('fournisseurEmail').value = fournisseur.EMAIL || '';
    document.getElementById('fournisseurContactNom').value = fournisseur.CONTACT_NOM || '';
    document.getElementById('fournisseurContactTelephone').value = fournisseur.CONTACT_TELEPHONE || '';
    document.getElementById('fournisseurSiret').value = fournisseur.SIRET || '';
    document.getElementById('fournisseurActif').value = fournisseur.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);

    // Réapplication du readonly sur le code (le code est immuable)
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveFournisseur').style.display = '';
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    document.getElementById('fournisseurModal').style.display = 'flex';
}

// ============================================================
// VISUALISATION
// ============================================================
function viewFournisseur(id) {
    var fournisseur = AppState.fournisseurs.find(function (f) { return f.ID === id; });
    if (!fournisseur) return;
    currentFournisseurId = id;
    currentMode = 'view';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-eye"></i> Détails du fournisseur';

    var codeEl = document.getElementById('fournisseurCode');
    codeEl.value = fournisseur.CODE || '';

    document.getElementById('fournisseurNom').value = fournisseur.NOM || '';
    document.getElementById('fournisseurAdresse').value = fournisseur.ADRESSE || '';
    document.getElementById('fournisseurTelephone').value = fournisseur.TELEPHONE || '';
    document.getElementById('fournisseurEmail').value = fournisseur.EMAIL || '';
    document.getElementById('fournisseurContactNom').value = fournisseur.CONTACT_NOM || '';
    document.getElementById('fournisseurContactTelephone').value = fournisseur.CONTACT_TELEPHONE || '';
    document.getElementById('fournisseurSiret').value = fournisseur.SIRET || '';
    document.getElementById('fournisseurActif').value = fournisseur.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveFournisseur').style.display = 'none';
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    document.getElementById('fournisseurModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT (ajout ou modification)
// ============================================================
async function saveFournisseur(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast('Info', 'Vous êtes en mode consultation, aucune modification n\'est possible.', 'info');
        return;
    }

    var id = currentFournisseurId;

    // ⚠️ Le CODE n'est plus envoyé :
    //    - à l'ajout → généré côté serveur (FRS-XXX-00001)
    //    - en modification → immuable, non modifiable
    var data = {
        nom: document.getElementById('fournisseurNom').value.trim(),
        adresse: document.getElementById('fournisseurAdresse').value.trim(),
        telephone: document.getElementById('fournisseurTelephone').value.trim(),
        email: document.getElementById('fournisseurEmail').value.trim(),
        contactNom: document.getElementById('fournisseurContactNom').value.trim(),
        contactTelephone: document.getElementById('fournisseurContactTelephone').value.trim(),
        siret: document.getElementById('fournisseurSiret').value.trim(),
        actif: parseInt(document.getElementById('fournisseurActif').value) === 1
    };

    // Validation : seul le nom est requis
    var valid = true;
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
    if (!data.nom) { showFieldError('fournisseurNom', 'Le nom est requis'); valid = false; }
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
            var msg = result.message || (id ? 'Fournisseur modifié' : 'Fournisseur ajouté');
            if (result.code && !id) msg = 'Fournisseur ajouté avec succès (' + result.code + ').';
            showToast('Succès', msg, 'success');
            closeFournisseurModal();
            loadFournisseurs();
            loadFournisseurStats();
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
async function deleteFournisseur(id) {
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer ce fournisseur ?',
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
            showToast('Succès', 'Fournisseur supprimé', 'success');
            loadFournisseurs();
            loadFournisseurStats();
        } else {
            showToast('Attention', result.message || 'Échec de la suppression', 'error');
        }
    } catch (e) {
        showToast('Attention', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// FERMETURE DU MODAL
// ============================================================
function closeFournisseurModal() {
    document.getElementById('fournisseurModal').style.display = 'none';

    currentFournisseurId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML = '<i class="fas fa-truck"></i> Ajouter un fournisseur';

    setFieldsEnabled(true);

    // Repasser le champ code en mode "généré auto"
    var codeEl = document.getElementById('fournisseurCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = 'Sera généré automatiquement (FRS-XXX-00001)';
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    }

    document.getElementById('btnSaveFournisseur').style.display = '';
    clearFieldErrors(['fournisseurCode', 'fournisseurNom']);
}

// ============================================================
// GESTION DES ERREURS DE CHAMP
// ============================================================
function showFieldError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
}

function clearFieldErrors(fieldIds) {
    fieldIds.forEach(function(id) {
        var err = document.getElementById('err-' + id);
        if (err) { err.textContent = ''; err.style.display = 'none'; }
    });
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.openAddFournisseurModal = openAddFournisseurModal;
window.editFournisseur = editFournisseur;
window.viewFournisseur = viewFournisseur;
window.saveFournisseur = saveFournisseur;
window.deleteFournisseur = deleteFournisseur;
window.closeFournisseurModal = closeFournisseurModal;
window.setFieldsEnabled = setFieldsEnabled;
window.clearFieldErrors = clearFieldErrors;
window.currentFournisseurId = currentFournisseurId;
