$(document).ready(function () {

    // ─── Chargement initial ───
    loadDropdowns().then(function () {
        loadStock();
        loadStats();
        if (typeof initUIControls === 'function') initUIControls();
    });

    // ─── Filtre : Recherche (debounce 350 ms) ───
    $('#search-filter').on('input', debounce(function () {
        AppState.filters.search = (this.value || '').trim();
        AppState.page = 1;
        loadStock({ silent: true });
    }, 350));

    // ─── Filtre : Article ───
    $('#article-filter').on('change', function () {
        AppState.filters.article = this.value || '';
        AppState.page = 1;
        loadStock({ silent: true });
    });

    // ─── Filtre : Emplacement ───
    $('#emplacement-filter').on('change', function () {
        AppState.filters.emplacement = this.value || '';
        AppState.page = 1;
        loadStock({ silent: true });
    });

    // ─── ✅ NOUVEAU : Filtre STATUT ───
    $('#statut-filter').on('change', function () {
        AppState.filters.statut = this.value || '';
        AppState.page = 1;
        loadStock({ silent: true });
    });

    // ─── Lignes par page ───
    $('#rows-per-page-top').on('change', function () {
        var v = this.value;
        AppState.pageSize = (v === 'all') ? 999999 : parseInt(v, 10);
        AppState.page = 1;
        loadStock();
    });

    // ─── Bouton Réinitialiser ───
    $('#btnResetFilters').on('click', function () {
        resetFilters();
    });

    // ─── Fermeture modales par croix ───
    $('.modal .close').on('click', function () {
        $(this).closest('.modal').hide();
    });

    // ─── Tri (fonction globale) ───
    window.sortData = function (field) {
        if (AppState.sortField === field) {
            AppState.sortOrder = (AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC');
        } else {
            AppState.sortField = field;
            AppState.sortOrder = 'ASC';
        }
        AppState.page = 1;
        loadStock();
    };
});

// ============================================================
// DEBOUNCE
// ============================================================
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

// ============================================================
// RÉINITIALISATION DES FILTRES
// ============================================================
function resetFilters() {
    var elSearch = document.getElementById('search-filter');
    var elArticle = document.getElementById('article-filter');
    var elEmpl = document.getElementById('emplacement-filter');
    var elStatut = document.getElementById('statut-filter');
    var elRows = document.getElementById('rows-per-page-top');

    if (elSearch)  elSearch.value  = '';
    if (elArticle) elArticle.value = '';
    if (elEmpl)    elEmpl.value    = '';
    if (elStatut)  elStatut.value  = '';
    if (elRows)    elRows.value    = '10';

    // ✅ Reset complet (statut inclus)
    AppState.filters = {
        search: '',
        article: '',
        emplacement: '',
        statut: ''
    };
    AppState.page = 1;
    AppState.pageSize = 10;

    loadStock({ silent: true });

    if (typeof showToast === 'function') {
        showToast('Info', 'Filtres réinitialisés.', 'info', 1500);
    }
}

// Expositions
window.resetFilters = resetFilters;
