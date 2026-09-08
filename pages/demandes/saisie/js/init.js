$(document).ready(function () {
    // Charger les articles pour les lignes du modal
    loadArticlesForSaisie().then(function () {
        // Initialiser les contrôles UI
        initUIControls();
        // Charger les demandes de l'utilisateur
        loadDemandes();
        // Charger les statistiques
        loadDemandesStats();
    });

    // Filtres
    $('#search-filter').on('input', debounce(function () {
        AppState.filters.search = this.value.trim();
        AppState.page = 1;
        applyFilters();
    }, 350));

    $('#statut-filter').on('change', function () {
        AppState.filters.statut = this.value;
        AppState.page = 1;
        applyFilters();
    });

    $('#btnResetFilters').on('click', function () {
        resetFilters();
    });

    // Fermeture du modal par la croix
    $('.modal .close').on('click', function () {
        $(this).closest('.modal').hide();
    });

    // Tri
    window.sortData = function (field) {
        if (AppState.sortField === field) {
            AppState.sortOrder = AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC';
        } else {
            AppState.sortField = field;
            AppState.sortOrder = 'ASC';
        }
        loadDemandes();
    };
});

function applyFilters() {
    AppState.page = 1;
    loadDemandes({ silent: true });
}

function resetFilters() {
    document.getElementById('search-filter').value = '';
    document.getElementById('statut-filter').value = '';
    AppState.filters = { search: '', statut: '' };
    AppState.page = 1;
    loadDemandes({ silent: true });
}

window.applyFilters = applyFilters;
window.resetFilters = resetFilters;
