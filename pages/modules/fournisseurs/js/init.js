// init.js
$(document).ready(function () {
    loadFournisseurs();
    loadFournisseurStats();
    initUIControls();

    $('#search-filter').on('input', debounce(function () {
        AppState.filters.search = (this.value || '').trim();
        AppState.page = 1;
        applyFilters();
    }, 350));

    $('#actif-filter').on('change', function () {
        AppState.filters.actif = this.value || '';
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
        loadFournisseurs();
    };
});

function resetFilters() {
    document.getElementById('search-filter').value = '';
    document.getElementById('actif-filter').value = '';
    AppState.filters = { search: '', actif: '' };
    AppState.page = 1;
    loadFournisseurs({ silent: true });
}

function debounce(fn, delay) {
    var timer;
    return function () {
        var args = arguments;
        clearTimeout(timer);
        timer = setTimeout(function () {
            fn.apply(this, args);
        }.bind(this), delay);
    };
}
