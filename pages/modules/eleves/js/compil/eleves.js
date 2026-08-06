'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// URLS DES HANDLERS — chemins relatifs depuis la page eleves.aspx
// ─────────────────────────────────────────────────────────────────────────────
var API = {
    getEleves: 'handlers/GetEleve.ashx',
    getClasses: '../../parametres/classes/handlers/GetClasse.ashx',
    getAnnees: '../../administrations/annee/handlers/GetAnnee.ashx',
    ajouter: 'handlers/AjouterEleve.ashx',
    modifier: 'handlers/ModifierEleve.ashx',
    supprimer: 'handlers/SupprimerEleve.ashx'
};

// ─────────────────────────────────────────────────────────────────────────────
// ÉTAT GLOBAL
// ─────────────────────────────────────────────────────────────────────────────
var currentMode = null;     // "ajout" | "modification"
var currentEleveId = null;     // GUID string
var elevesData = [];       // toutes les données chargées
var baseFilteredData = [];       // périmètre validé par le filtre initial
var filteredEleves = [];       // données affichées (après filtre rapide)
var classesData = [];
var anneesData = [];
var currentPage = 1;
var rowsPerPage = 10;
var sortDirection = 1;        // 1 ASC, -1 DESC
var isInitialLoad = true;

// ─────────────────────────────────────────────────────────────────────────────
// INITIALISATION
// ─────────────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function () {
    forceHideSpinner();
    preventFormAutoSubmit();
    ensureButtonsHaveTypeButton();
    initUIControls();
    loadEleves();
});

// ─────────────────────────────────────────────────────────────────────────────
// SÉCURITÉ FORMULAIRE
// ─────────────────────────────────────────────────────────────────────────────
function preventFormAutoSubmit() {
    var form = document.getElementById('eleveForm');
    if (!form) return;
    form.setAttribute('novalidate', 'novalidate');
    form.addEventListener('submit', function (e) { e.preventDefault(); });
}

