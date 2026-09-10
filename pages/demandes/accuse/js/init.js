// ============================================================
// INITIALISATION DE LA PAGE ACCUSE
// ============================================================

window.sortData = function (field) {
    if (AppState.sortField === field) {
        AppState.sortOrder = AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC';
    } else {
        AppState.sortField = field;
        AppState.sortOrder = 'ASC';
    }
    loadAccuse();
};

$(document).ready(function () {
    // Chargement initial
    loadArticlesForAccuse().then(function () {
        loadAccuse();
        initUIControls();
    });

    // Filtres
    $('#search-filter').on('input', debounce(function () {
        AppState.filters.search = this.value.trim();
        AppState.page = 1;
        applyFilters();
    }, 350));

    $('#destination-filter').on('change', function () {
        AppState.filters.destination = this.value;
        AppState.page = 1;
        applyFilters();
    });

    $('#btnResetFilters').on('click', function () {
        resetFilters();
    });

    // Fermeture des modales par croix
    $('.modal .close').on('click', function () {
        $(this).closest('.modal').hide();
    });
});

function applyFilters() {
    AppState.page = 1;
    loadAccuse({ silent: true });
}

function resetFilters() {
    document.getElementById('search-filter').value = '';
    document.getElementById('destination-filter').value = '';
    AppState.filters = { search: '', destination: '' };
    AppState.page = 1;
    loadAccuse({ silent: true });
}

window.applyFilters = applyFilters;
window.resetFilters = resetFilters;
