/**
 * matieres.js — Gestion Scolaire
 * Adapté à la table SQL Server : [dbo].[MATIERES]
 * Colonnes : ID (GUID), NOM, ENSEIGNANT (int FK→USERS.IDUSER),
 *            COEFFICIENT, HEURES_SEMAINE, CLASSE_ID (INT FK→CLASSES.ID), CREATED_AT
 * 
 * Modification : La matière dépend de la classe (pas du niveau)
 */

'use strict';

// ─────────────────────────────────────────────
// URLS DES HANDLERS
// ─────────────────────────────────────────────
var API_MATIERES = {
    liste: '/pages/parametres/matieres/handlers/GetMatieres.ashx',
    ajouter: '/pages/parametres/matieres/handlers/AjouterMatiere.ashx',
    modifier: '/pages/parametres/matieres/handlers/ModifierMatiere.ashx',
    supprimer: '/pages/parametres/matieres/handlers/SupprimerMatiere.ashx',
    classes: '/pages/parametres/classes/handlers/GetClasse.ashx',
    users: 'handlers/GetUsers.ashx'
};

// ─────────────────────────────────────────────
// ÉTAT LOCAL
// ─────────────────────────────────────────────
var matieresData = [];
var editId = null;
var currentPage = 1;
var rowsPerPage = 10;
var filteredMatieres = [];

// ============================================================
// FONCTIONS UTILITAIRES
// ============================================================

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

// ============================================================
// TOAST NOTIFICATIONS
// ============================================================

function showToast(message, type) {
    type = type || 'info';
    
    if (typeof Swal !== 'undefined') {
        var icon = type === 'error' ? 'error' : type === 'success' ? 'success' : type === 'warning' ? 'warning' : 'info';
        Swal.fire({ icon: icon, title: message, timer: 2000, showConfirmButton: false });
        return;
    }
    
    var container = document.getElementById('toastContainer');
    if (!container) {
        console.log(message);
        return;
    }
    
    var colors = {
        success: '#d4edda;color:#155724',
        error: '#f8d7da;color:#721c24',
        warning: '#fff3cd;color:#856404',
        info: '#d1ecf1;color:#0c5460'
    };
    
    var toast = document.createElement('div');
    toast.style.cssText = 'background:' + (colors[type] || colors.info).split(';')[0] + '; ' + (colors[type] || colors.info).split(';')[1] + '; padding:12px 18px; border-radius:6px; font-size:13px; font-weight:500; min-width:240px; box-shadow:0 4px 12px rgba(0,0,0,.15); opacity:0; transition:opacity .3s; margin-bottom:10px;';
    toast.textContent = message;
    container.appendChild(toast);
    
    setTimeout(function() { toast.style.opacity = '1'; }, 10);
    setTimeout(function() {
        toast.style.opacity = '0';
        setTimeout(function() { toast.remove(); }, 350);
    }, 4000);
}

// ============================================================
// SPINNER
// ============================================================

function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (s) {
        s.style.display = 'flex';
        s.style.visibility = 'visible';
        s.style.opacity = '1';
    }
}

function hideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (s) {
        s.style.display = 'none';
        s.style.visibility = 'hidden';
        s.style.opacity = '0';
    }
}

function forceHideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none';
    s.style.visibility = 'hidden';
    s.style.opacity = '0';
}

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

// ============================================================
// MODALES
// ============================================================

function showModal(id) {
    var m = document.getElementById(id);
    if (m) {
        m.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    }
}

function hideModal(id) {
    var m = document.getElementById(id);
    if (m) {
        m.style.display = 'none';
        document.body.style.overflow = '';
    }
}

function openAddMatiereModal() {
    editId = null;
    resetMatiereForm();
    var modalTitle = document.getElementById('matiereModalTitle');
    if (modalTitle) modalTitle.innerHTML = '<i class="fas fa-book-medical"></i> Ajouter une matière';
    showModal('addMatiereModal');
}

function closeAddMatiereModal() {
    hideModal('addMatiereModal');
    resetMatiereForm();
    editId = null;
}

// ============================================================
// FORMULAIRE
// ============================================================

function resetMatiereForm() {
    var nomInput = document.getElementById('matiereNom');
    var enseignantSelect = document.getElementById('matiereEnseignant');
    var coeffInput = document.getElementById('matiereCoeff');
    var heuresInput = document.getElementById('matiereHeures');
    var classeSelect = document.getElementById('matiereClasse');
    
    if (nomInput) nomInput.value = '';
    if (enseignantSelect) enseignantSelect.value = '';
    if (coeffInput) coeffInput.value = '1';
    if (heuresInput) heuresInput.value = '3';
    if (classeSelect) classeSelect.value = '';
    
    clearFormErrors();
}

