'use strict';

function buildExportRows(stock) {
    var rows = [['ARTICLE', 'ENTRÉE', 'SORTIE', 'DISPONIBLE', 'STATUT']];
    var data = stock || (typeof AppState !== 'undefined' && AppState.stock) || [];
    data.forEach(function(s) {
        var disponible = Number(s.DISPONIBLE || 0);
        var statut = '';
        if (disponible <= 0) statut = 'Rupture de stock';
        else if (disponible <= Number(s.SEUIL_ALERTE || 0)) statut = 'Stock faible';
        else statut = 'Normal';
        rows.push([
            (s.ARTICLE_CODE ? s.ARTICLE_CODE + ' - ' : '') + (s.ARTICLE_NOM || ''),
            s.ENTREE || 0,
            s.SORTIE || 0,
            disponible,
            statut
        ]);
    });
    return rows;
}

function exportStockToExcelOnly() {
    var stock = (typeof AppState !== 'undefined' && AppState.stock) || [];
    if (!stock.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRows(stock));
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Stock');
    XLSX.writeFile(wb, 'stock_' + new Date().toISOString().slice(0,10) + '.xlsx');
}

window.exportStockPDF = function() {
    var stock = (typeof AppState !== 'undefined' && AppState.stock) || [];
    if (!stock.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        const head = [['ARTICLE', 'ENTRÉE', 'SORTIE', 'DISPONIBLE', 'STATUT']];
        const body = stock.map(function(s) {
            var disponible = Number(s.DISPONIBLE || 0);
            var statut = '';
            if (disponible <= 0) statut = 'Rupture de stock';
            else if (disponible <= Number(s.SEUIL_ALERTE || 0)) statut = 'Stock faible';
            else statut = 'Normal';
            return [
                (s.ARTICLE_CODE ? s.ARTICLE_CODE + ' - ' : '') + (s.ARTICLE_NOM || ''),
                s.ENTREE || 0,
                s.SORTIE || 0,
                disponible,
                statut
            ];
        });
        doc.text('État du stock', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Stock_' + new Date().toISOString().slice(0,10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
};

window.exportStockToExcelOnly = exportStockToExcelOnly;
