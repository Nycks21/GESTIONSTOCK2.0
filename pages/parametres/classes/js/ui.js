'use strict';

// --- Spinner ---
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
    s.style.display = 'flex';
    s.style.visibility = 'visible';
    s.style.opacity = '1';
    s.removeAttribute('aria-hidden');
}

function hideSpinner() {
    forceHideSpinner();
}

// --- Modales ---
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

// --- Gestion du formulaire Classe ---
function resetClasseForm() {
    document.getElementById('classeEditId').value = '';
    setVal('ClasseNom', '');
    setVal('ClasseNiveau', '');
    setVal('ClasseUser', '');
    setVal('ClasseSalle', '');
    setVal('ClasseEffectif', '0');
    setVal('ClasseStatut', 'Actif');
    clearFormErrors();
}

function clearFormErrors() {
    document.querySelectorAll('.field-error').forEach(function (el) { el.remove(); });
    document.querySelectorAll('.form-control').forEach(function (el) {
        el.style.borderColor = '';
    });
}

function showFieldError(fieldId, msg) {
    var el = document.getElementById(fieldId);
    if (!el) return;
    el.style.borderColor = '#dc3545';
    var err = document.createElement('div');
    err.className = 'field-error';
    err.style.cssText = 'color:#dc3545;font-size:12px;margin-top:4px;';
    err.textContent = msg;
    el.parentNode.appendChild(err);
}

function validateClasseForm() {
    clearFormErrors();
    var valid = true;

    var nom = getVal('ClasseNom');
    if (!nom) {
        showFieldError('ClasseNom', 'Le nom est obligatoire.');
        valid = false;
    }

    var niveau = getVal('ClasseNiveau');
    if (!niveau) {
        showFieldError('ClasseNiveau', 'Veuillez sélectionner un niveau.');
        valid = false;
    }

    var user = getVal('ClasseUser');
    if (!user) {
        showFieldError('ClasseUser', 'Veuillez sélectionner un titulaire.');
        valid = false;
    }

    var salle = getVal('ClasseSalle');
    if (!salle) {
        showFieldError('ClasseSalle', 'Veuillez sélectionner une salle.');
        valid = false;
    }

    return valid;
}

// --- Ouverture modale Ajout / Modification ---
function openAddClasseModal() {
    STATE.editId = null;
    STATE.isEditMode = false;
    resetClasseForm();
    document.getElementById('classeModalTitle').innerHTML = '<i class="fas fa-book-medical"></i> Ajouter une classe';
    showModal('addClasseModal');
}

function openEditClasseModal(id) {
    var classe = STATE.classesData.find(function (c) { return String(c.ID) === String(id); });
    if (!classe) {
        showErrorToast('Classe introuvable.', 'ID: ' + id);
        return;
    }

    STATE.editId = id;
    STATE.isEditMode = true;

    document.getElementById('classeEditId').value = id;
    setVal('ClasseNom', classe.NOM);
    setVal('ClasseNiveau', classe.NIVEAU_ID);
    setVal('ClasseUser', classe.TITULAIRE_ID);
    setVal('ClasseSalle', classe.SALLE_ID);
    setVal('ClasseEffectif', classe.EFFECTIF);
    setVal('ClasseStatut', classe.STATUT ? 'Actif' : 'Inactif');

    document.getElementById('classeModalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier la classe';
    showModal('addClasseModal');
}

function closeAddClasseModal() {
    hideModal('addClasseModal');
    resetClasseForm();
    STATE.editId = null;
    STATE.isEditMode = false;
}

// --- Initialisation des contrôles UI ---
function initUIControls() {
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            closeAddClasseModal();
        }
    });

    // Empêcher la soumission du formulaire
    var form = document.getElementById('form1');
    if (form) {
        form.addEventListener('submit', function (e) { e.preventDefault(); });
    }

    // S'assurer que tous les boutons ont type="button"
    document.querySelectorAll('button').forEach(function (btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });
}

// --- Statistiques ---
function renderStats() {
    var container = document.getElementById('ClassesStatsContainer');
    if (!container) return;

    var total = STATE.classesData.length;
    var totalEffectif = 0;
    var niveauxVus = {};
    var actives = 0;

    STATE.classesData.forEach(function (c) {
        totalEffectif += parseInt(c.EFFECTIF, 10) || 0;
        if (c.NIVEAU) niveauxVus[c.NIVEAU] = true;
        var s = String(c.STATUT || '').toLowerCase().trim();
        if (s === 'true' || s === '1' || s === 'actif') actives++;
    });

    var niveaux = Object.keys(niveauxVus).length;

    var stats = [
        { label: 'Classes', value: total, icon: 'fas fa-folder', color: '#007bff' },
        { label: 'Effectif total', value: totalEffectif, icon: 'fas fa-users', color: '#28a745' },
        { label: 'Niveaux couverts', value: niveaux, icon: 'fas fa-layer-group', color: '#ffc107' },
        { label: 'Classes actives', value: actives, icon: 'fas fa-check-circle', color: '#17a2b8' }
    ];

    container.innerHTML = stats.map(function (s) {
        return '<div class="absence-stat-card" style="border-left:4px solid ' + s.color + ';">' +
            '<div class="stat-icon" style="color:' + s.color + ';"><i class="' + s.icon + '"></i></div>' +
            '<div class="stat-info"><span class="stat-value">' + s.value + '</span><span class="stat-label">' + escapeHtml(s.label) + '</span></div>' +
            '</div>';
    }).join('');
}

