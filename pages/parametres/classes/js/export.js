'use strict';

// Export des classes en CSV

function exportClasses() {
    if (!STATE.classesData.length) {
        showErrorToast('Aucune donnée à exporter.', '');
        return;
    }

    showSpinner();

    setTimeout(function() {
        try {
            var header = ['ID', 'Classe', 'Niveau', 'Effectif', 'Titulaire', 'Salle', 'Statut'];
            var rows = STATE.classesData.map(function(c) {
                return [
                    c.ID,
                    c.NOM,
                    c.NIVEAU || '',
                    c.EFFECTIF,
                    c.TITULAIRE || '',
                    c.SALLE || '',
                    c.STATUT ? 'Actif' : 'Inactif'
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
            a.download = 'Classes_export_' + dateDuJour() + '.csv';
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
window.exportClasses = exportClasses;