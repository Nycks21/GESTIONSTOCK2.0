/**
 * Classes.js — Gestion Scolaire
 * Adapté à la table SQL Server : [MONAPPECOLE2].[dbo].[ClasseS]
 * Colonnes : ID, NOM, NIVEAU, EFFECTIF, TITULAIRE, SALLE, STATUT
 *
 * Architecture :
 *   Toutes les opérations CRUD passent par des appels AJAX (fetch)
 *   vers les handlers ASP.NET (.ashx) côté serveur.
 *   Le JS ne stocke plus de données en mémoire — la source de vérité est SQL Server.
 */

'use strict';

// ─────────────────────────────────────────────
// URLS DES HANDLERS (relatifs à la page courante)
// ─────────────────────────────────────────────
var API = {
    liste: '/pages/parametres/classes/handlers/GetClasse.ashx',
    ajouter: '/pages/parametres/classes/handlers/AjouterClasse.ashx',
    modifier: '/pages/parametres/classes/handlers/ModifierClasse.ashx',
    supprimer: '/pages/parametres/classes/handlers/SupprimerClasse.ashx',
    niveaux: '/pages/parametres/niveaux/handlers/GetNiveaux.ashx',
    salles: '/pages/parametres/salles/handlers/GetSalles.ashx',
    users: '/pages/administrations/utilisateur/handlers/GetUsers.ashx'
};

// ─────────────────────────────────────────────
// ÉTAT LOCAL (sert uniquement à l'affichage)
// ─────────────────────────────────────────────
var ClassesData = [];   // tableau d'objets rempli depuis le serveur
var editId = null; // ID SQL Server de la ligne en cours d'édition
var currentPage = 1;
var rowsPerPage = 10;
var filteredClasses = [];

// ─────────────────────────────────────────────
// INIT
// ─────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function () {
    forceHideSpinner();
    hidePreloader();
    initUIControls();

    chargerSalles();
    chargerNiveaux();
    chargerUsers();
    chargerClasses(); // premier chargement depuis SQL Server
});

// ─────────────────────────────────────────────
// CHARGER LES NIVEAUX
// ─────────────────────────────────────────────
async function chargerNiveaux() {
    try {
        const response = await fetch(API.niveaux);
        const data = await response.json();

        if (data.success) {
            const select = document.getElementById('ClasseNiveau');
            // On garde la première option par défaut
            select.innerHTML = '<option value="">-- Sélectionner un niveau --</option>';

            data.niveaux.forEach(niv => {
                const opt = document.createElement('option');
                opt.value = niv.ID; // On stocke le GUID (ID) pour la clé étrangère
                opt.textContent = niv.NOM;
                select.appendChild(opt);
            });
        }
    } catch (err) {
        console.error("Erreur lors du chargement des niveaux:", err);
    }
}

// ─────────────────────────────────────────────
// CHARGER LES SALLES
// ─────────────────────────────────────────────
async function chargerSalles() {
    try {
        // ✅ Correction : On appelle l'API des salles, pas celle des niveaux
        const response = await fetch(API.salles);
        const data = await response.json();

        if (data.success) {
            const select = document.getElementById('ClasseSalle');
            if (!select) return;

            // On garde la première option par défaut
            select.innerHTML = '<option value="">-- Sélectionner une salle --</option>';

            // ✅ On boucle sur data.salles (ou le nom de la liste retournée par votre ASHH)
            const listeSalles = data.salles || data.Salles || [];

            listeSalles.forEach(s => {
                const opt = document.createElement('option');
                // ✅ CRUCIAL : On stocke l'ID (GUID) dans la value pour la clé étrangère
                opt.value = s.ID;
                // On affiche le NUMERO pour l'utilisateur
                opt.textContent = s.NUMERO;
                select.appendChild(opt);
            });
        }
    } catch (err) {
        console.error("Erreur lors du chargement des salles:", err);
    }
}
// ─────────────────────────────────────────────
// CHARGER LES UTILISATEURS (TITULAIRES)
// ─────────────────────────────────────────────
async function chargerUsers() {
    try {
        const response = await fetch(API.users);
        const data = await response.json();

        if (data.success) {
            const select = document.getElementById('ClasseUser');
            if (!select) return;

            select.innerHTML = '<option value="">-- Sélectionner un utilisateur --</option>';

            const listeUsers = data.users || data.Users || [];
            listeUsers.forEach(u => {
                const opt = document.createElement('option');
                // On stocke l'ID (int) dans la value pour la clé étrangère
                opt.value = u.ID;
                // On affiche le NOM pour l'utilisateur
                opt.textContent = u.NOM;
                select.appendChild(opt);
            });
        }
    } catch (err) {
        console.error("Erreur lors du chargement des utilisateurs:", err);
    }
}
// ─────────────────────────────────────────────
function hidePreloader() {
    var pre = document.getElementById('preloader');
    if (!pre) return;
    setTimeout(function () {
        pre.style.opacity = '0';
        setTimeout(function () {
            pre.style.display = 'none';
            forceHideSpinner();
        }, 400);
    }, 600);
}

