'use strict';

function exportMatieres() {
    if (!STATE.matieresData.length) {
        showErrorToast('Aucune donnée à exporter.', '');
        return;
    }

    showSpinner();

    setTimeout(function() {
        try {
            var header = ['ID', 'Matière', 'Enseignant', 'Classe', 'Coefficient', 'Heures/sem.', 'Créé le'];
            var rows = STATE.matieresData.map(function(m) {
                var date = m.CREATED_AT ? new Date(m.CREATED_AT).toLocaleDateString('fr-FR') : '';
                return [
                    m.ID,
                    m.NOM,
                    m.ENSEIGNANT || '',
                    m.CLASSE_NOM || '',
                    m.COEFFICIENT,
                    m.HEURES_SEMAINE || 0,
                    date
                ];
            });

            var csvContent = header.join(',') + '\r\n' +
                rows.map(function(row) {
                    return row.map(function(v) {
                        return '"' + String(v || '').replace(/"/g, '""') + '"';
                    }).join(',');
                }).join('\r\n');

            var blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = 'Matieres_export_' + dateDuJour() + '.csv';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        } catch (err) {
            showErrorToast('Erreur export', err.message);
        } finally {
            hideSpinner();
        }
    }, 400);
}

// Expositions
window.exportMatieres = exportMatieres;