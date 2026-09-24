$(document).ready(function () {
    loadDropdowns().then(function () {
        loadArticles();
        loadStats();
        initUIControls();
    });

    $('#search-filter').on('input', debounce(function () {
        AppState.filters.search = (this.value || '').trim();
        AppState.page = 1;
        applyFilters();
    }, 350));

    $('#category-filter').on('change', function () {
        AppState.filters.category = this.value || '';
        AppState.page = 1;
        applyFilters();
    });

    $('#status-filter').on('change', function () {
        AppState.filters.status = this.value || '';
        AppState.page = 1;
        applyFilters();
    });

    $('#btnResetFilters').on('click', function () {
        resetFilters();
    });

    $('.modal .close').on('click', function () {
        $(this).closest('.modal').hide();
    });

    window.sortData = function (field) {
        if (AppState.sortField === field) {
            AppState.sortOrder = AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC';
        } else {
            AppState.sortField = field;
            AppState.sortOrder = 'ASC';
        }
        loadArticles();
    };

    // ============================================================
    // NOTE : le modal d'importation des articles est géré
    // dans js/import.js (wizard multi-étapes).
    // Les fonctions openImportModal / closeImportModal / launchImport
    // y sont exposées globalement.
    // ============================================================
});

function resetFilters() {
    document.getElementById('search-filter').value = '';
    document.getElementById('category-filter').value = '';
    document.getElementById('status-filter').value = '';
    AppState.filters = { search: '', category: '', status: '' };
    AppState.page = 1;
    loadArticles();
}

function debounce(fn, delay) {
    let timer;
    return function () {
        const args = arguments;
        clearTimeout(timer);
        timer = setTimeout(() => fn.apply(this, args), delay);
    };
}
