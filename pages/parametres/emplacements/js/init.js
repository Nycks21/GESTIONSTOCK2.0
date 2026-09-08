$(document).ready(function () {
    loadDropdowns().then(function() {
        loadEmplacements();
        loadStats();
        initUIControls();
    });

    $('#search-filter').on('input', debounce(function() {
        AppState.filters.search = (this.value || '').trim();
        AppState.page = 1;
        applyFilters();
    }, 350));

    $('#btnResetFilters').on('click', function() {
        resetFilters();
    });

    $('.modal .close').on('click', function() {
        $(this).closest('.modal').hide();
    });

    window.sortData = function(field) {
        if (AppState.sortField === field) {
            AppState.sortOrder = (AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC');
        } else {
            AppState.sortField = field;
            AppState.sortOrder = 'ASC';
        }
        loadEmplacements();
    };
});

function debounce(fn, delay) {
    var timer;
    return function() {
        var args = arguments;
        clearTimeout(timer);
        timer = setTimeout(function() {
            fn.apply(this, args);
        }.bind(this), delay);
    };
}

function resetFilters() {
    document.getElementById('search-filter').value = '';
    document.getElementById('type-filter').value = '';
    document.getElementById('parent-filter').value = '';
    AppState.filters = { search: '', type: '', parent: '' };
    AppState.page = 1;
    loadEmplacements({ silent: true });
}