function clearFormErrors() {
    var invalids = document.querySelectorAll('#addMatiereModal .is-invalid');
    for (var i = 0; i < invalids.length; i++) {
        invalids[i].classList.remove('is-invalid');
    }
    var errors = document.querySelectorAll('#addMatiereModal .field-error');
    for (var j = 0; j < errors.length; j++) {
        if (errors[j].parentNode) {
            errors[j].parentNode.removeChild(errors[j]);
        }
    }
}

function showFieldError(fieldId, msg) {
    var field = document.getElementById(fieldId);
    if (!field) return;
    field.classList.add('is-invalid');
    var err = document.createElement('div');
    err.className = 'field-error';
    err.textContent = msg;
    err.style.cssText = 'color:#dc3545; font-size:12px; margin-top:5px;';
    field.parentNode.appendChild(err);
}

function validateMatiereForm() {
    clearFormErrors();
    var ok = true;

    var nom = document.getElementById('matiereNom').value.trim();
    if (!nom) {
        showFieldError('matiereNom', 'Le nom est obligatoire.');
        ok = false;
    } else if (nom.length > 100) {
        showFieldError('matiereNom', 'Maximum 100 caractères.');
        ok = false;
    }

    var ensEl = document.getElementById('matiereEnseignant');
    if (!ensEl || !ensEl.value) {
        showFieldError('matiereEnseignant', "L'enseignant est obligatoire.");
        ok = false;
    }

    var coeff = parseFloat(document.getElementById('matiereCoeff').value);
    if (isNaN(coeff) || coeff < 0.5 || coeff > 10) {
        showFieldError('matiereCoeff', 'Coefficient entre 0.5 et 10.');
        ok = false;
    }

    var heures = parseInt(document.getElementById('matiereHeures').value, 10);
    if (isNaN(heures) || heures < 1 || heures > 40) {
        showFieldError('matiereHeures', 'Heures entre 1 et 40.');
        ok = false;
    }

    var classeEl = document.getElementById('matiereClasse');
    if (!classeEl || !classeEl.value) {
        showFieldError('matiereClasse', 'La classe est obligatoire.');
        ok = false;
    }

    return ok;
}

// ============================================================
// AJAX
// ============================================================

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

// ============================================================
// CHARGEMENT DES DONNÉES
// ============================================================

async function chargerClasses() {
    try {
        var response = await fetch(API_MATIERES.classes);
        var data = await response.json();

        if (data.success) {
            var select = document.getElementById('matiereClasse');
            if (!select) return;
            select.innerHTML = '<option value="">-- Sélectionner une classe --</option>';

            var classesList = data.Classes || data.data || [];
            for (var i = 0; i < classesList.length; i++) {
                var cls = classesList[i];
                var opt = document.createElement('option');
                opt.value = cls.ID || cls.id;
                opt.textContent = cls.NOM || cls.nom;
                select.appendChild(opt);
            }
            console.log('[CLASSES] Chargées:', classesList.length);
        }
    } catch (err) {
        console.error("Erreur lors du chargement des classes:", err);
    }
}

async function chargerUsers() {
    try {
        var response = await fetch(API_MATIERES.users);
        var data = await response.json();

        if (data.success) {
            var select = document.getElementById('matiereEnseignant');
            if (!select) return;
            select.innerHTML = '<option value="">-- Sélectionner un enseignant --</option>';

            var listeUsers = data.users || data.Users || [];
            for (var i = 0; i < listeUsers.length; i++) {
                var u = listeUsers[i];
                var opt = document.createElement('option');
                opt.value = u.ID || u.id;
                opt.textContent = u.NOM || u.nom;
                select.appendChild(opt);
            }
            console.log('[ENSEIGNANTS] Chargés:', listeUsers.length);
        }
    } catch (err) {
        console.error("Erreur lors du chargement des enseignants:", err);
    }
}

