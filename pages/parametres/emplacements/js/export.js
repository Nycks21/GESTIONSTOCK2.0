'use strict';

function formatNumber(value) {
    if (value === undefined || value === null) return '';
    var num = parseFloat(value);
    return isNaN(num) ? '' : num.toFixed(2);
}

function buildExportRows(emplacements) {
    var rows = [['CODE', 'NOM', 'TYPE', 'PARENT', 'STATUT']];
    var data = emplacements || (typeof AppState !== 'undefined' && AppState.emplacements) || [];
    data.forEach(function(e) {
        rows.push([
            e.CODE || '',
            e.NOM || '',
            e.TYPE || '',
            e.PARENT_NOM || '',
            e.ACTIVE ? 'Actif' : 'Inactif'
        ]);
    });
    return rows;
}

function exportEmplacementsToExcelOnly() {
    var emplacements = (typeof AppState !== 'undefined' && AppState.emplacements) || [];
    if (!emplacements.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRows(emplacements));
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Emplacements');
    XLSX.writeFile(wb, 'emplacements_' + new Date().toISOString().slice(0,10) + '.xlsx');
}

window.exportEmplacementsPDF = function() {
    var emplacements = (typeof AppState !== 'undefined' && AppState.emplacements) || [];
    if (!emplacements.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        const head = [['CODE', 'NOM', 'TYPE', 'PARENT', 'STATUT']];
        const body = emplacements.map(function(e) {
            return [
                e.CODE || '',
                e.NOM || '',
                e.TYPE || '',
                e.PARENT_NOM || '',
                e.ACTIVE ? 'Actif' : 'Inactif'
            ];
        });
        doc.text('Liste des emplacements', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Emplacements_' + new Date().toISOString().slice(0,10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
};

window.exportEmplacementsToExcelOnly = exportEmplacementsToExcelOnly;
