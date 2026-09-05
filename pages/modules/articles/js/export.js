'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT EXCEL / CSV / PDF — s'appuie sur AppState.articles (liste courante)
// ─────────────────────────────────────────────────────────────────────────────

// Formatte un nombre pour l'affichage (2 décimales)
function formatNumber(value) {
    if (value === undefined || value === null) return '';
    var num = parseFloat(value);
    return isNaN(num) ? '' : num.toFixed(2);
}

/**
 * Construit les lignes du tableau à partir des articles
 * @param {Array} articles - Liste d'articles (par défaut AppState.articles)
 * @returns {Array} Lignes pour export (en-tête + données)
 */
function buildExportRowsFromArticles(articles) {
    var rows = [['CODE', 'NOM', 'CATÉGORIE', 'FOURNISSEUR', 'UNITÉ', 'STOCK', 'SEUIL', 'STATUT']];
    var data = articles || (typeof AppState !== 'undefined' && AppState.articles) || [];
    data.forEach(function (a) {
        rows.push([
            a.CODE || '',
            a.NOM || '',
            a.CATEGORIE || '',
            a.FOURNISSEUR || '',
            a.UNITE_SYMBOLE || a.UNITE || '',
            formatNumber(a.STOCK_DISPONIBLE),
            formatNumber(a.SEUIL_ALERTE),
            a.STATUT_STOCK || ''
        ]);
    });
    return rows;
}

/**
 * Export Excel (.xlsx) – utilise la liste courante
 */
function exportArticlesToExcelOnly() {
    var articles = (typeof AppState !== 'undefined' && AppState.articles) || [];
    if (!articles.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRowsFromArticles(articles));
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Articles');
    XLSX.writeFile(wb, 'articles_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

/**
 * Export CSV (.csv) – utilise la liste courante
 */
function exportArticlesToCsvOnly() {
    var articles = (typeof AppState !== 'undefined' && AppState.articles) || [];
    if (!articles.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var rows = buildExportRowsFromArticles(articles);
    var csvContent = rows.map(function (row) {
        return row.map(function (cell) {
            var value = String(cell).replace(/"/g, '""');
            return /[",;\n]/.test(value) ? '"' + value + '"' : value;
        }).join(';');
    }).join('\n');

    var blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    var link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'articles_' + new Date().toISOString().slice(0, 10) + '.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
}

/**
 * Export PDF – utilise la liste courante
 */
window.exportArticlesPDF = function () {
    var articles = (typeof AppState !== 'undefined' && AppState.articles) || [];
    if (!articles.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        const head = [['CODE', 'NOM', 'CATÉGORIE', 'FOURNISSEUR', 'UNITÉ', 'STOCK', 'SEUIL', 'STATUT']];
        const body = articles.map(function (a) {
            return [
                a.CODE || '', a.NOM || '', a.CATEGORIE || '', a.FOURNISSEUR || '',
                a.UNITE_SYMBOLE || a.UNITE || '', formatNumber(a.STOCK_DISPONIBLE),
                formatNumber(a.SEUIL_ALERTE), a.STATUT_STOCK || ''
            ];
        });
        doc.text('Liste des articles', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Articles_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
};

// Exposer les fonctions pour les appels onclick
window.exportArticlesToExcelOnly = exportArticlesToExcelOnly;
window.exportArticlesToCsvOnly = exportArticlesToCsvOnly;
