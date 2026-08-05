/**
 * stats.js - Statistiques et tableau des salles
 */

'use strict';

function renderSallesStats() {
    var container = document.getElementById('sallesStatsContainer');
    if (!container) return;

    var total = STATE.sallesData.length;
    var disponibles = 0;
    var totalCapa = 0;

    for (var i = 0; i < STATE.sallesData.length; i++) {
        var s = STATE.sallesData[i];
        if (s.STATUT === true || s.STATUT === 1 || s.STATUT === '1' || s.STATUT === 'True') {
            disponibles++;
        }
        totalCapa += parseInt(s.CAPACITE, 10) || 0;
    }

    var stats = [
        { label: 'Total salles', value: total, icon: 'fas fa-door-open', color: '#007bff' },
        { label: 'Disponibles', value: disponibles, icon: 'fas fa-check-circle', color: '#28a745' },
        { label: 'Capacité totale', value: totalCapa + ' élèves', icon: 'fas fa-users', color: '#ffc107' }
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

function renderSallesTable() {
    var tbody = document.getElementById('sallesTableBody');
    if (!tbody) return;

    var startIndex = (STATE.currentPage - 1) * STATE.rowsPerPage;
    var endIndex = startIndex + STATE.rowsPerPage;
    var pageSalles = STATE.filteredSalles.slice(startIndex, endIndex);
    var totalPages = Math.ceil(STATE.filteredSalles.length / STATE.rowsPerPage);

    tbody.innerHTML = '';

    if (!pageSalles.length) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding: 60px;">' +
            '<i class="fas fa-search" style="font-size: 48px; color: #ccc; margin-bottom: 15px; display: block;"></i>' +
            'Aucune salle trouvée</td></tr>';
        return;
    }

    pageSalles.forEach(function(s, idx) {
        var row = tbody.insertRow();
        var globalIndex = startIndex + idx + 1;
        var date = s.CREATED_AT ? new Date(s.CREATED_AT).toLocaleDateString('fr-FR') : '—';
        var isDispo = (s.STATUT === true || s.STATUT === 1 || s.STATUT === '1' || s.STATUT === 'True');

        // Index
        var cellIndex = row.insertCell(0);
        cellIndex.style.textAlign = 'center';
        cellIndex.style.verticalAlign = 'middle';
        cellIndex.style.color = '#888';
        cellIndex.style.fontSize = '12px';
        cellIndex.innerHTML = globalIndex;

        // Numéro
        var cellNumero = row.insertCell(1);
        cellNumero.style.textAlign = 'center';
        cellNumero.style.verticalAlign = 'middle';
        cellNumero.innerHTML = `
            <span style="background:#e8f4fd;color:#0c5460;padding:3px 12px;border-radius:15px;font-size:12px;font-weight:600;border:1px solid #bee5eb;display:inline-block;min-width:80px;">
                <i class="fas fa-door-open" style="margin-right:5px;"></i> ${escHtml(s.NUMERO)}
            </span>`;

        // Capacité
        var cellCapacite = row.insertCell(2);
        cellCapacite.style.textAlign = 'center';
        cellCapacite.style.verticalAlign = 'middle';
        cellCapacite.innerHTML = `<strong>${escHtml(String(s.CAPACITE))}</strong>`;

        // Statut
        var cellStatut = row.insertCell(3);
        cellStatut.style.textAlign = 'center';
        cellStatut.style.verticalAlign = 'middle';
        cellStatut.innerHTML = isDispo
            ? '<span style="background:#d4edda;color:#155724;padding:3px 12px;border-radius:15px;font-size:11px;font-weight:600;border:1px solid #c3e6cb;display:inline-block;min-width:90px;">Disponible</span>'
            : '<span style="background:#f8d7da;color:#721c24;padding:3px 12px;border-radius:15px;font-size:11px;font-weight:600;border:1px solid #f5c6cb;display:inline-block;min-width:90px;">Indisponible</span>';

        // Date
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
            <button type="button" class="btn btn-sm btn-primary" style="margin:0 2px;" onclick="editSalle('${s.ID}')" title="Modifier">
                <i class="fas fa-edit"></i>
            </button>
            <button type="button" class="btn btn-sm btn-danger" style="margin:0 2px;" onclick="deleteSalle('${s.ID}','${escHtml(s.NUMERO).replace(/'/g, "\\'")}')" title="Supprimer">
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
    var container = document.getElementById('sallesPagination');
    if (!container) {
        container = document.createElement('div');
        container.id = 'sallesPagination';
        container.style.marginTop = '15px';
        container.style.textAlign = 'center';
        var parent = document.querySelector('.dash-card-body');
        if (parent) parent.appendChild(container);
    }

    if (totalPages <= 1) {
        container.innerHTML = '';
        return;
    }

    var html = '<nav aria-label="Pagination"><ul class="pagination justify-content-center" style="margin:0;">';
    html += '<li class="page-item ' + (STATE.currentPage === 1 ? 'disabled' : '') + '">';
    html += '<a class="page-link" href="#" onclick="goToPage(' + (STATE.currentPage - 1) + ');return false;">&laquo;</a></li>';
    for (var i = 1; i <= totalPages; i++) {
        html += '<li class="page-item ' + (i === STATE.currentPage ? 'active' : '') + '">';
        html += '<a class="page-link" href="#" onclick="goToPage(' + i + ');return false;">' + i + '</a></li>';
    }
    html += '<li class="page-item ' + (STATE.currentPage === totalPages ? 'disabled' : '') + '">';
    html += '<a class="page-link" href="#" onclick="goToPage(' + (STATE.currentPage + 1) + ');return false;">&raquo;</a></li>';
    html += '</ul></nav>';
    container.innerHTML = html;
}

function goToPage(page) {
    var totalPages = Math.ceil(STATE.filteredSalles.length / STATE.rowsPerPage);
    if (page < 1 || page > totalPages) return;
    STATE.currentPage = page;
    renderSallesTable();
}

// ─────────────────────────────────────────────
// EXPORT CSV
// ─────────────────────────────────────────────
function exportSalles() {
    if (STATE.sallesData.length === 0) {
        alert('Aucune donnée à exporter.');
        return;
    }

    showSpinner();
    setTimeout(function() {
        try {
            var header = ['ID', 'Numéro', 'Capacité', 'Statut', 'Créé le'];
            var rows = STATE.sallesData.map(function(s) {
                var date = s.CREATED_AT ? new Date(s.CREATED_AT).toLocaleDateString('fr-FR') : '';
                var statut = (s.STATUT === true || s.STATUT === 1 || s.STATUT === '1' || s.STATUT === 'True')
                    ? 'Disponible' : 'Indisponible';
                return [s.ID, s.NUMERO, s.CAPACITE, statut, date]
                    .map(function(v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; })
                    .join(',');
            });
            var csv = [header.join(',')].concat(rows).join('\r\n');
            var blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = 'salles_export_' + dateDuJour() + '.csv';
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

// Expositions globales
window.exportSalles = exportSalles;
window.goToPage = goToPage;
window.renderSallesStats = renderSallesStats;
window.renderSallesTable = renderSallesTable;