function ensureButtonsHaveTypeButton() {
    document.querySelectorAll('button').forEach(function (btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// SPINNER
// ─────────────────────────────────────────────────────────────────────────────
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

function hideSpinner() { forceHideSpinner(); }

// ─────────────────────────────────────────────────────────────────────────────
// CHARGEMENT DONNÉES
// ─────────────────────────────────────────────────────────────────────────────
async function loadEleves() {
    showSpinner();
    try {
        // Chargement en parallèle des trois sources
        const [dataEleves, dataClasses, dataAnnees] = await Promise.all([
            fetchJson(API.getEleves),
            fetchJson(API.getClasses),
            fetchJson(API.getAnnees)
        ]);

        // Classes
        if (dataClasses.success) {
            classesData = dataClasses.Classes || dataClasses.niveaux || [];
            peuplerSelectClasses();
        }

        // Années
        if (dataAnnees.success) {
            anneesData = dataAnnees.Annees || [];
            peuplerSelectAnnees();
        }

        // Élèves
        if (dataEleves.success) {
            elevesData = dataEleves.Eleves || [];
            if (isInitialLoad) {
                hideSpinner();
                showInitialFilterModal();
            } else {
                // Rechargement sans perdre les filtres
                var searchValue = document.getElementById('search-filter')?.value || '';
                var statusValue = document.getElementById('status-filter')?.value || '';
                
                baseFilteredData = [...elevesData];
                filteredEleves = baseFilteredData.filter(function (eleve) {
                    var matchSearch = !searchValue || (
                        eleve.NOM?.toLowerCase().includes(searchValue.toLowerCase()) ||
                        eleve.MATRICULE?.toLowerCase().includes(searchValue.toLowerCase()) ||
                        eleve.EMAIL?.toLowerCase().includes(searchValue.toLowerCase())
                    );
                    var matchStatus = !statusValue || (eleve.STATUT?.toLowerCase() === statusValue);
                    return matchSearch && matchStatus;
                });
                
                currentPage = 1;
                renderSimpleTable();
                updateCounter();
            }
        } else {
            Swal.fire('Erreur', dataEleves.message || 'Impossible de charger les élèves.', 'error');
        }

    } catch (err) {
        console.error('loadEleves:', err);
        Swal.fire('Erreur réseau', err.message || 'Connexion au serveur échouée.', 'error');
    } finally {
        hideSpinner();
    }
}

// Peupler le select Classe dans la modal
function peuplerSelectClasses() {
    var sel = document.getElementById('EleveClasse');
    if (!sel) return;
    sel.innerHTML = '<option value="">-- Sélectionner une classe --</option>';
    classesData.forEach(function (c) {
        var opt = document.createElement('option');
        opt.value = c.ID;
        opt.textContent = c.NOM;
        sel.appendChild(opt);
    });
}

// Peupler le select Année dans la modal
/**
 * Remplit le select des années
 * @param {boolean} afficherTout - Si true, montre même les clôturées (pour la modif)
 */
function peuplerSelectAnnees(afficherTout) {
    var sel = document.getElementById('eleveAnnee');
    if (!sel) return;

    sel.innerHTML = '<option value="">-- Sélectionner une année --</option>';
    
    anneesData.forEach(function (a) {
        // Si on est en mode "Ajout", on ignore les années clôturées[cite: 9, 10]
        if (!afficherTout && a.CLOTURE) {
            return; 
        }

        var opt = document.createElement('option');
        opt.value = a.ID;
        // On ajoute une mention visuelle si l'année est clôturée (utile pour la modif)[cite: 9]
        opt.textContent = a.ANNEE + (a.CLOTURE ? ' (Clôturée)' : '');
        sel.appendChild(opt);
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL FILTRE INITIAL
// ─────────────────────────────────────────────────────────────────────────────
function showInitialFilterModal() {
    var savedFilter = {};
    try { savedFilter = JSON.parse(localStorage.getItem('lastInitialFilter')) || {}; } catch (e) { }

    var anneeOptions = anneesData.map(function (a) {
        return '<option value="' + escHtml(a.ANNEE) + '">' + escHtml(a.ANNEE) + '</option>';
    }).join('');

    var classeOptions = classesData.map(function (c) {
        return '<option value="' + escHtml(String(c.ID)) + '">' + escHtml(c.NOM) + '</option>';
    }).join('');

    Swal.fire({
        title: '<i class="fas fa-filter"></i> Filtrer les élèves',
        html: `
            <div style="text-align:left;">
                <label style="display:block;margin-bottom:6px;font-weight:600;">Année Scolaire</label>
                <select id="init-annee" class="form-control" style="margin-bottom:12px;">
                    <option value="">-- Toutes --</option>
                    ${anneeOptions}
                </select>

                <label style="display:block;margin-bottom:6px;font-weight:600;">Classe</label>
                <select id="init-classe" class="form-control" style="margin-bottom:12px;">
                    <option value="">-- Toutes les classes --</option>
                    ${classeOptions}
                </select>

                <label style="display:block;margin-bottom:6px;font-weight:600;">Matricule</label>
                <input type="text" id="init-matricule" class="form-control" style="margin-bottom:12px;"
                    value="${escHtml(savedFilter.matricule || '')}" placeholder="Ex: MAT-2024...">

                <label style="display:block;margin-bottom:6px;font-weight:600;">Nom de l'élève</label>
                <input type="text" id="init-nom" class="form-control" style="margin-bottom:12px;"
                    value="${escHtml(savedFilter.nom || '')}" placeholder="Nom...">

                <label style="display:block;margin-bottom:6px;font-weight:600;">Statut</label>
                <select id="init-status" class="form-control">
                    <option value="">-- Tous --</option>
                    <option value="actif">Actif</option>
                    <option value="inactif">Inactif</option>
                    <option value="suspendu">Suspendu</option>
                </select>
            </div>`,
        confirmButtonText: '<i class="fas fa-check"></i> Appliquer',
        confirmButtonColor: '#007bff',
        showCancelButton: true,
        cancelButtonText: 'Annuler',
        preConfirm: function () {
            return {
                annee: document.getElementById('init-annee').value,
                classe: document.getElementById('init-classe').value,
                matricule: document.getElementById('init-matricule').value.trim(),
                nom: document.getElementById('init-nom').value.trim(),
                status: document.getElementById('init-status').value
            };
        }
    }).then(function (result) {
        if (result.isConfirmed) {
            applyInitialFilters(result.value);
        }
        // Annuler : ferme simplement le modal, rien ne change
    });
}

function applyInitialFilters(criteria) {
    try { localStorage.setItem('lastInitialFilter', JSON.stringify(criteria)); } catch (e) { }
    isInitialLoad = false;

    baseFilteredData = elevesData.filter(function (eleve) {
        var matchAnnee = criteria.annee ? (eleve.ANNEE_TEXTE === criteria.annee) : true;
        var matchClasse = criteria.classe ? (String(eleve.ID_CLASSE) === String(criteria.classe)) : true;
        var matchMatricule = criteria.matricule ? (eleve.MATRICULE?.toLowerCase().includes(criteria.matricule.toLowerCase())) : true;
        var matchNom = criteria.nom ? (eleve.NOM?.toLowerCase().includes(criteria.nom.toLowerCase())) : true;
        var matchStatus = criteria.status ? (eleve.STATUT?.toLowerCase() === criteria.status.toLowerCase()) : true;
        return matchAnnee && matchClasse && matchMatricule && matchNom && matchStatus;
    });

    filteredEleves = [...baseFilteredData];
    currentPage = 1;
    createFilterControls();
    renderSimpleTable();

    var count = filteredEleves.length;
    Swal.mixin({ toast: true, position: 'top-end', showConfirmButton: false, timer: 2500 })
        .fire({ icon: 'success', title: count + ' élève(s) trouvé(s)' });
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRE DE FILTRES RAPIDE (recherche + statut + pagination)
// ─────────────────────────────────────────────────────────────────────────────
function createFilterControls() {
    if (document.getElementById('filter-container')) return;

    var fc = document.createElement('div');
    fc.id = 'filter-container';
    fc.style.cssText = 'margin:0 0 20px;padding:14px 18px;background:linear-gradient(135deg,#f8f9fa,#e9ecef);border-radius:10px;display:flex;gap:14px;flex-wrap:wrap;align-items:flex-end;box-shadow:0 2px 8px rgba(0,0,0,.08);border:1px solid #dee2e6;';
    fc.innerHTML = `
        <div style="flex:2;min-width:200px;">
            <label style="display:block;margin-bottom:6px;font-weight:600;color:#495057;font-size:13px;">
                <i class="fas fa-search"></i> Recherche
            </label>
            <input type="text" id="search-filter" placeholder="Nom, matricule, email..."
                style="width:100%;padding:9px 12px;border:1px solid #ced4da;border-radius:6px;font-size:13px;">
        </div>
        <div style="min-width:150px;">
            <label style="display:block;margin-bottom:6px;font-weight:600;color:#495057;font-size:13px;">
                <i class="fas fa-filter"></i> Statut
            </label>
            <select id="status-filter" class="form-control">
                <option value="">Tous</option>
                <option value="actif">Actif</option>
                <option value="inactif">Inactif</option>
                <option value="suspendu">Suspendu</option>
            </select>
        </div>
        <div style="min-width:130px;">
            <label style="display:block;margin-bottom:6px;font-weight:600;color:#495057;font-size:13px;">
                <i class="fas fa-list"></i> Afficher
            </label>
            <select id="rows-per-page-top" class="form-control">
                <option value="5">5 lignes</option>
                <option value="10" selected>10 lignes</option>
                <option value="20">20 lignes</option>
                <option value="50">50 lignes</option>
                <option value="100">100 lignes</option>
                <option value="-1">Tous</option>
            </select>
        </div>
        <button id="btn-reset-filters" type="button"
            style="padding:9px 20px;background:#6c757d;color:white;border:none;border-radius:6px;cursor:pointer;font-size:13px;">
            <i class="fas fa-undo"></i> Réinitialiser
        </button>`;

    var container = document.querySelector('.dash-card-body') || document.body;
    container.prepend(fc);

    document.getElementById('search-filter').addEventListener('input', applyFilters);
    document.getElementById('status-filter').addEventListener('change', applyFilters);
    document.getElementById('rows-per-page-top').addEventListener('change', function (e) {
        rowsPerPage = parseInt(e.target.value);
        currentPage = 1;
        renderSimpleTable();
    });
    document.getElementById('btn-reset-filters').addEventListener('click', resetFilters);
}

function applyFilters() {
    var search = (document.getElementById('search-filter')?.value || '').toLowerCase().trim();
    var status = document.getElementById('status-filter')?.value || '';

    filteredEleves = baseFilteredData.filter(function (eleve) {
        var matchSearch = !search || (
            eleve.NOM?.toLowerCase().includes(search) ||
            eleve.MATRICULE?.toLowerCase().includes(search) ||
            eleve.EMAIL?.toLowerCase().includes(search)
        );
        var matchStatus = !status || (eleve.STATUT?.toLowerCase() === status);
        return matchSearch && matchStatus;
    });

    currentPage = 1;
    renderSimpleTable();
}

function resetFilters() {
    var sf = document.getElementById('search-filter');
    var stf = document.getElementById('status-filter');
    var rp = document.getElementById('rows-per-page-top');
    if (sf) sf.value = '';
    if (stf) stf.value = '';
    if (rp) rp.value = '10';
    rowsPerPage = 10;
    applyFilters();
}

function goToPage(page) {
    currentPage = page;
    renderSimpleTable();
}

function createPaginationControls(totalPages) {
    const oldPagination = document.getElementById('pagination-container');
    if (oldPagination) oldPagination.remove();
    if (totalPages <= 1) return;

    const container = document.createElement('div');
    container.id = 'pagination-container';
    container.style.cssText = 'margin:20px 0; display:flex; justify-content:center; gap:5px; flex-wrap:wrap;';

    const createBtn = (text, onClick, disabled = false, isDots = false) => {
        const btn = document.createElement('button');
        btn.textContent = text;
        if (isDots) {
            btn.style.cssText = 'padding:8px 12px; border:none; background:transparent; color:#6c757d; cursor:default;';
            return btn;
        }
        const isActive = (text == currentPage && !isNaN(text));
        btn.style.cssText = `padding:8px 14px; border:1px solid ${isActive ? '#007bff' : '#dee2e6'}; background:${isActive ? '#007bff' : (disabled ? '#e9ecef' : 'white')}; color:${isActive ? 'white' : (disabled ? '#6c757d' : '#007bff')}; cursor:${disabled || isActive ? 'default' : 'pointer'}; border-radius:6px; font-weight:${isActive ? '700' : '500'}; min-width:40px;`;
        if (onClick && !disabled && !isActive) btn.onclick = onClick;
        if (disabled) btn.disabled = true;
        return btn;
    };

    container.appendChild(createBtn('«', () => goToPage(1), currentPage === 1));
    container.appendChild(createBtn('‹', () => { if (currentPage > 1) { currentPage--; renderSimpleTable(); } }, currentPage === 1));

    const maxVisible = 5;
    let start = Math.max(1, currentPage - Math.floor(maxVisible / 2));
    let end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);

    if (start > 1) {
        container.appendChild(createBtn('1', () => goToPage(1)));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }
    for (let i = start; i <= end; i++) {
        container.appendChild(createBtn(i, () => goToPage(i), false));
    }
    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        container.appendChild(createBtn(totalPages, () => goToPage(totalPages)));
    }
    container.appendChild(createBtn('›', () => { if (currentPage < totalPages) { currentPage++; renderSimpleTable(); } }, currentPage === totalPages));
    container.appendChild(createBtn('»', () => goToPage(totalPages), currentPage === totalPages));

    const table = document.querySelector('.dash-table');
    if (table?.parentNode) table.parentNode.insertBefore(container, table.nextSibling);
}

function updateCounter() {
    let counter = document.getElementById('record-counter');
    if (!counter) {
        counter = document.createElement('div');
        counter.id = 'record-counter';
        counter.style.cssText = 'margin:15px 0 0; padding:10px 15px; text-align:center; font-size:14px; background:#f8f9fa; border-radius:6px; border:1px solid #e9ecef;';
        const pagination = document.getElementById('pagination-container');
        if (pagination?.parentNode) pagination.parentNode.insertBefore(counter, pagination);
        else {
            const table = document.querySelector('.dash-table');
            if (table?.parentNode) table.parentNode.insertBefore(counter, table.nextSibling);
        }
    }
    
    const start = filteredEleves.length === 0 ? 0 : (currentPage - 1) * rowsPerPage + 1;
    const end = Math.min(currentPage * rowsPerPage, filteredEleves.length);
    counter.innerHTML = `<i class="fas fa-chart-bar"></i> <strong>Affichage :</strong> ${filteredEleves.length === 0 ? '0' : start} à ${end} sur <strong>${filteredEleves.length}</strong> enregistrement${filteredEleves.length > 1 ? 's' : ''}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// TRI
// ─────────────────────────────────────────────────────────────────────────────
function sortData(column) {
    sortDirection *= -1;
    filteredEleves.sort(function (a, b) {
        var va = (a[column] || '').toString().toLowerCase();
        var vb = (b[column] || '').toString().toLowerCase();
        return va < vb ? -sortDirection : va > vb ? sortDirection : 0;
    });
    currentPage = 1;
    renderSimpleTable();
}

// ─────────────────────────────────────────────────────────────────────────────
// RENDU TABLEAU
// ─────────────────────────────────────────────────────────────────────────────
function renderSimpleTable() {
    var tbody = document.getElementById('elevesTableBody');
    if (!tbody) return;

    var start = (currentPage - 1) * rowsPerPage;
    var pageData = filteredEleves.slice(start, start + rowsPerPage);
    var totalPages = Math.ceil(filteredEleves.length / rowsPerPage);

    if (!pageData.length) {
        tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:50px;">' +
            '<i class="fas fa-search" style="font-size:40px;color:#ccc;display:block;margin-bottom:12px;"></i>' +
            'Aucun élève trouvé</td></tr>';
    } else {
        tbody.innerHTML = '';
        pageData.forEach(function (eleve) {
            // Vérification de la clôture via l'objet année rattaché
            var anneeObj = anneesData.find(a => a.ID == eleve.ANNEE_ID || a.ANNEE === eleve.ANNEE_TEXTE);
            var isCloture = anneeObj && anneeObj.CLOTURE === true;

            var row = tbody.insertRow();
            row.innerHTML =
                '<td>' + getMatriculeBadge(eleve.MATRICULE) + '</td>' +
                '<td>' + escHtml(eleve.ANNEE_TEXTE || '-') + '</td>' +
                '<td>' + getNomBadge(eleve.NOM) + '</td>' +
                '<td>' + getClasseBadge(eleve.CLASSE_NOM || '-') + '</td>' +
                '<td>' + escHtml(eleve.EMAIL || '-') + '</td>' +
                '<td>' + escHtml(eleve.TELEPHONE || '-') + '</td>' +
                '<td>' + getStatutBadge(eleve.STATUT) + '</td>' +
                '<td>' +
                (isCloture
                    ? '<button type="button" class="btn btn-sm btn-secondary" style="margin:0 2px;cursor:not-allowed;" title="Année clôturée" disabled><i class="fas fa-lock"></i></button>'
                    : '<button type="button" class="btn btn-sm btn-primary" style="margin:0 2px;" onclick="openEditEleveModal(\'' + eleve.ID + '\')"><i class="fas fa-edit"></i></button>') +
                (isCloture
                    ? '<button type="button" class="btn btn-sm btn-secondary" style="margin:0 2px;cursor:not-allowed;" disabled><i class="fas fa-trash"></i></button>'
                    : '<button type="button" class="btn btn-sm btn-danger" style="margin:0 2px;" onclick="supprimerEleve(\'' + eleve.ID + '\', \'' + escapeHtml(eleve.NOM || '').replace(/'/g, "\\'") + '\')"><i class="fas fa-trash"></i></button>') +
                '</td>';
        });
    }

    updateCounter();
    createPaginationControls(totalPages);
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGES
// ─────────────────────────────────────────────────────────────────────────────
function getNomBadge(nom) {
    return '<span style="color:#212529;font-weight:700;">' + escHtml(nom || '-') + '</span>';
}

function getMatriculeBadge(matricule) {
    return '<span style="background:#f1f3f5;color:#212529;padding:4px 12px;border-radius:6px;font-size:12px;font-weight:700;border:1px solid #dee2e6;display:inline-block;">' + escHtml(matricule || '-') + '</span>';
}

function getStatutBadge(statut) {
    var s = (statut || '').toLowerCase();
    var style = 'padding:4px 10px;border-radius:20px;color:white;font-size:12px;font-weight:500;';
    if (s === 'actif') return '<span style="background:#28a745;' + style + '">✓ Actif</span>';
    if (s === 'suspendu') return '<span style="background:#6c757d;' + style + '">⚠ Suspendu</span>';
    return '<span style="background:#dc3545;' + style + '">✗ Inactif</span>';
}

function getClasseBadge(classeNom) {
    return '<span style="background:#fff;color:#007bff;padding:4px 12px;border-radius:20px;font-size:11px;font-weight:700;border:1px solid #007bff;white-space:nowrap;">' +
        '<i class="fas fa-folder" style="margin-right:5px;font-size:10px;"></i>' + escHtml(classeNom) +
        '</span>';
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL — OUVRIR AJOUT
// ─────────────────────────────────────────────────────────────────────────────
function openAddEleveModal(event) {
    if (event) { event.preventDefault(); event.stopPropagation(); }

    currentMode = 'ajout';
    currentEleveId = null;
    resetEleveForm();

    // Rétablir les champs pour l'ajout
    var inputAnnee = document.getElementById('eleveAnnee');
    var inputMatricule = document.getElementById('eleveMatricule');

    if (inputAnnee) {
        inputAnnee.disabled = false;
        inputAnnee.style.backgroundColor = '#fff'; // Fond blanc
    }
    if (inputMatricule) {
        inputMatricule.disabled = false;
        inputMatricule.style.backgroundColor = '#fff';
    }

    var title = document.getElementById('modalTitle');
    if (title) title.innerHTML = '<i class="fas fa-plus"></i> Nouvel élève';

    showModal('eleveModal');
    return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL — OUVRIR MODIFICATION
// ─────────────────────────────────────────────────────────────────────────────
function openEditEleveModal(id) {
    var eleve = elevesData.find(e => e.ID == id);
    var anneeObj = anneesData.find(a => a.ID == eleve.ANNEE_ID || a.ANNEE === eleve.ANNEE_TEXTE);

    if (anneeObj && anneeObj.CLOTURE) {
        Swal.fire('Action impossible', 'Cette année est clôturée. Aucune modification n’est autorisée.', 'warning');
        return;
    }

    currentMode = 'modification';
    currentEleveId = id;

    // --- CORRECTION DU REMPLISSAGE DE L'ANNÉE ---
    var selectAnnee = document.getElementById('eleveAnnee');
    if (selectAnnee) {
        // On cherche l'ID. Si ANNEE_ID est vide, on essaie de trouver l'ID 
        // en cherchant dans anneesData celui qui correspond au texte (ex: "2023-2024")
        var idAnnee = eleve.ANNEE_ID;

        if (!idAnnee && eleve.ANNEE_TEXTE) {
            var found = anneesData.find(function (a) { return a.ANNEE === eleve.ANNEE_TEXTE; });
            if (found) idAnnee = found.ID;
        }

        // On force la valeur (en string pour le select)
        selectAnnee.value = idAnnee ? idAnnee.toString() : "";

        // Verrouillage visuel
        selectAnnee.disabled = true;
        selectAnnee.style.backgroundColor = '#e9ecef';
        selectAnnee.style.cursor = 'not-allowed';
    }

    // --- SELECTION DU MATRICULE ---
    var inputMatricule = document.getElementById('eleveMatricule');
    if (inputMatricule) {
        inputMatricule.value = eleve.MATRICULE || '';
        inputMatricule.disabled = true;
        inputMatricule.style.backgroundColor = '#e9ecef'; // Gris figé
        inputMatricule.style.cursor = 'not-allowed';
    }

    // Remplissage des autres champs modifiables
    setVal('eleveNom', eleve.NOM || '');
    setVal('EleveClasse', String(eleve.ID_CLASSE || '')); // Utilise .CLASSE selon votre SQL
    setVal('eleveEmail', eleve.EMAIL || '');
    setVal('eleveTelephone', eleve.TELEPHONE || '');
    setVal('eleveDateNaiss', eleve.DATE_NAISSANCE || '');
    setVal('eleveGenre', eleve.GENRE || 'M');
    setVal('eleveAdresse', eleve.ADRESSE || '');
    setVal('eleveParent', eleve.PARENT || '');
    setVal('eleveStatut', (eleve.STATUT || 'actif').toLowerCase());

    var title = document.getElementById('modalTitle');
    if (title) title.innerHTML = '<i class="fas fa-edit"></i> Modifier l\'élève';

    showModal('eleveModal');
}

function resetEleveForm() {
    ['eleveAnnee', 'eleveMatricule', 'eleveNom', 'EleveClasse', 'eleveEmail',
        'eleveTelephone', 'eleveDateNaiss', 'eleveAdresse', 'eleveParent'].forEach(function (id) {
            setVal(id, '');
        });
    setVal('eleveGenre', 'M');
    setVal('eleveStatut', 'actif');
}

// ─────────────────────────────────────────────────────────────────────────────
// SAUVEGARDE (Ajouter ou Modifier)
// ─────────────────────────────────────────────────────────────────────────────
async function saveEleve(event) {
    if (event) { event.preventDefault(); event.stopPropagation(); }

    var body = {
        ID: currentEleveId,
        ANNEE_ID: getVal('eleveAnnee'),
        MATRICULE: getVal('eleveMatricule'),
        NOM: getVal('eleveNom'),
        CLASSE: getVal('EleveClasse'),
        EMAIL: getVal('eleveEmail'),
        TELEPHONE: getVal('eleveTelephone'),
        STATUT: getVal('eleveStatut'),
        GENRE: getVal('eleveGenre'),
        DATE_NAISSANCE: getVal('eleveDateNaiss'),
        ADRESSE: getVal('eleveAdresse'),
        PARENT: getVal('eleveParent')
    };

    // --- Validation côté client ---
    if (!body.NOM.trim()) {
        Swal.fire('Attention', 'Le nom complet est obligatoire.', 'warning'); 
        return false;
    }
    if (!body.MATRICULE.trim()) {
        Swal.fire('Attention', 'Le matricule est obligatoire.', 'warning'); 
        return false;
    }
    if (!body.CLASSE) {
        Swal.fire('Attention', 'Veuillez sélectionner une classe.', 'warning'); 
        return false;
    }
    if (!body.ANNEE_ID) {
        Swal.fire('Attention', 'Veuillez sélectionner une année scolaire.', 'warning'); 
        return false;
    }

    // --- Sécurité : Vérifier si l'année sélectionnée est clôturée ---
    var anneeSelectionnee = anneesData.find(a => a.ID == body.ANNEE_ID);
    if (anneeSelectionnee && anneeSelectionnee.CLOTURE) {
        Swal.fire('Action impossible', 'Vous ne pouvez pas ajouter ou modifier un élève dans une année clôturée.', 'error');
        return false;
    }

    var url = currentMode === 'ajout' ? API.ajouter : API.modifier;

    if (typeof showSpinner === "function") showSpinner();

    try {
        var res = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });

        var data = await safeJson(res);

        if (data.success) {
            Swal.fire({ 
                icon: 'success', 
                title: data.message || 'Opération réussie', 
                timer: 1500, 
                showConfirmButton: false 
            });
            
            setTimeout(function () { 
                closeEleveModal(); 
                // FORCER LE RECHARGEMENT COMPLET DES DONNÉES
                reloadElevesAfterModification();
            }, 1500);
        } else {
            var msg = data.message || 'Erreur inconnue.';
            if (msg.includes("PRIMARY KEY") || msg.includes("UQ_") || msg.includes("duplicate key")) {
                msg = "Ce matricule existe déjà. Veuillez attribuer un matricule unique à cet élève.";
            }
            Swal.fire({
                icon: 'error',
                title: 'Erreur d\'enregistrement',
                text: msg
            });
        }
    } catch (err) {
        console.error('saveEleve:', err);
        Swal.fire('Erreur réseau', 'Impossible de contacter le serveur.', 'error');
    } finally {
        if (typeof hideSpinner === "function") hideSpinner();
    }
    return false;
}

// Nouvelle fonction pour recharger les données après modification
async function reloadElevesAfterModification() {
    console.log('[RELOAD] Rechargement des données...');
    showSpinner();
    
    try {
        // Recharger toutes les données
        const [dataEleves, dataClasses, dataAnnees] = await Promise.all([
            fetchJson(API.getEleves),
            fetchJson(API.getClasses),
            fetchJson(API.getAnnees)
        ]);

        // Mettre à jour les classes
        if (dataClasses.success) {
            classesData = dataClasses.Classes || dataClasses.niveaux || [];
            peuplerSelectClasses();
        }

        // Mettre à jour les années
        if (dataAnnees.success) {
            anneesData = dataAnnees.Annees || [];
            peuplerSelectAnnees();
        }

        // Mettre à jour les élèves
        if (dataEleves.success) {
            elevesData = dataEleves.Eleves || [];
            
            // Re-appliquer les filtres existants
            if (baseFilteredData.length > 0 || !isInitialLoad) {
                // Conserver les critères de filtre actuels
                var searchValue = document.getElementById('search-filter')?.value || '';
                var statusValue = document.getElementById('status-filter')?.value || '';
                
                baseFilteredData = elevesData.filter(function (eleve) {
                    // Reconstruire baseFilteredData avec les mêmes critères initiaux
                    // Pour simplifier, on garde tous les élèves et on réapplique les filtres
                    return true;
                });
                baseFilteredData = [...elevesData];
                
                // Réappliquer les filtres de recherche
                filteredEleves = baseFilteredData.filter(function (eleve) {
                    var matchSearch = !searchValue || (
                        eleve.NOM?.toLowerCase().includes(searchValue.toLowerCase()) ||
                        eleve.MATRICULE?.toLowerCase().includes(searchValue.toLowerCase()) ||
                        eleve.EMAIL?.toLowerCase().includes(searchValue.toLowerCase())
                    );
                    var matchStatus = !statusValue || (eleve.STATUT?.toLowerCase() === statusValue);
                    return matchSearch && matchStatus;
                });
            } else {
                baseFilteredData = [...elevesData];
                filteredEleves = [...elevesData];
            }
            
            currentPage = 1;
            renderSimpleTable();
            
            console.log('[RELOAD] Données rechargées:', elevesData.length, 'élèves');
        } else {
            Swal.fire('Erreur', dataEleves.message || 'Impossible de recharger les élèves.', 'error');
        }

    } catch (err) {
        console.error('reloadElevesAfterModification:', err);
        Swal.fire('Erreur réseau', err.message || 'Connexion au serveur échouée.', 'error');
    } finally {
        hideSpinner();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPRESSION
// ─────────────────────────────────────────────────────────────────────────────
// --- FONCTIONS UTILITAIRES À AJOUTER ---

// 1. Pour échapper les caractères HTML (sécurité XSS)
function escHtml(text) {
    if (!text) return "";
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// 2. Pour parser le JSON en toute sécurité (utilisé dans votre fetch)
async function safeJson(response) {
    try {
        return await response.json();
    } catch (e) {
        return { success: false, message: "Erreur de réponse serveur" };
    }
}

// --- VOTRE FONCTION PRINCIPALE ---

async function supprimerEleve(id, nom) {
    var eleve = elevesData.find(e => e.ID == id);
    var anneeObj = anneesData.find(a => a.ID == eleve.ANNEE_ID || a.ANNEE === eleve.ANNEE_TEXTE);

    if (anneeObj && anneeObj.CLOTURE) {
        Swal.fire('Blocage', 'Impossible de supprimer un élève rattaché à une année clôturée.', 'error');
        return;
    }

    var result = await Swal.fire({
        title: 'Supprimer cet élève ?',
        html: '<strong>' + escHtml(nom) + '</strong> sera supprimé définitivement.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    });

    if (!result.isConfirmed) return;

    if (typeof showSpinner === "function") showSpinner();

    try {
        var res = await fetch(API.supprimer, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ID: id })
        });

        var data = await safeJson(res);

        if (data.success) {
            // Recharger complètement les données
            await reloadElevesAfterModification();

            Swal.fire({
                icon: 'success',
                title: data.message || 'Élève supprimé.',
                timer: 1000,
                showConfirmButton: false
            });
        } else {
            Swal.fire('Erreur', data.message || 'Erreur lors de la suppression.', 'error');
        }
    } catch (err) {
        console.error('supprimerEleve:', err);
        Swal.fire('Erreur réseau', err.message, 'error');
    } finally {
        if (typeof hideSpinner === "function") hideSpinner();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT
// ─────────────────────────────────────────────────────────────────────────────
function exportEleves() {
    exportElevesToExcelOnly();
    exportElevesToCsvOnly();
}

function exportElevesToExcelOnly() {
    if (!filteredEleves.length) { Swal.fire('Info', 'Aucune donnée à exporter.', 'info'); return; }
    var rows = [['MATRICULE', 'ANNÉE', 'NOM', 'CLASSE', 'EMAIL', 'TÉLÉPHONE', 'STATUT']];
    filteredEleves.forEach(function (e) {
        rows.push([e.MATRICULE || '', e.ANNEE_TEXTE || '', e.NOM || '', e.CLASSE_NOM || '', e.EMAIL || '', e.TELEPHONE || '', e.STATUT || '']);
    });
    var ws = XLSX.utils.aoa_to_sheet(rows);
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Eleves');
    XLSX.writeFile(wb, 'eleves_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportElevesToCsvOnly() {
    if (!filteredEleves.length) { Swal.fire('Info', 'Aucune donnée à exporter.', 'info'); return; }
    var header = 'MATRICULE;ANNEE;NOM;CLASSE;EMAIL;TELEPHONE;STATUT\n';
    var rows = filteredEleves.map(function (e) {
        return [e.MATRICULE || '', e.ANNEE_TEXTE || '', e.NOM || '', e.CLASSE_NOM || '', e.EMAIL || '', e.TELEPHONE || '', e.STATUT || ''].join(';');
    }).join('\n');
    var blob = new Blob(['\uFEFF' + header + rows], { type: 'text/csv;charset=utf-8' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'eleves_' + new Date().toISOString().slice(0, 10) + '.csv';
    a.click();
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPORTER EN EXCEL
// ─────────────────────────────────────────────────────────────────────────────
function exportElevesToExcelOnly() {
    if (!filteredEleves.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }

    // Préparation des colonnes pour Excel
    var rows = [['MATRICULE', 'ANNÉE', 'NOM', 'CLASSE', 'EMAIL', 'TÉLÉPHONE', 'STATUT']];

    filteredEleves.forEach(function (e) {
        rows.push([
            e.MATRICULE || '',
            e.ANNEE_TEXTE || '',
            e.NOM || '',
            e.CLASSE_NOM || '',
            e.EMAIL || '',
            e.TELEPHONE || '',
            e.STATUT || ''
        ]);
    });

    // Création du classeur Excel
    var ws = XLSX.utils.aoa_to_sheet(rows);
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Liste_Eleves');

    // Téléchargement
    XLSX.writeFile(wb, 'Export_Eleves_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPRIMER EN PDF
// ─────────────────────────────────────────────────────────────────────────────
window.exportEleves = function () {
    if (!filteredEleves || filteredEleves.length === 0) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }

    try {
        // Initialisation correcte pour la version UMD
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');

        // Préparation des données
        const head = [['MATRICULE', 'ANNÉE', 'NOM COMPLET', 'CLASSE', 'EMAIL', 'STATUT']];
        const body = filteredEleves.map(function (e) {
            return [
                e.MATRICULE || '',
                e.ANNEE_TEXTE || '',
                e.NOM || '',
                e.CLASSE_NOM || '',
                e.EMAIL || '',
                e.STATUT || ''
            ];
        });

        // Utilisation de la syntaxe recommandée pour éviter "deprecated autoTable initiation"
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] }, // Bleu primaire
            styles: { fontSize: 8, cellPadding: 2 },
            didDrawPage: function (data) {
                // Pied de page simple
                doc.setFontSize(8);
                doc.text("Page " + data.pageNumber, data.settings.margin.left, doc.internal.pageSize.height - 10);
            }
        });

        doc.save('Liste_Eleves.pdf');

    } catch (err) {
        console.error("Erreur PDF détaillée:", err);
        Swal.fire('Erreur', 'Erreur lors de la génération : ' + err.message, 'error');
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// MODAL HELPERS
// ─────────────────────────────────────────────────────────────────────────────
function showModal(id) {
    var m = document.getElementById(id || 'eleveModal');
    if (m) {
        m.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    }
}

function closeEleveModal() {
    var m = document.getElementById('eleveModal');
    if (m) {
        m.style.display = 'none';
        document.body.style.overflow = '';
    }
    currentMode = null;
    currentEleveId = null;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTRÔLES UI (Échap)
// ─────────────────────────────────────────────────────────────────────────────
function initUIControls() {
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            closeEleveModal();
            closeModal('modalImport');
            closeModal('modalMapping');
        }
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// UTILITAIRES
// ─────────────────────────────────────────────────────────────────────────────
async function fetchJson(url) {
    var res = await fetch(url);
    return safeJson(res);
}

async function safeJson(res) {
    try {
        var text = await res.text();
        if (!text?.trim()) return { success: false, message: 'Réponse vide du serveur.' };
        return JSON.parse(text);
    } catch (e) {
        return { success: false, message: 'Erreur de parsing JSON.' };
    }
}

function getVal(id) {
    var el = document.getElementById(id);
    return el ? el.value.trim() : '';
}

function setVal(id, val) {
    var el = document.getElementById(id);
    if (el) el.value = val;
}

function escHtml(str) {
    if (!str) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}


// Fonction pour mettre à jour le nom du fichier sélectionné
function updateFileName() {
    var file = document.getElementById('excelFile');
    var display = document.getElementById('fileNameDisplay');
    var btn = document.getElementById('btnLaunchImport');
    if (!file || !display) return;

    var name = file.files[0] ? file.files[0].name : '';
    display.value = name;
    if (btn) btn.disabled = !name;
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPOSITION GLOBALE (onclick= dans le HTML)
// ─────────────────────────────────────────────────────────────────────────────
window.openAddEleveModal = openAddEleveModal;
window.openEditEleveModal = openEditEleveModal;
window.closeEleveModal = closeEleveModal;
window.saveEleve = saveEleve;
window.supprimerEleve = supprimerEleve;
window.sortData = sortData;
window.goToPage = goToPage;
window.exportEleves = exportEleves;
window.exportElevesToExcelOnly = exportElevesToExcelOnly;
window.exportElevesToCsvOnly = exportElevesToCsvOnly;
window.showInitialFilterModal = showInitialFilterModal;
window.updateFileName = updateFileName;

