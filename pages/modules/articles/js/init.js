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
    // MODAL IMPORTATION
    // ============================================================
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

    // ============================================================
    // LANCEMENT IMPORT
    // ============================================================
    window.launchImport = async function () {
        const fileInput = document.getElementById('excelFile');
        if (!fileInput || !fileInput.files.length) return;

        const file = fileInput.files[0];

        try {
            showSpinner();

            // 1) Lire le fichier côté client avec SheetJS
            const arrayBuffer = await file.arrayBuffer();
            const workbook = XLSX.read(arrayBuffer, { type: 'array' });
            const sheetName = workbook.SheetNames[0];
            const sheet = workbook.Sheets[sheetName];
            const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });

            if (!rows.length) {
                showToast('Erreur', 'Le fichier est vide', 'error');
                return;
            }

            // 2) Normaliser les lignes (tolérance sur casse / accents / espaces)
            const articles = rows.map(function (r) {
                function pick() {
                    var wanted = Array.prototype.slice.call(arguments);
                    var keys = Object.keys(r);
                    for (var i = 0; i < keys.length; i++) {
                        var k = keys[i].toString()
                            .toUpperCase()
                            .normalize('NFD')
                            .replace(/[\u0300-\u036f]/g, '')
                            .replace(/\s+/g, '_')
                            .trim();
                        for (var j = 0; j < wanted.length; j++) {
                            if (k === wanted[j]) return r[keys[i]];
                        }
                    }
                    return '';
                }

                return {
                    code:         String(pick('CODE') || '').trim(),
                    nom:          String(pick('NOM', 'DESIGNATION', 'LIBELLE') || '').trim(),
                    categorie:    String(pick('CATEGORIE', 'CATEGORY') || '').trim(),
                    unite:        String(pick('UNITE', 'UNITE_MESURE', 'UNIT') || '').trim(),
                    seuilAlerte:  parseFloat(String(pick('SEUIL_ALERTE', 'SEUIL') || '0').replace(',', '.')) || 0,
                    stockInitial: parseFloat(String(pick('STOCK_INITIAL', 'STOCK') || '0').replace(',', '.')) || 0
                };
            }).filter(function (a) { return a.nom; }); // ignore les lignes sans NOM

            if (!articles.length) {
                showToast('Erreur', 'Aucun article valide (colonne NOM manquante ?)', 'error');
                return;
            }

            // 3) Envoyer au serveur
            const response = await fetch(
                API.BASE + API.HANDLERS_PATH + 'ArticlesImport.ashx',
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(articles)
                }
            );

            const result = await response.json();

            if (result.success) {
                var msg = result.message || (result.imported + ' article(s) importé(s)');
                showToast('Succès', msg, 'success');
                if (result.errors && result.errors.length) {
                    console.warn('Lignes ignorées :', result.errors);
                }
                closeImportModal();
                loadArticles();
                loadStats();
            } else {
                showToast('Erreur', result.message || "Échec de l'import", 'error');
            }
        } catch (error) {
            console.error('Erreur import:', error);
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
