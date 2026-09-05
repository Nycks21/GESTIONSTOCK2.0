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
    // Chargement initial
    loadDropdownsSortie().then(function () {
        loadSorties();
        initUIControls();
    });

    // Filtres
    $('#search-filter').on('input', debounce(function () {
        AppState.filters.search = this.value.trim();
        AppState.page = 1;
        applyFiltersSortie();
    }, 350));

    $('#destination-filter').on('change', function () {
        AppState.filters.destination = this.value;
        AppState.page = 1;
        applyFiltersSortie();
    });

    $('#statut-filter').on('change', function () {
        AppState.filters.statut = this.value;
        AppState.page = 1;
        applyFiltersSortie();
    });

    $('#btnResetFilters').on('click', function () {
        resetFiltersSortie();
    });

    // Fermeture des modales par croix
    $('.modal .close').on('click', function () {
        $(this).closest('.modal').hide();
    });

    // Import (optionnel)
    window.openImportModal = function (e) {
        if (e) e.preventDefault();
        document.getElementById('modalImport').style.display = 'flex';
        document.getElementById('excelFile').value = '';
        document.getElementById('fileNameDisplay').value = '';
        document.getElementById('btnLaunchImport').disabled = true;
    };
    window.closeImportModal = function () {
        document.getElementById('modalImport').style.display = 'none';
        document.getElementById('excelFile').value = '';
        document.getElementById('fileNameDisplay').value = '';
        document.getElementById('btnLaunchImport').disabled = true;
    };
    window.launchImport = function () {
        // À implémenter si nécessaire
    };
});

// ============================================================
// FONCTIONS DE FILTRAGE
// ============================================================

function applyFiltersSortie() {
    AppState.page = 1;
    loadSorties({ silent: true });
}

function resetFiltersSortie() {
    document.getElementById('search-filter').value = '';
    document.getElementById('destination-filter').value = '';
    document.getElementById('statut-filter').value = '';
    AppState.filters = { search: '', destination: '', statut: '' };
    AppState.page = 1;
    loadSorties({ silent: true });
}

window.applyFiltersSortie = applyFiltersSortie;
window.resetFiltersSortie = resetFiltersSortie;