// ─────────────────────────────────────────────
// SPINNER
// ─────────────────────────────────────────────
function forceHideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none';
    s.style.visibility = 'hidden';
    s.style.opacity = '0';
    s.setAttribute('aria-hidden', 'true');
}

function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.opacity = '1';
    s.style.visibility = 'visible';
    s.style.display = 'flex';
    s.removeAttribute('aria-hidden');
}

function hideSpinner() { forceHideSpinner(); }

// ─────────────────────────────────────────────
// AJAX — helper générique
// ─────────────────────────────────────────────
/**
 * Envoie une requête POST JSON vers un handler .ashx
 * @param {string} url
 * @param {object} payload  — sera sérialisé en JSON
 * @returns {Promise<object>}  — réponse JSON du serveur
 */
function ajax(url, payload) {
    return fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify(payload)
    })
        .then(function (r) {
            if (!r.ok) throw new Error('Erreur HTTP ' + r.status);
            return r.json();
        });
}

// ─────────────────────────────────────────────
// CHARGER LA LISTE DEPUIS SQL SERVER
// ─────────────────────────────────────────────
function chargerClasses() {
    showSpinner();
    fetch(API.liste)
        .then(function (r) {
            if (!r.ok) throw new Error('Erreur HTTP ' + r.status);
            return r.json();
        })
        .then(function (data) {
            if (!data.success) throw new Error(data.message || 'Erreur serveur');
            ClassesData = data.Classes || [];

            // Initialisation pour la pagination
            filteredClasses = [...ClassesData];
            currentPage = 1;

            renderClasseStats();
            renderClassesTable();
        })
        .catch(function (err) {
            afficherErreurGlobale('Impossible de charger les Classes : ' + err.message);
        })
        .finally(function () {
            hideSpinner();
        });
}

// ─────────────────────────────────────────────
// STATISTIQUES
// ─────────────────────────────────────────────
function renderClasseStats() {
    var container = document.getElementById('ClassesStatsContainer');
    if (!container) return;

    var total = ClassesData.length;
    var totalEffectif = 0;
    var niveauxVus = {};
    var actives = 0;

    for (var i = 0; i < ClassesData.length; i++) {
        var classe = ClassesData[i];

        // Calcul effectif
        totalEffectif += parseInt(classe.EFFECTIF, 10) || 0;

        // Calcul niveaux uniques
        if (classe.NIVEAU) {
            niveauxVus[classe.NIVEAU] = true;
        }

        // --- CORRECTION DU COMPTEUR ACTIVES ---
        // On normalise la valeur en minuscules pour comparer "True", "true" ou "Actif"
        var statutBrut = String(classe.STATUT || '').toLowerCase().trim();

        if (statutBrut === 'true' || statutBrut === '1' || statutBrut === 'actif') {
            actives++;
        }
    }

    var niveaux = Object.keys(niveauxVus).length;

    var stats = [
        { label: 'Classes', value: total, icon: 'fas fa-folder', color: '#007bff' },
        { label: 'Effectif total', value: totalEffectif, icon: 'fas fa-users', color: '#28a745' },
        { label: 'Niveaux couverts', value: niveaux, icon: 'fas fa-layer-group', color: '#ffc107' },
        { label: 'Classes actives', value: actives, icon: 'fas fa-check-circle', color: '#17a2b8' }
    ];

    container.innerHTML = stats.map(function (s) {
        return '<div class="absence-stat-card" style="border-left:4px solid ' + s.color + ';">' +
            '  <div class="stat-icon" style="color:' + s.color + ';"><i class="' + s.icon + '"></i></div>' +
            '  <div class="stat-info">' +
            '    <span class="stat-value">' + s.value + '</span>' +
            '    <span class="stat-label">' + escHtml(s.label) + '</span>' +
            '  </div>' +
            '</div>';
    }).join('');
}

