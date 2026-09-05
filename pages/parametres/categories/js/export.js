'use strict';

function formatNumber(value) { /* ... */ }

function buildExportRowsFromCategories(categories) {
    var rows = [['CODE', 'NOM', 'CATÉGORIE PARENTE', 'STATUT']];
    var data = categories || (typeof AppState !== 'undefined' && AppState.categories) || [];
    data.forEach(function (c) {
        rows.push([
            c.CODE || '',
            c.NOM || '',
            c.PARENT_NOM || '(Aucune)',
            c.ACTIVE ? 'Actif' : 'Inactif'
        ]);
    });
    return rows;
}

function exportCategoriesToExcelOnly() { /* ... */ }
function exportCategoriesToCsvOnly() { /* ... */ }
window.exportCategoriesPDF = function () { /* ... */ };
window.exportCategoriesToExcelOnly = exportCategoriesToExcelOnly;
window.exportCategoriesToCsvOnly = exportCategoriesToCsvOnly;
