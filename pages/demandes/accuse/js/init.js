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
    // ✅ Garde : s'assurer que AppState existe avant de démarrer
    if (typeof window.AppState === 'undefined') {
        console.warn('[init.js] AppState absent — attente...');
        setTimeout(function () {
            if (typeof window.AppState !== 'undefined') {
                startAccusePage();
            } else {
                Swal.fire('Erreur', 'État de la page non initialisé (AppState).', 'error');
            }
        }, 150);
        return;
    }
    startAccusePage();
});

function startAccusePage() {
    loadArticlesForAccuse().then(function () {
        loadAccuse();
        initUIControls();
    });

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

    $('.modal .close').on('click', function () {
        $(this).closest('.modal').hide();
    });
}

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
window.startAccusePage = startAccusePage;