function chargerMatieres() {
    console.log('[MATIERES] Chargement en cours...');
    showSpinner();
    
    fetch(API_MATIERES.liste)
        .then(function (r) {
            if (!r.ok) throw new Error('Erreur HTTP ' + r.status);
            return r.json();
        })
        .then(function (data) {
            if (!data.success) throw new Error(data.message || 'Erreur serveur');
            matieresData = data.matieres || data.data || [];
            filteredMatieres = [...matieresData];
            currentPage = 1;
            console.log('[MATIERES] Chargées:', matieresData.length);
            renderMatiereStats();
            renderMatieresTable();
        })
        .catch(function (err) {
            console.error('Erreur chargerMatieres:', err);
            afficherErreurGlobale('Impossible de charger les matières : ' + err.message);
        })
        .finally(function () { hideSpinner(); });
}

// ============================================================
// STATISTIQUES
// ============================================================

function renderMatiereStats() {
    var container = document.getElementById('matieresStatsContainer');
    if (!container) return;

    var total = matieresData.length;
    var totalCoeff = 0;
    var totalH = 0;
    var classesVues = {};

    for (var i = 0; i < matieresData.length; i++) {
        totalCoeff += parseFloat(matieresData[i].COEFFICIENT) || 0;
        totalH += parseInt(matieresData[i].HEURES_SEMAINE, 10) || 0;
        if (matieresData[i].CLASSE_NOM) classesVues[matieresData[i].CLASSE_NOM] = true;
    }

    var stats = [
        { label: 'Matières', value: total, icon: 'fas fa-book', color: '#007bff' },
        { label: 'Coeff. total', value: totalCoeff.toFixed(1), icon: 'fas fa-balance-scale', color: '#28a745' },
        { label: 'Heures / sem.', value: totalH + 'h', icon: 'fas fa-clock', color: '#ffc107' },
        { label: 'Classes couvertes', value: Object.keys(classesVues).length, icon: 'fas fa-folder', color: '#17a2b8' }
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

// ============================================================
// TABLEAU
// ============================================================

function renderMatieresTable() {
    var tbody = document.getElementById('matieresTableBody');
    if (!tbody) return;

    var startIndex = (currentPage - 1) * rowsPerPage;
    var pageMatieres = filteredMatieres.slice(startIndex, startIndex + rowsPerPage);
    var totalPages = Math.ceil(filteredMatieres.length / rowsPerPage);

    tbody.innerHTML = '';

    if (!pageMatieres.length) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;color:#888;padding:40px;">' +
            '<i class="fas fa-search" style="font-size:40px;color:#ccc;display:block;margin-bottom:12px;"></i>' +
            'Aucune matière trouvée.您</td>' +
            '</tr>' +
            '<tr><td colspan="7" style="text-align:center;padding:10px;">' +
            '<button class="btn btn-primary" onclick="openAddMatiereModal()">' +
            '<i class="fas fa-plus"></i> Ajouter une matière</button>' +
            '</td>' +
            '</tr>';
        return;
    }

    for (var i = 0; i < pageMatieres.length; i++) {
        var m = pageMatieres[i];
        var date = m.CREATED_AT ? new Date(m.CREATED_AT).toLocaleDateString('fr-FR') : '—';
        var row = tbody.insertRow();

        // 0. Nom
        var cellNom = row.insertCell(0);
        cellNom.style.textAlign = 'center';
        cellNom.style.verticalAlign = 'middle';
        cellNom.innerHTML = '<span style="display: inline-block; min-width: 120px; padding: 3px 8px; border: 1px solid #f0f0f0; border-radius: 8px;"><strong>' + escHtml(m.NOM) + '</strong></span>';

        // 1. Enseignant
        var cellEnseignant = row.insertCell(1);
        cellEnseignant.style.textAlign = 'center';
        cellEnseignant.style.verticalAlign = 'middle';
        cellEnseignant.innerHTML = '<span style="background-color: #fce4ec; color: #d32f2f; padding: 3px 12px; border-radius: 15px; font-size: 11px; font-weight: 600; display: inline-block; border: 1px solid #ffcdd2; min-width: 130px;">' +
            '<i class="fas fa-user-tie mr-1"></i> ' + escHtml(m.ENSEIGNANT || '—') + '</span>';

        // 2. Classe
        var cellClasse = row.insertCell(2);
        cellClasse.style.textAlign = 'center';
        cellClasse.style.verticalAlign = 'middle';
        cellClasse.innerHTML = '<span style="background-color: #e1f5fe; color: #01579b; padding: 3px 12px; border-radius: 15px; font-size: 11px; font-weight: 600; display: inline-block; border: 1px solid #b3e5fc; min-width: 90px;">' +
            '<i class="fas fa-folder mr-1"></i> ' + escHtml(m.CLASSE_NOM || '—') + '</span>';

        // 3. Coefficient
        var cellCoeff = row.insertCell(3);
        cellCoeff.style.textAlign = 'center';
        cellCoeff.style.verticalAlign = 'middle';
        cellCoeff.innerHTML = '<span style="background-color: #f8f9fa; color: #333; padding: 4px 8px; border-radius: 50%; font-weight: 700; border: 1px solid #ddd; font-size: 11px;">' + parseFloat(m.COEFFICIENT).toFixed(1) + '</span>';

        // 4. Heures
        var cellHeures = row.insertCell(4);
        cellHeures.style.textAlign = 'center';
        cellHeures.style.verticalAlign = 'middle';
        cellHeures.style.fontWeight = '600';
        cellHeures.textContent = (m.HEURES_SEMAINE || 0) + 'h';

        // 5. Date
        var cellDate = row.insertCell(5);
        cellDate.style.textAlign = 'center';
        cellDate.style.verticalAlign = 'middle';
        cellDate.style.color = '#888';
        cellDate.style.fontSize = '12px';
        cellDate.textContent = date;

        // 6. Actions
        var cellActions = row.insertCell(6);
        cellActions.style.textAlign = 'center';
        cellActions.style.verticalAlign = 'middle';
        cellActions.style.whiteSpace = 'nowrap';
        cellActions.innerHTML = '<button type="button" class="btn btn-sm btn-primary" style="margin: 0 2px;" onclick="editMatiere(\'' + m.ID + '\')" title="Modifier"><i class="fas fa-edit"></i></button>' +
            '<button type="button" class="btn btn-sm btn-danger" style="margin: 0 2px;" onclick="deleteMatiere(\'' + m.ID + '\', \'' + escHtml(m.NOM).replace(/'/g, "\\'") + '\')" title="Supprimer"><i class="fas fa-trash"></i></button>';
    }

    createPaginationControls(totalPages);
}

function createPaginationControls(totalPages) {
    if (totalPages <= 1) return;
    
    var oldContainer = document.getElementById('matieres-pagination-container');
    if (oldContainer) oldContainer.remove();
    
    var container = document.createElement('div');
    container.id = 'matieres-pagination-container';
    container.style.cssText = 'display:flex;justify-content:center;align-items:center;gap:5px;margin-top:15px;flex-wrap:wrap;';
    
    container.appendChild(createPageButton('«', function() { goToPage(1); }, currentPage === 1));
    container.appendChild(createPageButton('‹', function() { if (currentPage > 1) goToPage(currentPage - 1); }, currentPage === 1));
    
    var startPage = Math.max(1, currentPage - 2);
    var endPage = Math.min(totalPages, startPage + 4);
    
    if (startPage > 1) {
        container.appendChild(createPageButton('1', function() { goToPage(1); }));
        if (startPage > 2) container.appendChild(createDots());
    }
    
    for (var i = startPage; i <= endPage; i++) {
        container.appendChild(createPageButton(i.toString(), (function(p) { 
            return function() { goToPage(p); }; 
        })(i), i === currentPage));
    }
    
    if (endPage < totalPages) {
        if (endPage < totalPages - 1) container.appendChild(createDots());
        container.appendChild(createPageButton(totalPages.toString(), function() { goToPage(totalPages); }));
    }
    
    container.appendChild(createPageButton('›', function() { if (currentPage < totalPages) goToPage(currentPage + 1); }, currentPage === totalPages));
    container.appendChild(createPageButton('»', function() { goToPage(totalPages); }, currentPage === totalPages));
    
    var tableContainer = document.querySelector('.dash-card-body');
    if (tableContainer) tableContainer.appendChild(container);
}

function createPageButton(text, onClick, isActive) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = text;
    var active = isActive === true;
    
    btn.style.cssText = 'padding:7px 13px;border:1px solid ' + (active ? '#007bff' : '#dee2e6') + ';' +
        'background:' + (active ? '#007bff' : 'white') + ';' +
        'color:' + (active ? 'white' : '#007bff') + ';' +
        'cursor:' + (active ? 'default' : 'pointer') + ';border-radius:6px;font-weight:500;min-width:38px;transition:all .15s;';
    
    if (onClick && !active) {
        btn.addEventListener('click', onClick);
        btn.addEventListener('mouseenter', function() {
            btn.style.background = '#007bff';
            btn.style.color = 'white';
        });
        btn.addEventListener('mouseleave', function() {
            btn.style.background = 'white';
            btn.style.color = '#007bff';
        });
    }
    
    if (active) {
        btn.disabled = true;
    }
    
    return btn;
}

function createDots() {
    var span = document.createElement('span');
    span.textContent = '…';
    span.style.cssText = 'padding:7px 4px;color:#6c757d;';
    return span;
}

function goToPage(page) {
    currentPage = page;
    renderMatieresTable();
}

// ============================================================
// CRUD OPÉRATIONS
// ============================================================

async function saveMatiere() {
    var nom = document.getElementById('matiereNom')?.value.trim();
    var enseignantId = document.getElementById('matiereEnseignant')?.value;
    var coefficient = document.getElementById('matiereCoeff')?.value;
    var heuresSemaine = document.getElementById('matiereHeures')?.value;
    var classeId = document.getElementById('matiereClasse')?.value;

    // Validations
    if (!nom) {
        showToast('Veuillez saisir le nom de la matière', 'warning');
        return;
    }
    if (!enseignantId) {
        showToast('Veuillez sélectionner un enseignant', 'warning');
        return;
    }
    if (!coefficient || coefficient <= 0) {
        showToast('Veuillez saisir un coefficient valide', 'warning');
        return;
    }
    if (!classeId) {
        showToast('Veuillez sélectionner une classe', 'warning');
        return;
    }

    showSpinner();

    try {
        var url = editId ? API_MATIERES.modifier : API_MATIERES.ajouter;
        var payload = {
            NOM: nom,
            ENSEIGNANT_ID: parseInt(enseignantId),
            COEFFICIENT: parseFloat(coefficient),
            HEURES_SEMAINE: parseInt(heuresSemaine) || 3,
            CLASSE_ID: parseInt(classeId)
        };
        
        if (editId) {
            payload.ID = editId;
        }

        console.log('[SAVE] Payload:', payload);

        var response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        var result = await response.json();
        
        if (response.ok && result.success) {
            showToast(editId ? 'Matière modifiée avec succès' : 'Matière ajoutée avec succès', 'success');
            closeAddMatiereModal();
            chargerMatieres();
        } else {
            showToast(result.message || 'Erreur lors de l\'opération', 'error');
        }
    } catch (error) {
        console.error('[SAVE] Error:', error);
        showToast('Erreur de connexion au serveur: ' + error.message, 'error');
    } finally {
        hideSpinner();
    }
}

function editMatiere(id) {
    var m = matieresData.find(function (x) { return x.ID === id; });
    if (!m) {
        showToast('Matière non trouvée', 'error');
        return;
    }

    editId = id;

    var nomInput = document.getElementById('matiereNom');
    var enseignantSelect = document.getElementById('matiereEnseignant');
    var coeffInput = document.getElementById('matiereCoeff');
    var heuresInput = document.getElementById('matiereHeures');
    var classeSelect = document.getElementById('matiereClasse');
    
    if (nomInput) nomInput.value = m.NOM;
    if (enseignantSelect) enseignantSelect.value = m.ENSEIGNANT_ID;
    if (coeffInput) coeffInput.value = m.COEFFICIENT;
    if (heuresInput) heuresInput.value = m.HEURES_SEMAINE;
    if (classeSelect) classeSelect.value = m.CLASSE_ID;

    var modalTitle = document.getElementById('matiereModalTitle');
    if (modalTitle) modalTitle.innerHTML = '<i class="fas fa-edit"></i> Modifier : ' + escHtml(m.NOM);

    showModal('addMatiereModal');
}

function deleteMatiere(id, nom) {
    if (typeof Swal === 'undefined') {
        if (confirm('Supprimer la matière "' + nom + '" ?')) {
            deleteMatiereConfirm(id);
        }
        return;
    }
    
    Swal.fire({
        title: 'Confirmation',
        text: 'Supprimer la matière « ' + nom + ' » ? Cette action est irréversible.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    }).then(function (result) {
        if (result.isConfirmed) {
            deleteMatiereConfirm(id);
        }
    });
}

async function deleteMatiereConfirm(id) {
    showSpinner();
    try {
        var response = await fetch(API_MATIERES.supprimer, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ID: id })
        });
        
        var data = await response.json();
        
        if (data.success) {
            if (typeof Swal !== 'undefined') {
                Swal.fire({ title: 'Supprimé !', text: 'La matière a été supprimée avec succès.', icon: 'success', timer: 2000, showConfirmButton: false });
            }
            chargerMatieres();
        } else {
            var errorMsg = data.message || 'Erreur lors de la suppression';
            if (typeof Swal !== 'undefined') {
                Swal.fire({ title: 'Erreur', text: errorMsg, icon: 'error' });
            } else {
                alert('Erreur: ' + errorMsg);
            }
        }
    } catch (err) {
        console.error('deleteMatiere error:', err);
        if (typeof Swal !== 'undefined') {
            Swal.fire({ title: 'Erreur', text: 'Erreur de connexion au serveur', icon: 'error' });
        } else {
            alert('Erreur de connexion au serveur');
        }
    } finally {
        hideSpinner();
    }
}

