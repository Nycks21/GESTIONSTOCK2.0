function buildEntreeExportRows() {
    var rows = [['N°', 'Date', 'Fournisseur', 'Statut', 'Total HT', 'Total TTC', 'Référence', 'Notes']];
    AppState.entrees.forEach(function (e) {
        rows.push([
            e.NUMERO || '',
            window.formatDateValue ? window.formatDateValue(e.DATE_ENTREE, true) : '-',
            e.FOURNISSEUR || '',
            e.STATUT || '',
            e.TOTAL_HT ? e.TOTAL_HT.toFixed(2) : '0.00',
            e.TOTAL_TTC ? e.TOTAL_TTC.toFixed(2) : '0.00',
            e.REFERENCE || '',
            e.NOTES || ''
        ]);
    });
    return rows;
}

function exportEntreesToExcelOnly() {
    if (!AppState.entrees.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildEntreeExportRows());
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'BonsEntree');
    XLSX.writeFile(wb, 'bons_entree_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportEntreesPDF() {
    if (!AppState.entrees.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        var jsPDF = window.jspdf.jsPDF;
        var doc = new jsPDF('l', 'mm', 'a4');
        var head = [['N°', 'Date', 'Fournisseur', 'Statut', 'Total HT', 'Total TTC', 'Référence']];
        var body = AppState.entrees.map(function (e) {
            return [
                e.NUMERO || '',
                window.formatDateValue ? window.formatDateValue(e.DATE_ENTREE, true) : '-',
                e.FOURNISSEUR || '',
                e.STATUT || '',
                e.TOTAL_HT ? e.TOTAL_HT.toFixed(2) : '0.00',
                e.TOTAL_TTC ? e.TOTAL_TTC.toFixed(2) : '0.00',
                e.REFERENCE || ''
            ];
        });
        doc.text('Liste des bons d\'entrée', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [40, 167, 69] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('BonsEntree_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
}

// Expositions globales
window.exportEntreesToExcelOnly = exportEntreesToExcelOnly;
window.exportEntreesPDF = exportEntreesPDF;