// --- Tableau ---
function renderTable() {
    var tbody = document.getElementById('ClassesTableBody');
    if (!tbody) return;

    var start = (STATE.currentPage - 1) * STATE.rowsPerPage;
    var pageData = STATE.filteredClasses.slice(start, start + STATE.rowsPerPage);
    var totalPages = Math.ceil(STATE.filteredClasses.length / STATE.rowsPerPage);

    if (!pageData.length) {
        tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:50px;">' +
            '<i class="fas fa-search" style="font-size:40px;color:#ccc;display:block;margin-bottom:12px;"></i>' +
            'Aucune classe trouvée</td></tr>';
        return;
    }

    tbody.innerHTML = '';
    pageData.forEach(function (classe) {
        var row = tbody.insertRow();
        row.innerHTML =
            '<td>' + escapeHtml(classe.ID) + '</td>' +
            '<td><strong>' + escapeHtml(classe.NOM) + '</strong></td>' +
            '<td>' + escapeHtml(classe.NIVEAU || '-') + '</td>' +
            '<td>' + (classe.EFFECTIF || 0) + '</td>' +
            '<td>' + escapeHtml(classe.TITULAIRE || '-') + '</td>' +
            '<td>' + escapeHtml(classe.SALLE || '-') + '</td>' +
            '<td>' + (classe.STATUT ? '<span class="badge badge-success">Actif</span>' : '<span class="badge badge-danger">Inactif</span>') + '</td>' +
            '<td>' +
            '<button type="button" class="btn btn-sm btn-primary" style="margin:0 2px;" onclick="openEditClasseModal(\'' + classe.ID + '\')"><i class="fas fa-edit"></i></button>' +
            '<button type="button" class="btn btn-sm btn-danger" style="margin:0 2px;" onclick="deleteClasse(\'' + classe.ID + '\', \'' + escapeHtml(classe.NOM) + '\')"><i class="fas fa-trash"></i></button>' +
            '</td>';
    });

    renderPagination(totalPages);
}

// --- Pagination ---
function renderPagination(totalPages) {
    var container = document.getElementById('pagination-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'pagination-container';
        container.style.cssText = 'margin:20px 0;display:flex;justify-content:center;gap:5px;flex-wrap:wrap;';
        var parent = document.querySelector('.dash-card-body');
        if (parent) parent.appendChild(container);
    }

    if (totalPages <= 1) {
        container.innerHTML = '';
        return;
    }

    var html = '';
    var current = STATE.currentPage;

    // Bouton précédent
    html += '<button class="btn btn-sm ' + (current === 1 ? 'btn-secondary disabled' : 'btn-outline-primary') + '" onclick="goToPage(' + (current - 1) + ')" ' + (current === 1 ? 'disabled' : '') + '>&laquo;</button>';

    // Numéros de page
    for (var i = 1; i <= totalPages; i++) {
        html += '<button class="btn btn-sm ' + (i === current ? 'btn-primary' : 'btn-outline-secondary') + '" onclick="goToPage(' + i + ')">' + i + '</button>';
    }

    // Bouton suivant
    html += '<button class="btn btn-sm ' + (current === totalPages ? 'btn-secondary disabled' : 'btn-outline-primary') + '" onclick="goToPage(' + (current + 1) + ')" ' + (current === totalPages ? 'disabled' : '') + '>&raquo;</button>';

    container.innerHTML = html;
}

// --- Aller à une page ---
function goToPage(page) {
    var total = Math.ceil(STATE.filteredClasses.length / STATE.rowsPerPage);
    if (page < 1 || page > total) return;
    STATE.currentPage = page;
    renderTable();
}

// --- Expositions globales ---
window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.showModal = showModal;
window.hideModal = hideModal;
window.openAddClasseModal = openAddClasseModal;
window.openEditClasseModal = openEditClasseModal;
window.closeAddClasseModal = closeAddClasseModal;
window.validateClasseForm = validateClasseForm;
window.resetClasseForm = resetClasseForm;
window.initUIControls = initUIControls;
window.renderStats = renderStats;
window.renderTable = renderTable;
window.renderPagination = renderPagination;
window.goToPage = goToPage;