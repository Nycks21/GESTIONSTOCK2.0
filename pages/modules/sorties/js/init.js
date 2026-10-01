// ============================================================
// INITIALISATION DE LA PAGE
// ============================================================

window.sortData = function (field) {
    if (AppState.sortField === field) {
        AppState.sortOrder = AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC';
    } else {
        AppState.sortField = field;
        AppState.sortOrder = 'ASC';
    }
    loadSorties();
};

$(document).ready(function () {
    // Chargement initial : dropdowns → liste → handlers UI
    loadDropdownsSortie().then(function () {
        loadSorties();
        initUIControls();   // ✅ gère TOUS les handlers filtres/tri/page
    });

    // ✅ Fermeture des modales via bouton × — utilise les vraies fonctions
    //    (évite que le body reste en overflow:hidden)
    $(document).on('click', '.modal .close', function () {
        var $modal = $(this).closest('.modal');
        var modalId = $modal.attr('id');

        if (modalId === 'sortieModal' && typeof closeSortieModal === 'function') {
            closeSortieModal();
        } else if (modalId === 'modalImport' && typeof closeImportModal === 'function') {
            closeImportModal();
        } else {
            $modal.hide();
            document.body.style.overflow = '';
        }
    });

    // ─── Import Excel (optionnel) ───
    window.openImportModal = function (e) {
        if (e) e.preventDefault();
        var m = document.getElementById('modalImport');
        if (m) m.style.display = 'flex';
        document.body.style.overflow = 'hidden';

        var f = document.getElementById('excelFile');
        var d = document.getElementById('fileNameDisplay');
        var b = document.getElementById('btnLaunchImport');
        if (f) f.value = '';
        if (d) d.value = '';
        if (b) b.disabled = true;
    };

    window.closeImportModal = function () {
        var m = document.getElementById('modalImport');
        if (m) m.style.display = 'none';
        document.body.style.overflow = '';

        var f = document.getElementById('excelFile');
        var d = document.getElementById('fileNameDisplay');
        var b = document.getElementById('btnLaunchImport');
        if (f) f.value = '';
        if (d) d.value = '';
        if (b) b.disabled = true;
    };

    window.launchImport = function () {
        // À implémenter si nécessaire
    };
});

// ============================================================
// FONCTIONS DE FILTRAGE (exposées pour les onclick HTML)
// ============================================================

function applyFiltersSortie() {
    AppState.page = 1;
    loadSorties({ silent: true });
}

function resetFiltersSortie() {
    var s = document.getElementById('search-filter');
    var d = document.getElementById('destination-filter');
    var t = document.getElementById('statut-filter');
    if (s) s.value = '';
    if (d) d.value = '';
    if (t) t.value = '';
    AppState.filters = { search: '', destination: '', statut: '' };
    AppState.page = 1;
    loadSorties({ silent: true });
}

window.applyFiltersSortie = applyFiltersSortie;
window.resetFiltersSortie = resetFiltersSortie;