// ============================================================
// EXPORT
// ============================================================

function exportMatieres() {
    if (matieresData.length === 0) {
        showToast('Aucune donnée à exporter.', 'warning');
        return;
    }
    
    showSpinner();
    setTimeout(function () {
        try {
            var header = ['ID', 'Matière', 'Enseignant', 'Classe', 'Coefficient', 'Heures/sem.', 'Créé le'];
            var rows = matieresData.map(function (m) {
                var date = m.CREATED_AT ? new Date(m.CREATED_AT).toLocaleDateString('fr-FR') : '';
                return [m.ID, m.NOM, m.ENSEIGNANT, m.CLASSE_NOM, m.COEFFICIENT, m.HEURES_SEMAINE, date]
                    .map(function (v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; })
                    .join(',');
            });
            var csv = [header.join(',')].concat(rows).join('\r\n');
            var blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = 'matieres_export_' + dateDuJour() + '.csv';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            showToast('Export terminé', 'success');
        } catch (err) {
            console.error('Export error:', err);
            showToast('Erreur export : ' + err.message, 'error');
        } finally {
            hideSpinner();
        }
    }, 100);
}

// ============================================================
// ERREURS
// ============================================================

function afficherErreurGlobale(msg) {
    var existing = document.getElementById('alertErreurGlobal');
    if (existing) existing.parentNode.removeChild(existing);

    var div = document.createElement('div');
    div.id = 'alertErreurGlobal';
    div.className = 'alert-erreur';
    div.style.cssText = 'background:#f8d7da; color:#721c24; padding:12px 20px; border-radius:8px; margin-bottom:20px; border-left:4px solid #dc3545;';
    div.innerHTML = '<i class="fas fa-exclamation-triangle"></i> ' + escHtml(msg) +
        '<button onclick="this.parentNode.remove()" style="float:right;background:none;border:none;cursor:pointer;font-size:16px;color:inherit;">&times;</button>';

    var section = document.getElementById('section-matieres');
    if (section) section.insertBefore(div, section.firstChild);
}

