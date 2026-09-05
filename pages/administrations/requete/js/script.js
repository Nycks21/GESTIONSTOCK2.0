// ── État de la pagination (Inchangé) ──────────────────────────────────────────
var sqlCurrentPage = 1;
var sqlRowsPerPage = 10;
var sqlAllData = [];
var sqlAllColumns = [];

// ── Fonction de conversion (Inchangé) ────────────────────────────────────────
function formatNetDate(jsonDate) {
    if (typeof jsonDate !== 'string') return jsonDate;
    var regex = /\/Date\((\d+)\)\//;
    var match = jsonDate.match(regex);
    if (match) {
        var date = new Date(parseInt(match[1], 10));
        return ("0" + date.getDate()).slice(-2) + "/" + ("0" + (date.getMonth() + 1)).slice(-2) + "/" + date.getFullYear() + " " + ("0" + date.getHours()).slice(-2) + ":" + ("0" + date.getMinutes()).slice(-2) + ":" + ("0" + date.getSeconds()).slice(-2);
    }
    return jsonDate;
}

// ── Logique d'exécution (Inchangée) ──────────────────────────────────────────
function executeCustomSQL() {
    var queryArea = document.getElementById('sqlConsole');
    var resultDiv = document.getElementById('sqlExecutionResult');

    if (!queryArea || !queryArea.value.trim()) {
        Swal.fire({ icon: 'error', title: 'Champ vide', text: 'Veuillez saisir une requête.' });
        return;
    }

    var queryText = queryArea.value.trim();

    // On supprime la vérification du mot de passe en dur ici.
    // La sécurité est maintenant gérée par le serveur (ExecuteSQL.ashx).
    lancerExecution();

    function lancerExecution() {
        Swal.fire({
            title: 'Confirmer l\'exécution ?',
            text: 'Action directe sur la base de données.',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Oui, exécuter'
        }).then(function (result) {
            if (!result.isConfirmed) return;

            Swal.showLoading();
            var formData = new URLSearchParams();
            formData.append('query', queryText);

            var sqlHeaders = { 'Content-Type': 'application/x-www-form-urlencoded' };
            var csrf = typeof getCsrfToken === 'function' ? getCsrfToken()
                : (document.querySelector('meta[name="csrf-token"]') || {}).content;
            if (csrf) {
                sqlHeaders['X-CSRF-Token'] = csrf;
            }

            fetch('handlers/ExecuteSQL.ashx', {
                method: 'POST',
                headers: sqlHeaders,
                body: formData
            })
            .then(function (r) { return r.json(); })
            .then(function (res) {
                Swal.close();
                if (res.success) {
                    if (res.type === 'SELECT') {
                        sqlAllData = res.data || [];
                        sqlAllColumns = sqlAllData.length > 0 ? Object.keys(sqlAllData[0]) : [];
                        sqlCurrentPage = 1;
                        renderSqlTablePaged(resultDiv);
                    } else {
                        resultDiv.innerHTML = '<div class="alert alert-success m-2">' + escSql(res.message) + '</div>';
                    }
                } else {
                    // Si le serveur renvoie une erreur (ex: pas autorisé), on l'affiche ici
                    resultDiv.innerHTML = '<div class="alert alert-danger m-2">' + escSql(res.message) + '</div>';
                    if(res.message.includes("Autorisation")) {
                        Swal.fire('Accès refusé', 'Vous n\'avez pas les droits pour cette action.', 'error');
                    }
                }
            })
            .catch(function () {
                Swal.fire('Erreur', 'Erreur de communication avec le serveur.', 'error');
            });
        });
    }
}

