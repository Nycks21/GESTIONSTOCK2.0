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

    window.openImportModal = function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        document.getElementById('modalImport').style.display = 'flex';
        var excelInput = document.getElementById('excelFile');
        var fileNameDisplay = document.getElementById('fileNameDisplay');
        var importButton = document.getElementById('btnLaunchImport');
        if (excelInput) excelInput.value = '';
        if (fileNameDisplay) fileNameDisplay.value = '';
        if (importButton) importButton.disabled = true;
    };

    window.closeImportModal = function () {
        var modal = document.getElementById('modalImport');
        if (modal) modal.style.display = 'none';
        var excelInput = document.getElementById('excelFile');
        var fileNameDisplay = document.getElementById('fileNameDisplay');
        var importButton = document.getElementById('btnLaunchImport');
        if (excelInput) excelInput.value = '';
        if (fileNameDisplay) fileNameDisplay.value = '';
        if (importButton) importButton.disabled = true;
    };

    var excelInput = document.getElementById('excelFile');
    if (excelInput) {
        excelInput.addEventListener('change', function (e) {
            var file = e.target.files[0];
            var display = document.getElementById('fileNameDisplay');
            var button = document.getElementById('btnLaunchImport');
            if (file) {
                if (display) display.value = file.name;
                if (button) button.disabled = false;
            } else {
                if (display) display.value = '';
                if (button) button.disabled = true;
            }
        });
    }

    window.launchImport = async function () {
        var fileInput = document.getElementById('excelFile');
        if (!fileInput || !fileInput.files.length) return;

        var formData = new FormData();
        formData.append('file', fileInput.files[0]);

        try {
            showSpinner();
            var response = await fetch(API.BASE + API.HANDLERS_PATH + 'ArticlesImport.ashx', {
                method: 'POST',
                body: formData
            });
            var result = await response.json();
            if (result.success) {
                showToast('Succès', result.imported + ' articles importés', 'success');
                closeImportModal();
                loadArticles();
                loadStats();
            } else {
                showToast('Erreur', result.message || 'Échec de l\'import', 'error');
            }
        } catch (error) {
            showToast('Erreur', error.message, 'error');
        } finally {
            hideSpinner();
        }
    };
});

function resetFilters() {
    var searchInput = document.getElementById('search-filter');
    var categorySelect = document.getElementById('category-filter');
    var statusSelect = document.getElementById('status-filter');

    if (searchInput) searchInput.value = '';
    if (categorySelect) categorySelect.value = '';
    if (statusSelect) statusSelect.value = '';

    AppState.filters = { search: '', category: '', status: '' };
    AppState.page = 1;
    loadArticles();
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
