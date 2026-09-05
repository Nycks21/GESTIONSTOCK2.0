// export.js
'use strict';

function formatNumber(value) {
    if (value === undefined || value === null) return '';
    var num = parseFloat(value);
    return isNaN(num) ? '' : num.toFixed(2);
}

function buildExportRowsFromUnites(unites) {
    var rows = [['CODE', 'NOM', 'STATUT']];
    var data = unites || (typeof AppState !== 'undefined' && AppState.unites) || [];
    data.forEach(function (u) {
        rows.push([
            u.CODE || '',
            u.NOM || '',
            u.ACTIVE ? 'Actif' : 'Inactif'
        ]);
    });
    return rows;
}

function exportUnitesToExcelOnly() {
    var unites = (typeof AppState !== 'undefined' && AppState.unites) || [];
    if (!unites.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRowsFromUnites(unites));
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Unites');
    XLSX.writeFile(wb, 'unites_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportUnitesToCsvOnly() {
    var unites = (typeof AppState !== 'undefined' && AppState.unites) || [];
    if (!unites.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var rows = buildExportRowsFromUnites(unites);
    var csvContent = rows.map(function (row) {
        return row.map(function (cell) {
            var value = String(cell).replace(/"/g, '""');
            return /[",;\n]/.test(value) ? '"' + value + '"' : value;
        }).join(';');
    }).join('\n');

    var blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    var link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'unites_' + new Date().toISOString().slice(0, 10) + '.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
}

window.exportUnitesPDF = function () {
    var unites = (typeof AppState !== 'undefined' && AppState.unites) || [];
    if (!unites.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        const head = [['CODE', 'NOM', 'STATUT']];
        const body = unites.map(function (u) {
            return [u.CODE || '', u.NOM || '', u.ACTIVE ? 'Actif' : 'Inactif'];
        });
        doc.text('Liste des unités de mesure', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Unites_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
};

window.exportUnitesToExcelOnly = exportUnitesToExcelOnly;
window.exportUnitesToCsvOnly = exportUnitesToCsvOnly;