// ============================================================================
// RENDU DU TABLEAU
// ============================================================================
function renderClassesTable() {
    const tbody = document.getElementById('ClassesTableBody');
    if (!tbody) return;

    const startIndex = (currentPage - 1) * rowsPerPage;
    const endIndex = startIndex + rowsPerPage;
    const pageClasses = filteredClasses.slice(startIndex, endIndex);
    const totalPages = Math.ceil(filteredClasses.length / rowsPerPage);

    tbody.innerHTML = '';

    if (!pageClasses.length) {
        tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding: 60px;"><i class="fas fa-search" style="font-size: 48px; color: #ccc; margin-bottom: 15px; display: block;"></i>Aucune classe trouvée</td></tr>';
        if (typeof updateCounter === "function") updateCounter();
        return;
    }

    pageClasses.forEach(classe => {
        const row = tbody.insertRow();

        // 0. ID (Badge gris, Centré)
        const cellId = row.insertCell(0);
        cellId.style.textAlign = 'center';
        cellId.style.verticalAlign = 'middle';
        cellId.innerHTML = `
            <span style="display: inline-block; background-color: #f0f0f0; color: #333; padding: 3px 12px; border-radius: 15px; font-size: 11px; font-weight: 600; border: 1px solid #ddd;">
                ${classe.ID || '-'}
            </span>`;

        // 1. Nom de la classe (Badge transparent, Centré)
        const cellNom = row.insertCell(1);
        cellNom.style.textAlign = 'center';
        cellNom.style.verticalAlign = 'middle';
        cellNom.innerHTML = `
            <span style="display: inline-block; min-width: 100px; padding: 3px 12px; border: 1px solid #e1f5fe; border-radius: 15px;">
                <strong>${escHtml(classe.NOM) || '-'}</strong>
            </span>`;
        cellNom.style.color = '#333333';

        // 2. Niveau (Badge bleu, Centré)
        const cellNiveau = row.insertCell(2);
        cellNiveau.style.textAlign = 'center';
        cellNiveau.style.verticalAlign = 'middle';
        cellNiveau.innerHTML = `
            <span style="background-color: #e1f5fe; color: #01579b; padding: 3px 12px; border-radius: 15px; font-size: 11px; font-weight: 600; display: inline-block; border: 1px solid #b3e5fc;">
                <i class="fas fa-layer-group mr-1"></i> ${escHtml(classe.NIVEAU) || '-'}
            </span>`;

        // 3. Effectif (Centré)
        const cellEffectif = row.insertCell(3);
        cellEffectif.style.textAlign = 'center';
        cellEffectif.style.verticalAlign = 'middle';
        cellEffectif.innerHTML = `<strong>${classe.EFFECTIF || '0'}</strong>`;

        // 4. Titulaire (Badge rouge, Centré)
        const cellTitulaire = row.insertCell(4);
        cellTitulaire.style.textAlign = 'center';
        cellTitulaire.style.verticalAlign = 'middle';
        cellTitulaire.innerHTML = `
            <span style="background-color: #fff1f2; color: rgb(243, 10, 10); padding: 3px 12px; border-radius: 15px; font-size: 11px; font-weight: 600; display: inline-block; border: 1px solid #eea3ad;">
                <i class="fas fa-user-tie mr-1"></i> ${escHtml(classe.TITULAIRE) || '-'}
            </span>`;

        // 5. Salle (Badge Vert, Centré)
        const cellSalle = row.insertCell(5);
        cellSalle.style.textAlign = 'center';
        cellSalle.style.verticalAlign = 'middle';
        cellSalle.innerHTML = ` 
            <span style="background-color: #e8f5e9; color: rgb(1, 155, 52); padding: 3px 12px; border-radius: 15px; font-size: 11px; font-weight: 600; display: inline-block; border: 1px solid rgb(179, 252, 207);">
                <i class="fas fa-door-open mr-1"></i> ${escHtml(classe.SALLE) || '-'}
            </span>`;

        // 6. Statut (Badge, Centré)
        const cellStatut = row.insertCell(6);
        cellStatut.style.textAlign = 'center';
        cellStatut.style.verticalAlign = 'middle';
        const isActif = (
            classe.STATUT === true ||
            classe.STATUT === 1 ||
            classe.STATUT === '1' ||
            classe.STATUT === 'True' ||
            classe.STATUT === 'Actif'
        );
        cellStatut.innerHTML = isActif
            ? '<span style="background: #28a745; padding: 4px 10px; border-radius: 20px; color: white; font-size: 11px; font-weight: 600; display: inline-block; min-width: 80px;">✓ Actif</span>'
            : '<span style="background: #dc3545; padding: 4px 10px; border-radius: 20px; color: white; font-size: 11px; font-weight: 600; display: inline-block; min-width: 80px;">✗ Inactif</span>';

        // 7. Actions (Centré)
        const cellActions = row.insertCell(7);
        cellActions.style.textAlign = 'center';
        cellActions.style.verticalAlign = 'middle';
        cellActions.style.whiteSpace = 'nowrap';
        cellActions.innerHTML = `
            <button type="button" class="btn btn-sm btn-primary" style="margin: 0 2px;" onclick="editClasse('${classe.ID}')" title="Modifier">
                <i class="fas fa-edit"></i>
            </button>
            <button type="button" class="btn btn-sm btn-danger" style="margin: 0 2px;" onclick="deleteClasse('${classe.ID}', '${escHtml(classe.NOM).replace(/'/g, "\\'")}')" title="Supprimer">
                <i class="fas fa-trash"></i>
            </button>
        `;
    });

    if (typeof createPaginationControls === "function") createPaginationControls(totalPages);
}

