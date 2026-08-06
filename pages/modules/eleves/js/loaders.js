'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// CHARGEMENT DES DONNÉES
// ─────────────────────────────────────────────────────────────────────────────
async function loadEleves() {
    showSpinner();
    try {
        const [dataEleves, dataClasses, dataAnnees] = await Promise.all([
            fetchJson(API_ELEVES.getEleves),
            fetchJson(API_ELEVES.getClasses),
            fetchJson(API_ELEVES.getAnnees)
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
                renderTable();
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

// ─────────────────────────────────────────────────────────────────────────────
// PEUPLER LES SELECTS
// ─────────────────────────────────────────────────────────────────────────────
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

function peuplerSelectAnnees(afficherTout) {
    var sel = document.getElementById('eleveAnnee');
    if (!sel) return;
    sel.innerHTML = '<option value="">-- Sélectionner une année --</option>';
    anneesData.forEach(function (a) {
        if (!afficherTout && a.CLOTURE) return;
        var opt = document.createElement('option');
        opt.value = a.ID;
        opt.textContent = a.ANNEE + (a.CLOTURE ? ' (Clôturée)' : '');
        sel.appendChild(opt);
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// RENDU TABLEAU
// ─────────────────────────────────────────────────────────────────────────────
function renderTable() {
    var tbody = document.getElementById('elevesTableBody');
    if (!tbody) return;

    var start = (currentPage - 1) * rowsPerPage;
    var pageData = filteredEleves.slice(start, start + rowsPerPage);
    var totalPages = Math.ceil(filteredEleves.length / rowsPerPage);

    if (!pageData.length) {
        tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:50px;">'
            + '<i class="fas fa-search" style="font-size:40px;color:#ccc;display:block;margin-bottom:12px;"></i>'
            + 'Aucun élève trouvé</td></tr>';
    } else {
        tbody.innerHTML = '';
        pageData.forEach(function (eleve) {
            var anneeObj = anneesData.find(a => a.ID == eleve.ANNEE_ID || a.ANNEE === eleve.ANNEE_TEXTE);
            var isCloture = anneeObj && anneeObj.CLOTURE === true;

            var row = tbody.insertRow();
            row.innerHTML =
                '<td>' + getMatriculeBadge(eleve.MATRICULE) + '</td>' +
                '<td>' + escapeHtml(eleve.ANNEE_TEXTE || '-') + '</td>' +
                '<td>' + getNomBadge(eleve.NOM) + '</td>' +
                '<td>' + getClasseBadge(eleve.CLASSE_NOM || '-') + '</td>' +
                '<td>' + escapeHtml(eleve.EMAIL || '-') + '</td>' +
                '<td>' + escapeHtml(eleve.TELEPHONE || '-') + '</td>' +
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
    renderTable();
}