// init.js
$(document).ready(function () {
    loadUnites();
    loadStats();
    initUIControls();

    $('#search-filter').on('input', debounce(function () {
        AppState.filters.search = (this.value || '').trim();
        AppState.page = 1;
        applyFilters();
    }, 350));

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
        loadUnites();
    };
});

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