// ─────────────────────────────────────────────
// MODAL — OUVRIR / FERMER
// ─────────────────────────────────────────────
function openAddClasseModal() {
    editId = null;
    resetClasseForm();
    document.getElementById('classeModalTitle').innerHTML =
        '<i class="fas fa-book-medical"></i> Ajouter une Classe';
    showModal('addClasseModal');
}

function closeAddClasseModal() {
    hideModal('addClasseModal');
    resetClasseForm();
    editId = null;
}

function showModal(id) {
    var m = document.getElementById(id);
    if (m) { m.style.display = 'flex'; m.classList.add('open'); }
}

function hideModal(id) {
    var m = document.getElementById(id);
    if (m) { m.style.display = 'none'; m.classList.remove('open'); }
}

// ─────────────────────────────────────────────
// FORMULAIRE — RESET
// ─────────────────────────────────────────────
function resetClasseForm() {
    document.getElementById('ClasseNom').value = '';
    document.getElementById('ClasseUser').value = '';         // select utilisateur
    document.getElementById('ClasseSalle').value = '';
    document.getElementById('ClasseEffectif').value = '0';
    document.getElementById('ClasseNiveau').value = '';
    document.getElementById('ClasseStatut').value = 'Actif';
    clearFormErrors();
}

// ─────────────────────────────────────────────
// SAUVEGARDER (ajout ou modification)
// ─────────────────────────────────────────────
function saveClasse() {
    // 1. Validation visuelle du formulaire (champs vides, etc.)
    if (typeof validateClasseForm === "function" && !validateClasseForm()) return;

    const estUneModification = (typeof editId !== "undefined" && editId !== null);

    // Récupération des éléments pour vérification
    const elNom = document.getElementById('ClasseNom');
    const elNiveau = document.getElementById('ClasseNiveau'); // Le <select>
    const elUser = document.getElementById('ClasseUser');     // Le <select> utilisateurs
    const elSalle = document.getElementById('ClasseSalle');   // Le <select>
    const elEffectif = document.getElementById('ClasseEffectif');
    const elStatut = document.getElementById('ClasseStatut');

    // 2. Préparation du Payload avec validation des GUIDs
    // On vérifie si la valeur ressemble à un GUID ou n'est pas vide
    if (!elNiveau.value || elNiveau.value.length < 10) {
        Swal.fire('Attention', 'Veuillez sélectionner un niveau valide dans la liste.', 'warning');
        return;
    }

    if (!elUser.value || parseInt(elUser.value, 10) <= 0) {
        Swal.fire('Attention', 'Veuillez sélectionner un titulaire valide dans la liste.', 'warning');
        return;
    }

    var payload = {
        NOM: elNom.value.trim(),
        NIVEAU_ID: elNiveau.value,              // GUID niveau
        TITULAIRE_ID: parseInt(elUser.value, 10), // ID int de l'utilisateur
        SALLE_ID: elSalle.value,                // GUID salle
        EFFECTIF: parseInt(elEffectif.value, 10) || 0,
        STATUT: elStatut.value === 'Actif' ? '1' : '0'
    };

    var url = API.ajouter;

    if (estUneModification) {
        payload.ID = editId;
        url = API.modifier;
    }

    // 3. UI : Désactiver le bouton pour éviter les doubles clics
    var btnSave = document.querySelector('#addClasseModal .btn-primary');
    if (btnSave) {
        btnSave.disabled = true;
        btnSave.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Enregistrement...';
    }

    if (typeof showSpinner === "function") showSpinner();

    // 4. Appel AJAX
    ajax(url, payload)
        .then(function (data) {
            if (!data.success) throw new Error(data.message);

            // --- SUCCÈS ---
            if (typeof closeAddClasseModal === "function") closeAddClasseModal();

            var titreSucces = estUneModification ? 'Modification réussie !' : 'Ajout réussi !';
            var texteSucces = estUneModification ?
                'Les modifications de la classe ont été enregistrées.' :
                'La nouvelle classe a été créée avec succès.';

            Swal.fire({
                title: titreSucces,
                text: texteSucces,
                icon: 'success',
                timer: 2500,
                showConfirmButton: false
            });

            if (typeof chargerClasses === "function") chargerClasses();
        })
        .catch(function (err) {
            // Ici, l'erreur "Le niveau sélectionné est invalide" sera affichée proprement
            Swal.fire({
                icon: 'error',
                title: 'Erreur d\'enregistrement',
                text: err.message,
                confirmButtonColor: '#d63030'
            });
        })
        .finally(function () {
            if (typeof hideSpinner === "function") hideSpinner();
            // 5. UI : Réactiver le bouton
            if (btnSave) {
                btnSave.disabled = false;
                btnSave.innerHTML = '<i class="fas fa-save"></i> Enregistrer';
            }
        });
}

