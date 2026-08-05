/**
 * stats.js - Rendu des statistiques et du tableau des niveaux
 */

'use strict';

function renderNiveauxStats() {
    var container = document.getElementById('niveauxStatsContainer');
    if (!container) return;

    var total = STATE.niveauxData.length;
    var actifs = 0;
    var inactifs = 0;

    for (var i = 0; i < STATE.niveauxData.length; i++) {
        var n = STATE.niveauxData[i];
        var isActif = (n.STATUT === true || n.STATUT === 1 || n.STATUT === '1' || n.STATUT === 'True');
        if (isActif) {
            actifs++;
        } else {
            inactifs++;
        }
    }

    var stats = [
        { label: 'Total niveaux', value: total, icon: 'fas fa-layer-group', color: '#007bff' },
        { label: 'Actifs', value: actifs, icon: 'fas fa-check-circle', color: '#28a745' },
        { label: 'Inactifs', value: inactifs, icon: 'fas fa-times-circle', color: '#dc3545' }
    ];

    container.innerHTML = stats.map(function(s) {
        return '<div class="absence-stat-card" style="border-left:4px solid ' + s.color + ';">' +
            '  <div class="stat-icon" style="color:' + s.color + ';"><i class="' + s.icon + '"></i></div>' +
            '  <div class="stat-info">' +
            '    <span class="stat-value">' + s.value + '</span>' +
            '    <span class="stat-label">' + escHtml(s.label) + '</span>' +
            '  </div>' +
            '</div>';
    }).join('');
}

function renderNiveauxTable() {
    var tbody = document.getElementById('niveauxTableBody');
    if (!tbody) return;

    var startIndex = (STATE.currentPage - 1) * STATE.rowsPerPage;
    var endIndex = startIndex + STATE.rowsPerPage;
    var pageNiveaux = STATE.filteredNiveaux.slice(startIndex, endIndex);
    var totalPages = Math.ceil(STATE.filteredNiveaux.length / STATE.rowsPerPage);

    tbody.innerHTML = '';

    if (!pageNiveaux.length) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding: 60px;">' +
            '<i class="fas fa-search" style="font-size: 48px; color: #ccc; margin-bottom: 15px; display: block;"></i>' +
            'Aucun niveau trouvé</td></tr>';
        return;
    }

    pageNiveaux.forEach(function(n, idx) {
        var row = tbody.insertRow();
        var globalIndex = startIndex + idx + 1;
        var date = n.CREATED_AT ? new Date(n.CREATED_AT).toLocaleDateString('fr-FR') : '—';
        var isActif = (n.STATUT === true || n.STATUT === 1 || n.STATUT === '1' || n.STATUT === 'True');

        // Index
        var cellIndex = row.insertCell(0);
        cellIndex.style.textAlign = 'center';
        cellIndex.style.verticalAlign = 'middle';
        cellIndex.style.color = '#888';
        cellIndex.style.fontSize = '12px';
        cellIndex.innerHTML = globalIndex;

        // Nom du niveau
        var cellNom = row.insertCell(1);
        cellNom.style.textAlign = 'center';
        cellNom.style.verticalAlign = 'middle';
        cellNom.innerHTML = `
            <span style="display: inline-block; min-width: 120px; padding: 3px 8px; border: 1px solid #f0f0f0; border-radius: 8px;">
                <strong>${escHtml(n.NOM) || '-'}</strong>
            </span>`;

        // Ordre
        var cellOrdre = row.insertCell(2);
        cellOrdre.style.textAlign = 'center';
        cellOrdre.style.verticalAlign = 'middle';
        cellOrdre.innerHTML = `
            <span style="display: inline-block; min-width: 40px; padding: 3px 8px; border-radius: 15px; background-color: #007bff; color: #ffffff; font-weight: 700; font-size: 14px;">
                ${escHtml(String(n.ORDRE))}
            </span>`;

        // Statut
        var cellStatut = row.insertCell(3);
        cellStatut.style.textAlign = 'center';
        cellStatut.style.verticalAlign = 'middle';
        cellStatut.innerHTML = isActif
            ? '<span style="background: #28a745; padding: 4px 10px; border-radius: 20px; color: white; font-size: 11px; font-weight: 600; display: inline-block; min-width: 80px;">✓ Actif</span>'
            : '<span style="background: #dc3545; padding: 4px 10px; border-radius: 20px; color: white; font-size: 11px; font-weight: 600; display: inline-block; min-width: 80px;">✗ Inactif</span>';

        // Date de création
        var cellDate = row.insertCell(4);
        cellDate.style.textAlign = 'center';
        cellDate.style.verticalAlign = 'middle';
        cellDate.style.color = '#888';
        cellDate.style.fontSize = '12px';
        cellDate.innerHTML = date;

        // Actions
        var cellActions = row.insertCell(5);
        cellActions.style.textAlign = 'center';
        cellActions.style.verticalAlign = 'middle';
        cellActions.style.whiteSpace = 'nowrap';
        cellActions.innerHTML = `
            <button type="button" class="btn btn-sm btn-primary" style="margin: 0 2px;" onclick="editNiveau('${n.ID}')" title="Modifier">
                <i class="fas fa-edit"></i>
            </button>
            <button type="button" class="btn btn-sm btn-danger" style="margin: 0 2px;" onclick="deleteNiveau('${n.ID}', '${escHtml(n.NOM).replace(/'/g, "\\'")}')" title="Supprimer">
                <i class="fas fa-trash"></i>
            </button>
        `;
    });

    if (typeof createPaginationControls === "function") {
        createPaginationControls(totalPages);
    }
}

