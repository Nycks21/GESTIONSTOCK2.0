// ============================================================
// EXPORT DES DONNÉES (EXCEL / PDF)
// ============================================================

function buildSortieExportRows() {
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

function exportSortiesToExcelOnly() {
    if (!AppState.sorties.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildSortieExportRows());
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'BonsSortie');
    XLSX.writeFile(wb, 'bons_sortie_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportSortiesPDF() {
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
        doc.text('Liste des bons de sortie', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [220, 53, 69] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('BonsSortie_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
}

window.exportSortiesToExcelOnly = exportSortiesToExcelOnly;
window.exportSortiesPDF = exportSortiesPDF;
