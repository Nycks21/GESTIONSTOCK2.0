'use strict';

function formatNumber(value) {
    if (value === undefined || value === null) return '';
    const num = parseFloat(value);
    return isNaN(num) ? '' : num.toFixed(2);
}

function buildExportRowsFromArticles(articles) {
    const rows = [['CODE', 'NOM', 'CATÉGORIE', 'FOURNISSEUR', 'UNITÉ', 'STOCK TOTAL', 'SEUIL ALERTE', 'STATUT']];
    const data = articles || (typeof AppState !== 'undefined' && AppState.articles) || [];
    data.forEach(a => {
        rows.push([
            a.CODE || '',
            a.NOM || '',
            a.CATEGORIE_NOM || '',
            a.FOURNISSEUR_NOM || '',
            a.UNITE_SYMBOLE || a.UNITE || '',
            formatNumber(a.STOCK_TOTAL),
            formatNumber(a.SEUIL_ALERTE),
            a.STATUT_STOCK || ''
        ]);
    });
    return rows;
}

function exportArticlesToExcelOnly() {
    const articles = (typeof AppState !== 'undefined' && AppState.articles) || [];
    if (!articles.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    const ws = XLSX.utils.aoa_to_sheet(buildExportRowsFromArticles(articles));
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Articles');
    XLSX.writeFile(wb, 'articles_' + new Date().toISOString().slice(0,10) + '.xlsx');
}

function exportArticlesToCsvOnly() {
    const articles = (typeof AppState !== 'undefined' && AppState.articles) || [];
    if (!articles.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    const rows = buildExportRowsFromArticles(articles);
    const csvContent = rows.map(row => {
        return row.map(cell => {
            const value = String(cell).replace(/"/g, '""');
            return /[",;\n]/.test(value) ? '"' + value + '"' : value;
        }).join(';');
    }).join('\n');
    const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'articles_' + new Date().toISOString().slice(0,10) + '.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
}

window.exportArticlesPDF = function() {
    const articles = (typeof AppState !== 'undefined' && AppState.articles) || [];
    if (!articles.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        const head = [['CODE', 'NOM', 'CATÉGORIE', 'FOURNISSEUR', 'UNITÉ', 'STOCK TOTAL', 'SEUIL', 'STATUT']];
        const body = articles.map(a => [
            a.CODE || '', a.NOM || '', a.CATEGORIE_NOM || '', a.FOURNISSEUR_NOM || '',
            a.UNITE_SYMBOLE || a.UNITE || '', formatNumber(a.STOCK_TOTAL),
            formatNumber(a.SEUIL_ALERTE), a.STATUT_STOCK || ''
        ]);
        doc.text('Liste des articles', 14, 12);
        doc.autoTable({
            head,
            body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [0,123,255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Articles_' + new Date().toISOString().slice(0,10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
};

window.exportArticlesToExcelOnly = exportArticlesToExcelOnly;
window.exportArticlesToCsvOnly = exportArticlesToCsvOnly;