// ─────────────────────────────────────────────
// PAGINATION
// ─────────────────────────────────────────────
function createPaginationControls(totalPages) {
    var container = document.getElementById('niveauxPagination');
    if (!container) {
        container = document.createElement('div');
        container.id = 'niveauxPagination';
        container.style.marginTop = '15px';
        container.style.textAlign = 'center';

        var tableContainer = document.querySelector('.dash-card-body');
        if (tableContainer) {
            tableContainer.appendChild(container);
        }
    }

    if (totalPages <= 1) {
        container.innerHTML = '';
        return;
    }

    var html = '<nav aria-label="Pagination des niveaux"><ul class="pagination justify-content-center" style="margin:0;">';

    html += '<li class="page-item ' + (STATE.currentPage === 1 ? 'disabled' : '') + '">';
    html += '<a class="page-link" href="#" onclick="goToPage(' + (STATE.currentPage - 1) + ');return false;">&laquo;</a>';
    html += '</li>';

    for (var i = 1; i <= totalPages; i++) {
        html += '<li class="page-item ' + (i === STATE.currentPage ? 'active' : '') + '">';
        html += '<a class="page-link" href="#" onclick="goToPage(' + i + ');return false;">' + i + '</a>';
        html += '</li>';
    }

    html += '<li class="page-item ' + (STATE.currentPage === totalPages ? 'disabled' : '') + '">';
    html += '<a class="page-link" href="#" onclick="goToPage(' + (STATE.currentPage + 1) + ');return false;">&raquo;</a>';
    html += '</li>';

    html += '</ul></nav>';
    container.innerHTML = html;
}

function goToPage(page) {
    var totalPages = Math.ceil(STATE.filteredNiveaux.length / STATE.rowsPerPage);
    if (page < 1 || page > totalPages) return;
    STATE.currentPage = page;
    renderNiveauxTable();
}

// ─────────────────────────────────────────────
// EXPORT CSV
// ─────────────────────────────────────────────
function exportNiveaux() {
    if (STATE.niveauxData.length === 0) {
        alert('Aucune donnée à exporter.');
        return;
    }

    showSpinner();

    setTimeout(function() {
        try {
            var header = ['ID', 'Nom', 'Ordre', 'Statut', 'Créé le'];
            var rows = STATE.niveauxData.map(function(n) {
                var date = n.CREATED_AT ? new Date(n.CREATED_AT).toLocaleDateString('fr-FR') : '';
                var statut = (n.STATUT === true || n.STATUT === 1 || n.STATUT === '1' || n.STATUT === 'True')
                    ? 'Actif'
                    : 'Inactif';
                return [n.ID, n.NOM, n.ORDRE, statut, date]
                    .map(function(v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; })
                    .join(',');
            });

            var csv = [header.join(',')].concat(rows).join('\r\n');
            var blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = 'niveaux_export_' + dateDuJour() + '.csv';
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

// Exposer les fonctions globalement
window.exportNiveaux = exportNiveaux;
window.goToPage = goToPage;
window.renderNiveauxStats = renderNiveauxStats;
window.renderNiveauxTable = renderNiveauxTable;