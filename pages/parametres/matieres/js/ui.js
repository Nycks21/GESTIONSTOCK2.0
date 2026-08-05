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

// --- Gestion du formulaire Matière ---
function resetMatiereForm() {
    document.getElementById('matiereEditId').value = '';
    setVal('matiereNom', '');
    setVal('matiereEnseignant', '');
    setVal('matiereCoeff', '1');
    setVal('matiereHeures', '3');
    setVal('matiereClasse', '');
    clearFormErrors();
}

function clearFormErrors() {
    document.querySelectorAll('.field-error').forEach(function(el) { el.remove(); });
    document.querySelectorAll('.form-control').forEach(function(el) {
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

function validateMatiereForm() {
    clearFormErrors();
    var valid = true;

    var nom = getVal('matiereNom');
    if (!nom) {
        showFieldError('matiereNom', 'Le nom est obligatoire.');
        valid = false;
    } else if (nom.length > 100) {
        showFieldError('matiereNom', 'Maximum 100 caractères.');
        valid = false;
    }

    var enseignant = getVal('matiereEnseignant');
    if (!enseignant) {
        showFieldError('matiereEnseignant', 'L\'enseignant est obligatoire.');
        valid = false;
    }

    var coeff = parseFloat(getVal('matiereCoeff'));
    if (isNaN(coeff) || coeff < 0.5 || coeff > 10) {
        showFieldError('matiereCoeff', 'Coefficient entre 0.5 et 10.');
        valid = false;
    }

    var heures = parseInt(getVal('matiereHeures'), 10);
    if (isNaN(heures) || heures < 1 || heures > 40) {
        showFieldError('matiereHeures', 'Heures entre 1 et 40.');
        valid = false;
    }

    var classe = getVal('matiereClasse');
    if (!classe) {
        showFieldError('matiereClasse', 'La classe est obligatoire.');
        valid = false;
    }

    return valid;
}

// --- Ouverture modale Ajout / Modification ---
function openAddMatiereModal() {
    STATE.editId = null;
    STATE.isEditMode = false;
    resetMatiereForm();
    document.getElementById('matiereModalTitle').innerHTML = '<i class="fas fa-book-medical"></i> Ajouter une matière';
    showModal('addMatiereModal');
}

function openEditMatiereModal(id) {
    var matiere = STATE.matieresData.find(function(m) { return String(m.ID) === String(id); });
    if (!matiere) {
        showErrorToast('Matière introuvable.', 'ID: ' + id);
        return;
    }

    STATE.editId = id;
    STATE.isEditMode = true;

    document.getElementById('matiereEditId').value = id;
    setVal('matiereNom', matiere.NOM);
    setVal('matiereEnseignant', matiere.ENSEIGNANT_ID);
    setVal('matiereCoeff', matiere.COEFFICIENT);
    setVal('matiereHeures', matiere.HEURES_SEMAINE);
    setVal('matiereClasse', matiere.CLASSE_ID);

    document.getElementById('matiereModalTitle').innerHTML = '<i class="fas fa-edit"></i> Modifier : ' + escapeHtml(matiere.NOM);
    showModal('addMatiereModal');
}

function closeAddMatiereModal() {
    hideModal('addMatiereModal');
    resetMatiereForm();
    STATE.editId = null;
    STATE.isEditMode = false;
}

// --- Statistiques ---
function renderStats() {
    var container = document.getElementById('matieresStatsContainer');
    if (!container) return;

    var total = STATE.matieresData.length;
    var totalCoeff = 0;
    var totalH = 0;
    var classesVues = {};

    STATE.matieresData.forEach(function(m) {
        totalCoeff += parseFloat(m.COEFFICIENT) || 0;
        totalH += parseInt(m.HEURES_SEMAINE, 10) || 0;
        if (m.CLASSE_NOM) classesVues[m.CLASSE_NOM] = true;
    });

    var stats = [
        { label: 'Matières', value: total, icon: 'fas fa-book', color: '#007bff' },
        { label: 'Coeff. total', value: totalCoeff.toFixed(1), icon: 'fas fa-balance-scale', color: '#28a745' },
        { label: 'Heures / sem.', value: totalH + 'h', icon: 'fas fa-clock', color: '#ffc107' },
        { label: 'Classes couvertes', value: Object.keys(classesVues).length, icon: 'fas fa-folder', color: '#17a2b8' }
    ];

    container.innerHTML = stats.map(function(s) {
        return '<div class="absence-stat-card" style="border-left:4px solid ' + s.color + ';">' +
            '<div class="stat-icon" style="color:' + s.color + ';"><i class="' + s.icon + '"></i></div>' +
            '<div class="stat-info"><span class="stat-value">' + s.value + '</span><span class="stat-label">' + escapeHtml(s.label) + '</span></div>' +
            '</div>';
    }).join('');
}

// --- Tableau ---
function renderTable() {
    var tbody = document.getElementById('matieresTableBody');
    if (!tbody) return;

    var start = (STATE.currentPage - 1) * STATE.rowsPerPage;
    var pageData = STATE.filteredMatieres.slice(start, start + STATE.rowsPerPage);
    var totalPages = Math.ceil(STATE.filteredMatieres.length / STATE.rowsPerPage);

    if (!pageData.length) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;padding:50px;">' +
            '<i class="fas fa-search" style="font-size:40px;color:#ccc;display:block;margin-bottom:12px;"></i>' +
            'Aucune matière trouvée</td></tr>';
        return;
    }

    tbody.innerHTML = '';
    pageData.forEach(function(m) {
        var row = tbody.insertRow();
        row.innerHTML =
            '<td style="text-align:center;vertical-align:middle;">' +
            '<span style="display:inline-block;min-width:120px;padding:3px 8px;border:1px solid #f0f0f0;border-radius:8px;"><strong>' + escapeHtml(m.NOM) + '</strong></span>' +
            '</td>' +
            '<td style="text-align:center;vertical-align:middle;">' +
            '<span style="background-color:#fce4ec;color:#d32f2f;padding:3px 12px;border-radius:15px;font-size:11px;font-weight:600;display:inline-block;border:1px solid #ffcdd2;min-width:130px;">' +
            '<i class="fas fa-user-tie mr-1"></i> ' + escapeHtml(m.ENSEIGNANT || '—') + '</span>' +
            '</td>' +
            '<td style="text-align:center;vertical-align:middle;">' +
            '<span style="background-color:#e1f5fe;color:#01579b;padding:3px 12px;border-radius:15px;font-size:11px;font-weight:600;display:inline-block;border:1px solid #b3e5fc;min-width:90px;">' +
            '<i class="fas fa-folder mr-1"></i> ' + escapeHtml(m.CLASSE_NOM || '—') + '</span>' +
            '</td>' +
            '<td style="text-align:center;vertical-align:middle;">' +
            '<span style="background-color:#f8f9fa;color:#333;padding:4px 8px;border-radius:50%;font-weight:700;border:1px solid #ddd;font-size:11px;">' + parseFloat(m.COEFFICIENT).toFixed(1) + '</span>' +
            '</td>' +
            '<td style="text-align:center;vertical-align:middle;font-weight:600;">' + (m.HEURES_SEMAINE || 0) + 'h</td>' +
            '<td style="text-align:center;vertical-align:middle;color:#888;font-size:12px;">' + (m.CREATED_AT ? new Date(m.CREATED_AT).toLocaleDateString('fr-FR') : '—') + '</td>' +
            '<td style="text-align:center;vertical-align:middle;white-space:nowrap;">' +
            '<button type="button" class="btn btn-sm btn-primary" style="margin:0 2px;" onclick="openEditMatiereModal(\'' + m.ID + '\')"><i class="fas fa-edit"></i></button>' +
            '<button type="button" class="btn btn-sm btn-danger" style="margin:0 2px;" onclick="deleteMatiere(\'' + m.ID + '\', \'' + escapeHtml(m.NOM) + '\')"><i class="fas fa-trash"></i></button>' +
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

function goToPage(page) {
    var total = Math.ceil(STATE.filteredMatieres.length / STATE.rowsPerPage);
    if (page < 1 || page > total) return;
    STATE.currentPage = page;
    renderTable();
}

// --- Initialisation des contrôles UI ---
function initUIControls() {
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            closeAddMatiereModal();
        }
    });

    var form = document.getElementById('form1');
    if (form) {
        form.addEventListener('submit', function (e) { e.preventDefault(); });
    }

    document.querySelectorAll('button').forEach(function (btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });
}

// --- Expositions globales ---
window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.showModal = showModal;
window.hideModal = hideModal;
window.openAddMatiereModal = openAddMatiereModal;
window.openEditMatiereModal = openEditMatiereModal;
window.closeAddMatiereModal = closeAddMatiereModal;
window.validateMatiereForm = validateMatiereForm;
window.resetMatiereForm = resetMatiereForm;
window.renderStats = renderStats;
window.renderTable = renderTable;
window.renderPagination = renderPagination;
window.goToPage = goToPage;
window.initUIControls = initUIControls;