// ============================================================
// INITIALISATION UI
// ============================================================

function initUIControls() {
    var menuToggle = document.getElementById('menuToggle');
    var sidebar = document.getElementById('sidebar');
    var wrapper = document.getElementById('contentWrapper');
    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', function () {
            sidebar.classList.toggle('collapsed');
            if (wrapper) wrapper.classList.toggle('expanded');
        });
    }

    var notifToggle = document.getElementById('notifToggle');
    var notifDropdown = document.getElementById('notifDropdown');
    if (notifToggle && notifDropdown) {
        notifToggle.addEventListener('click', function (e) {
            e.stopPropagation();
            notifDropdown.classList.toggle('show');
        });
        document.addEventListener('click', function (e) {
            if (notifDropdown && notifToggle && !notifDropdown.contains(e.target) && !notifToggle.contains(e.target)) {
                notifDropdown.classList.remove('show');
            }
        });
    }

    var fsToggle = document.getElementById('fullscreenToggle');
    if (fsToggle) {
        fsToggle.addEventListener('click', function () {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen();
            } else {
                document.exitFullscreen();
            }
        });
    }

    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') closeAddMatiereModal();
    });
}

// ============================================================
// INIT
// ============================================================

document.addEventListener('DOMContentLoaded', function () {
    console.log('[MATIERES] Initialisation...');
    forceHideSpinner();
    hidePreloader();
    initUIControls();
    chargerClasses();      // Charger les classes (remplace chargerNiveaux)
    chargerUsers();
    chargerMatieres();
});

// Exposer les fonctions globalement
window.openAddMatiereModal = openAddMatiereModal;
window.closeAddMatiereModal = closeAddMatiereModal;
window.saveMatiere = saveMatiere;
window.editMatiere = editMatiere;
window.deleteMatiere = deleteMatiere;
window.exportMatieres = exportMatieres;