// ─────────────────────────────────────────────
// MODIFIER — ouvre le modal pré-rempli
// @param {number} id — ID SQL Server
// ─────────────────────────────────────────────
function editClasse(id) {
    var m = ClassesData.find(x => x.ID === id);
    if (!m) return;

    editId = id;
    document.getElementById('ClasseNom').value = m.NOM;
    // On utilise les GUIDs/IDs pour sélectionner la bonne option dans chaque liste déroulante
    document.getElementById('ClasseNiveau').value = m.NIVEAU_ID;
    document.getElementById('ClasseUser').value = m.TITULAIRE_ID;
    document.getElementById('ClasseSalle').value = m.SALLE_ID;
    document.getElementById('ClasseEffectif').value = m.EFFECTIF;

    // --- CORRECTION DU STATUT POUR LE MODAL ---
    // On normalise la valeur SQL (True/1/Actif) pour qu'elle corresponde aux options du Select
    var statutBrut = String(m.STATUT || '').toLowerCase().trim();
    var valeurSelect = (statutBrut === 'true' || statutBrut === '1' || statutBrut === 'actif')
        ? 'Actif'
        : 'Inactif';

    document.getElementById('ClasseStatut').value = valeurSelect;

    // Mise à jour du titre du modal
    var titleElement = document.getElementById('classeModalTitle');
    if (titleElement) {
        titleElement.innerHTML = '<i class="fas fa-edit"></i> Modifier la classe';
    }

    showModal('addClasseModal');
}

