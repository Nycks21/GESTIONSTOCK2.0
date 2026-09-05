// Définition globale de sortData (accessible avant le DOM ready)
window.sortData = function (field) {
    if (AppState.sortField === field) {
        AppState.sortOrder = AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC';
    } else {
        AppState.sortField = field;
        AppState.sortOrder = 'ASC';
    }
    loadEntrees();
};

$(document).ready(function () {
    loadDropdownsEntree().then(function () {
        loadEntrees();
        initUIControls();
    });

    // Filtres
    $('#search-filter').on('input', debounce(function () {
        AppState.filters.search = this.value.trim();
        AppState.page = 1;
        applyFiltersEntree();
    }, 350));

    $('#fournisseur-filter').on('change', function () {
        AppState.filters.fournisseur = this.value;
        AppState.page = 1;
        applyFiltersEntree();
    });

    $('#statut-filter').on('change', function () {
        AppState.filters.statut = this.value;
        AppState.page = 1;
        applyFiltersEntree();
    });

    $('#btnResetFilters').on('click', function () {
        resetFiltersEntree();
    });

    // Gestion des modales (fermeture par clic sur la croix)
    $('.modal .close').on('click', function () {
        $(this).closest('.modal').hide();
    });

    // Import (si nécessaire)
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
    window.launchImport = async function () {
        // À implémenter si nécessaire (similaire à articles)
    };
});

function applyFiltersEntree() {
    AppState.page = 1;
    loadEntrees({ silent: true });
}

function resetFiltersEntree() {
    document.getElementById('search-filter').value = '';
    document.getElementById('fournisseur-filter').value = '';
    document.getElementById('statut-filter').value = '';
    AppState.filters = { search: '', fournisseur: '', statut: '' };
    AppState.page = 1;
    loadEntrees({ silent: true });
}

// Expositions globales
window.applyFiltersEntree = applyFiltersEntree;
window.resetFiltersEntree = resetFiltersEntree;
