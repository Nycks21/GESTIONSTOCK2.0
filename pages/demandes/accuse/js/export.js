// ============================================================
// EXPORT DES DONNÉES (EXCEL / PDF) - ACCUSE
// ============================================================

function buildAccuseExportRows() {
    var rows = [['N°', 'Date', 'Destination', 'Bénéficiaire', 'Fonction', 'Statut', 'Notes']];
    AppState.sorties.forEach(function (s) {
        rows.push([
            s.NUMERO || '',
            s.DATE_SORTIE ? new Date(s.DATE_SORTIE).toLocaleString() : '',
            s.DESTINATION || '',
            s.NOM || '',
            s.FONCTION || '',
            s.STATUT || '',
            s.NOTES || ''
        ]);
    });
    return rows;
}

function exportAccuseToExcelOnly() {
    if (!AppState.sorties.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildAccuseExportRows());
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Accuses');
    XLSX.writeFile(wb, 'accuses_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportAccusePDF() {
    if (!AppState.sorties.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        var jsPDF = window.jspdf.jsPDF;
        var doc = new jsPDF('l', 'mm', 'a4');
        var head = [['N°', 'Date', 'Destination', 'Bénéficiaire', 'Fonction', 'Statut']];
        var body = AppState.sorties.map(function (s) {
            return [
                s.NUMERO || '',
                s.DATE_SORTIE ? new Date(s.DATE_SORTIE).toLocaleString() : '',
                s.DESTINATION || '',
                s.NOM || '',
                s.FONCTION || '',
                s.STATUT || ''
            ];
        });
        doc.text('Liste des accusés de réception', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [40, 167, 69] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Accuses_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
}

window.exportAccuseToExcelOnly = exportAccuseToExcelOnly;
window.exportAccusePDF = exportAccusePDF;
