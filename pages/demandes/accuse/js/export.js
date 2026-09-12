// ============================================================
// EXPORT DES DONNÉES (EXCEL / PDF) - ACCUSE
// ============================================================

// ✅ Formate une date SQL (peut être ISO, /Date(...)/, ou null)
function formatDateForExport(value) {
    if (value === null || value === undefined || value === "") return '';
    try {
        var dateValue = String(value);
        var dotNetDate = dateValue.match(/^\/Date\((-?\d+)\)\/$/);
        var d = dotNetDate ? new Date(Number(dotNetDate[1])) : new Date(dateValue);
        if (isNaN(d.getTime())) return '';
        var pad = function (v) { return String(v).padStart(2, '0'); };
        return pad(d.getDate()) + '/' + pad(d.getMonth() + 1) + '/' + d.getFullYear();
    } catch (e) {
        return '';
    }
}

function buildAccuseExportRows() {
    var rows = [[
        'N°', 'Date sortie', 'Date réception', 'Destination',
        'Bénéficiaire', 'Fonction', 'Statut', 'Notes'
    ]];
    AppState.sorties.forEach(function (s) {
        rows.push([
            s.NUMERO || '',
            formatDateForExport(s.DATE_SORTIE),
            formatDateForExport(s.DATE_RECEPTION),
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
        var head = [['N°', 'Date sortie', 'Date réception', 'Destination', 'Bénéficiaire', 'Fonction', 'Statut']];
        var body = AppState.sorties.map(function (s) {
            return [
                s.NUMERO || '',
                formatDateForExport(s.DATE_SORTIE),
                formatDateForExport(s.DATE_RECEPTION),
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