// ── Rendu du tableau (LOGIQUE CONSERVÉE + RESIZE) ─────────────────────────────
function renderSqlTablePaged(container) {
    if (!sqlAllData || sqlAllData.length === 0) {
        container.innerHTML = '<div class="p-3">Requête exécutée avec succès.</div>';
        return;
    }

    var start = (sqlCurrentPage - 1) * sqlRowsPerPage;
    var end = Math.min(start + sqlRowsPerPage, sqlAllData.length);
    var pageData = sqlAllData.slice(start, end);

    var controlBar = '<div style="padding:10px; background:#f8f9fa; border-bottom:1px solid #dee2e6; display:flex; justify-content:space-between; align-items:center;">' +
                     '<span>Page ' + sqlCurrentPage + '</span>' +
                     '<select onchange="onRowsPerPageChange(this.value)">' + [10, 20, 50].map(function(n){ return '<option '+(n==sqlRowsPerPage?'selected':'')+'>'+n+'</option>'; }).join('') + '</select></div>';

    var tableHtml =
        '<table style="width:100%; min-width:1200px; border-collapse:collapse; table-layout:fixed; background:#fff;">' +
            '<thead style="background:#343a40; color:#fff;"><tr>' +
                sqlAllColumns.map(function(col) {
                    // Ajout du div "resizer" ici
                    return '<th style="width:150px; padding:12px; text-align:left; border:1px solid #454d55; white-space:nowrap; position:relative;">' +
                             col + '<div class="resizer" style="width:5px; height:100%; position:absolute; top:0; right:0; cursor:col-resize;"></div></th>';
                }).join('') +
            '</tr></thead>' +
            '<tbody>' +
                pageData.map(function(row) {
                    return '<tr>' + sqlAllColumns.map(function(col) {
                        var val = row[col];
                        var display = formatNetDate(val);
                        return '<td style="padding:10px; border:1px solid #dee2e6; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; font-size:13px;">' +
                               (val === null ? '<i>null</i>' : escSql(display)) + '</td>';
                    }).join('') + '</tr>';
                }).join('') +
            '</tbody></table>';

    var pagination = buildPagination(Math.ceil(sqlAllData.length / sqlRowsPerPage));
    var tableWrapper = '<div style="overflow-y:auto; overflow-x:auto; border:1px solid #dee2e6;">' + tableHtml + '</div>';
    container.innerHTML = controlBar + tableWrapper + pagination;

    // Initialisation du resize après l'injection
    initResizers(container);
}

function initResizers(container) {
    container.querySelectorAll('.resizer').forEach(function(resizer) {
        resizer.addEventListener('mousedown', function(e) {
            var th = e.target.parentElement;
            var startX = e.pageX;
            var startWidth = th.offsetWidth;
            function onMouseMove(e) {
                var newWidth = startWidth + (e.pageX - startX);
                if (newWidth > 50) th.style.width = newWidth + 'px';
            }
            function onMouseUp() {
                document.removeEventListener('mousemove', onMouseMove);
                document.removeEventListener('mouseup', onMouseUp);
            }
            document.addEventListener('mousemove', onMouseMove);
            document.addEventListener('mouseup', onMouseUp);
        });
    });
}

// ── Fonctions de Pagination (REPRISES TEL QUEL) ──────────────────────────────
function buildPagination(totalPages) {
    if (totalPages <= 1) return '';
    var html = '<div style="padding:15px; text-align:center; background:#f8f9fa; border-top:1px solid #dee2e6;">';
    for (var i = 1; i <= totalPages; i++) {
        html += '<button onclick="goToPage(' + i + ')" style="margin:2px; padding:6px 12px; border:1px solid #ddd; ' + (i==sqlCurrentPage?'background:#007bff; color:#fff;':'') + '">' + i + '</button>';
    }
    return html + '</div>';
}

function goToPage(p) { sqlCurrentPage = p; renderSqlTablePaged(document.getElementById('sqlExecutionResult')); }
function onRowsPerPageChange(v) { sqlRowsPerPage = parseInt(v); sqlCurrentPage = 1; renderSqlTablePaged(document.getElementById('sqlExecutionResult')); }
function escSql(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }

document.addEventListener('DOMContentLoaded', function () {
    var area = document.getElementById('sqlConsole');
    if (area) area.addEventListener('keydown', function (e) { if (e.ctrlKey && e.key === 'Enter') { e.preventDefault(); executeCustomSQL(); } });
});
