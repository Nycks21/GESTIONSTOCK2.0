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
        if (e) { e.preventDefault(); e.stopPropagation(); }
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

    document.getElementById('excelFile').addEventListener('change', function (e) {
        const file = e.target.files[0];
        const display = document.getElementById('fileNameDisplay');
        const button = document.getElementById('btnLaunchImport');
        if (file) {
            display.value = file.name;
            button.disabled = false;
        } else {
            display.value = '';
            button.disabled = true;
        }
    });

    window.launchImport = async function () {
        const fileInput = document.getElementById('excelFile');
        if (!fileInput || !fileInput.files.length) return;
        const formData = new FormData();
        formData.append('file', fileInput.files[0]);
        try {
            showSpinner();
            const response = await fetch(API.BASE + API.HANDLERS_PATH + 'ArticlesImport.ashx', {
                method: 'POST',
                body: formData
            });
            const result = await response.json();
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
