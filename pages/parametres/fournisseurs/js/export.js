'use strict';

function formatNumber(value) {
    if (value === undefined || value === null) return '';
    var num = parseFloat(value);
    return isNaN(num) ? '' : num.toFixed(2);
}

function buildExportRowsFromFournisseurs(fournisseurs) {
    var rows = [['CODE', 'NOM', 'ADRESSE', 'TÉLÉPHONE', 'EMAIL', 'CONTACT', 'TÉL. CONTACT', 'SIRET', 'STATUT']];
    var data = fournisseurs || (typeof AppState !== 'undefined' && AppState.fournisseurs) || [];
    data.forEach(function (f) {
        rows.push([
            f.CODE || '',
            f.NOM || '',
            f.ADRESSE || '',
            f.TELEPHONE || '',
            f.EMAIL || '',
            f.CONTACT_NOM || '',
            f.CONTACT_TELEPHONE || '',
            f.SIRET || '',
            f.ACTIVE ? 'Actif' : 'Inactif'
        ]);
    });
    return rows;
}

function exportFournisseursToExcelOnly() {
    var fournisseurs = (typeof AppState !== 'undefined' && AppState.fournisseurs) || [];
    if (!fournisseurs.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRowsFromFournisseurs(fournisseurs));
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Fournisseurs');
    XLSX.writeFile(wb, 'fournisseurs_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportFournisseursToCsvOnly() {
    var fournisseurs = (typeof AppState !== 'undefined' && AppState.fournisseurs) || [];
    if (!fournisseurs.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var rows = buildExportRowsFromFournisseurs(fournisseurs);
    var csvContent = rows.map(function (row) {
        return row.map(function (cell) {
            var value = String(cell).replace(/"/g, '""');
            return /[",;\n]/.test(value) ? '"' + value + '"' : value;
        }).join(';');
    }).join('\n');
    var blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    var link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'fournisseurs_' + new Date().toISOString().slice(0, 10) + '.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
}

window.exportFournisseursPDF = function () {
    var fournisseurs = (typeof AppState !== 'undefined' && AppState.fournisseurs) || [];
    if (!fournisseurs.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        const head = [['CODE', 'NOM', 'ADRESSE', 'TÉLÉPHONE', 'EMAIL', 'CONTACT', 'TÉL. CONTACT', 'SIRET', 'STATUT']];
        const body = fournisseurs.map(function (f) {
            return [
                f.CODE || '', f.NOM || '', f.ADRESSE || '',
                f.TELEPHONE || '', f.EMAIL || '', f.CONTACT_NOM || '',
                f.CONTACT_TELEPHONE || '', f.SIRET || '',
                f.ACTIVE ? 'Actif' : 'Inactif'
            ];
        });
        doc.text('Liste des fournisseurs', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Fournisseurs_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
};

window.exportFournisseursToExcelOnly = exportFournisseursToExcelOnly;
window.exportFournisseursToCsvOnly = exportFournisseursToCsvOnly;