// ─────────────────────────────────────────────
// SUPPRIMER
// @param {number} id  — ID SQL Server
// @param {string} nom — pour le message de confirmation
// ─────────────────────────────────────────────
function deleteClasse(id, nom) {
    // Utilisation de SweetAlert2 au lieu du confirm() natif
    Swal.fire({
        title: 'Confirmation',
        text: "Supprimer la Classe « " + nom + " » ? Cette action est irréversible.",
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler',
        // Empêche l'affichage derrière la modal en ciblant le body ou la modal elle-même
        target: document.body
    }).then((result) => {
        if (result.isConfirmed) {
            showSpinner();

            ajax(API.supprimer, { ID: id })
                .then(function (data) {
                    if (!data.success) throw new Error(data.message || 'Erreur serveur');

                    // Alerte de succès
                    Swal.fire({
                        title: 'Supprimé !',
                        text: 'La Classe a été supprimée avec succès.',
                        icon: 'success',
                        timer: 3000,
                        showConfirmButton: false
                    });

                    chargerClasses(); // recharge la liste 
                })
                .catch(function (err) {
                    // Utilisation de SweetAlert pour l'erreur au lieu du bandeau global
                    Swal.fire({
                        title: 'Erreur',
                        text: 'Erreur lors de la suppression : ' + err.message,
                        icon: 'error'
                    });
                    hideSpinner();
                });
        }
    });
}

// ─────────────────────────────────────────────
// EXPORT CSV
// ─────────────────────────────────────────────
function exportClasses() {
    if (ClassesData.length === 0) {
        alert('Aucune donnée à exporter.');
        return;
    }

    showSpinner();

    setTimeout(function () {
        try {
            var header = ['ID', 'Classe', 'Niveau', 'Effectif', 'Titulaire', 'Salle', 'Statut'];
            var rows = ClassesData.map(function (m) {
                return [m.ID, m.NOM, m.NIVEAU, m.EFFECTIF, m.TITULAIRE, m.SALLE, m.STATUT]
                    .map(function (v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; })
                    .join(',');
            });

            var csv = [header.join(',')].concat(rows).join('\r\n');
            var blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = 'Classes_export_' + dateDuJour() + '.csv';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        } catch (err) {
            alert('Erreur export : ' + err.message);
        } finally {
            hideSpinner();
        }
    }, 400);
}

// ─────────────────────────────────────────────
// VALIDATION FORMULAIRE
// ─────────────────────────────────────────────
function validateClasseForm() {
    clearFormErrors();
    var ok = true;

    var nom = document.getElementById('ClasseNom').value.trim();
    if (!nom) {
        showFieldError('ClasseNom', 'Le nom est obligatoire.');
        ok = false;
    }

    var userElement = document.getElementById('ClasseUser');
    if (userElement && !userElement.value) {
        showFieldError('ClasseUser', 'Le titulaire est obligatoire.');
        ok = false;
    }

    // CORRIGÉ : La variable 'salle' doit lire la valeur de l'élément ClasseSalle
    var salleElement = document.getElementById('ClasseSalle');
    if (salleElement && !salleElement.value.trim()) {
        showFieldError('ClasseSalle', 'La salle est obligatoire.');
        ok = false;
    }

    var effectif = parseInt(document.getElementById('ClasseEffectif').value, 10);
    if (isNaN(effectif) || effectif < 0) {
        showFieldError('ClasseEffectif', 'Effectif invalide.');
        ok = false;
    }

    return ok;
}

function showFieldError(fieldId, msg) {
    var field = document.getElementById(fieldId);
    if (!field) return;
    field.classList.add('is-invalid');
    var err = document.createElement('div');
    err.className = 'field-error';
    err.textContent = msg;
    field.parentNode.appendChild(err);
}

function clearFormErrors() {
    var invalids = document.querySelectorAll('#addClasseModal .is-invalid');
    for (var i = 0; i < invalids.length; i++) invalids[i].classList.remove('is-invalid');
    var errors = document.querySelectorAll('#addClasseModal .field-error');
    for (var j = 0; j < errors.length; j++) errors[j].parentNode.removeChild(errors[j]);
}

// ─────────────────────────────────────────────
// MESSAGE D'ERREUR GLOBAL (bandeau en haut du contenu)
// ─────────────────────────────────────────────
function afficherErreurGlobale(msg) {
    var existing = document.getElementById('alertErreurGlobal');
    if (existing) existing.parentNode.removeChild(existing);

    var div = document.createElement('div');
    div.id = 'alertErreurGlobal';
    div.className = 'alert-erreur';
    div.innerHTML = '<i class="fas fa-exclamation-triangle"></i> ' + escHtml(msg) +
        '<button onclick="this.parentNode.remove()" style="float:right;background:none;border:none;' +
        'cursor:pointer;font-size:16px;color:inherit;">&times;</button>';

    var section = document.getElementById('section-Classes');
    if (section) section.insertBefore(div, section.firstChild);
}

// ─────────────────────────────────────────────
// CONTRÔLES UI
// ─────────────────────────────────────────────
function initUIControls() {
    // Sidebar toggle
    var menuToggle = document.getElementById('menuToggle');
    var sidebar = document.getElementById('sidebar');
    var wrapper = document.getElementById('contentWrapper');
    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', function () {
            sidebar.classList.toggle('sidebar-collapsed');
            if (wrapper) wrapper.classList.toggle('sidebar-collapsed');
        });
    }

    // Notifications
    var notifToggle = document.getElementById('notifToggle');
    var notifDropdown = document.getElementById('notifDropdown');
    if (notifToggle && notifDropdown) {
        notifToggle.addEventListener('click', function (e) {
            e.stopPropagation();
            var isOpen = notifDropdown.classList.toggle('show');
            notifToggle.setAttribute('aria-expanded', String(isOpen));
        });
    }
    document.addEventListener('click', function (e) {
        if (!notifDropdown || !notifToggle) return;
        if (!notifDropdown.contains(e.target) && !notifToggle.contains(e.target)) {
            notifDropdown.classList.remove('show');
            notifToggle.setAttribute('aria-expanded', 'false');
        }
    });

    // Plein écran
    var fsToggle = document.getElementById('fullscreenToggle');
    if (fsToggle) {
        fsToggle.addEventListener('click', function () {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen &&
                    document.documentElement.requestFullscreen().catch(function () { });
            } else {
                document.exitFullscreen && document.exitFullscreen().catch(function () { });
            }
        });
    }

    // Fermer modal avec Échap
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') closeAddClasseModal();
    });

}

// ─────────────────────────────────────────────
// UTILITAIRES
// ─────────────────────────────────────────────
function escHtml(str) {
    return String(str == null ? '' : str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function dateDuJour() {
    var d = new Date();
    return d.getFullYear() + '-' +
        String(d.getMonth() + 1).padStart(2, '0') + '-' +
        String(d.getDate()).padStart(2, '0');
}