'use strict';

// ============================================================
// SPINNER
// ============================================================

function forceHideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none';
    s.style.visibility = 'hidden';
    s.style.opacity = '0';
    s.setAttribute('aria-hidden', 'true');
}
function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'flex';
    s.style.visibility = 'visible';
    s.style.opacity = '1';
    s.removeAttribute('aria-hidden');
}
function hideSpinner() { forceHideSpinner(); }

// ============================================================
// MODALES
// ============================================================

// fonction générique pour afficher une modale (utilisée pour l'historique)
function showModal(id) {
    var m = document.getElementById(id || 'historyModal');
    if (m) {
        m.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    }
}

function closeHistoryModal() {
    var m = document.getElementById('historyModal');
    if (m) {
        m.style.display = 'none';
        document.body.style.overflow = '';
    }
    // réinitialiser les variables d'historique si elles existent globalement
    if (typeof historyArticleId !== 'undefined') historyArticleId = null;
    if (typeof historyEmplacementId !== 'undefined') historyEmplacementId = null;
    if (typeof historyPage !== 'undefined') historyPage = 1;
}

// ============================================================
// PAGINATION
// ============================================================

function createPaginationControls(totalPages) {
    var wrapper = document.getElementById('paginationWrapper');
    if (!wrapper) return;
    if (totalPages <= 1) {
        wrapper.innerHTML = '';
        return;
    }
    var container = document.createElement('div');
    container.id = 'pagination-container';
    container.style.cssText = 'margin:5px 0;display:flex;justify-content:center;gap:5px;flex-wrap:wrap;';

    function createBtn(text, onClick, disabled, isDots) {
        disabled = disabled || false;
        isDots = isDots || false;
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.textContent = text;
        if (isDots) {
            btn.style.cssText = 'padding:8px 12px;border:none;background:transparent;color:#6c757d;cursor:default;';
            btn.disabled = true;
            return btn;
        }
        var numericValue = Number(text);
        var isActive = !isNaN(numericValue) && numericValue === AppState.page;
        btn.style.cssText = 'padding:8px 14px;border:1px solid ' + (isActive ? '#007bff' : '#dee2e6') + ';'
            + 'background:' + (isActive ? '#007bff' : (disabled ? '#e9ecef' : 'white')) + ';'
            + 'color:' + (isActive ? 'white' : (disabled ? '#6c757d' : '#007bff')) + ';'
            + 'cursor:' + (disabled || isActive ? 'default' : 'pointer') + ';border-radius:6px;font-weight:' + (isActive ? '700' : '500') + ';min-width:40px;';
        if (onClick && !disabled && !isActive) {
            btn.addEventListener('click', function (e) {
                e.preventDefault();
                onClick();
            });
        }
        if (disabled) btn.disabled = true;
        return btn;
    }

    container.appendChild(createBtn('«', function() {
        if (AppState.page !== 1) { AppState.page = 1; loadStock(); }
    }, AppState.page === 1));

    container.appendChild(createBtn('‹', function() {
        if (AppState.page > 1) { AppState.page--; loadStock(); }
    }, AppState.page === 1));

    var maxVisible = 5;
    var start = Math.max(1, AppState.page - Math.floor(maxVisible/2));
    var end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);
    if (start > 1) {
        container.appendChild(createBtn('1', function() { AppState.page = 1; loadStock(); }));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }
    for (var i = start; i <= end; i++) {
        (function(page) {
            container.appendChild(createBtn(String(page), function() {
                if (page !== AppState.page) { AppState.page = page; loadStock(); }
            }));
        })(i);
    }
    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        (function(tp) {
            container.appendChild(createBtn(String(tp), function() { AppState.page = tp; loadStock(); }));
        })(totalPages);
    }

    container.appendChild(createBtn('›', function() {
        if (AppState.page < totalPages) { AppState.page++; loadStock(); }
    }, AppState.page === totalPages));

    container.appendChild(createBtn('»', function() {
        if (AppState.page !== totalPages) { AppState.page = totalPages; loadStock(); }
    }, AppState.page === totalPages));

    wrapper.innerHTML = '';
    wrapper.appendChild(container);
}

// ============================================================
// FILTRES
// ============================================================

function applyFilters() {
    var search = document.getElementById('search-filter')?.value || '';
    var article = document.getElementById('article-filter')?.value || '';
    var emplacement = document.getElementById('emplacement-filter')?.value || '';
    AppState.filters.search = search;
    AppState.filters.article = article;
    AppState.filters.emplacement = emplacement;
    AppState.page = 1;
    loadStock({ silent: true });
}
function resetFilters() {
    document.getElementById('search-filter').value = '';
    document.getElementById('article-filter').value = '';
    document.getElementById('emplacement-filter').value = '';
    AppState.filters = { search: '', article: '', emplacement: '' };
    AppState.page = 1;
    loadStock({ silent: true });
}

// ============================================================
// GESTION DU NOMBRE DE LIGNES PAR PAGE
// ============================================================

function initRowsPerPage() {
    var select = document.getElementById('rows-per-page-top');
    if (!select) return;
    var currentSize = AppState.pageSize || DEFAULTS.PAGE_SIZE;
    var exists = false;
    for (var i = 0; i < select.options.length; i++) {
        if (select.options[i].value == currentSize) {
            select.selectedIndex = i;
            exists = true;
            break;
        }
    }
    if (!exists) {
        var opt = document.createElement('option');
        opt.value = currentSize;
        opt.textContent = currentSize + ' par page';
        select.appendChild(opt);
        select.value = currentSize;
    }
    select.addEventListener('change', function () {
        var val = this.value;
        if (val === 'all') AppState.pageSize = 999999;
        else {
            var newSize = parseInt(val, 10);
            if (!isNaN(newSize) && newSize > 0) AppState.pageSize = newSize;
        }
        AppState.page = 1;
        loadStock();
    });
}

// ============================================================
// ECOUTEURS DE FILTRES
// ============================================================

function initFilterListeners() {
    var searchInput = document.getElementById('search-filter');
    var articleSelect = document.getElementById('article-filter');
    var emplacementSelect = document.getElementById('emplacement-filter');
    var timeoutId = null;
    if (searchInput) {
        searchInput.addEventListener('input', function () {
            clearTimeout(timeoutId);
            timeoutId = setTimeout(function() { applyFilters(); }, 300);
        });
    }
    if (articleSelect) articleSelect.addEventListener('change', applyFilters);
    if (emplacementSelect) emplacementSelect.addEventListener('change', applyFilters);
}

// ============================================================
// INITIALISATION UI
// ============================================================

function initUIControls() {
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeHistoryModal(); // uniquement l'historique
        }
    });
    initFilterListeners();
    initRowsPerPage();

    var form = document.getElementById('stockForm');
    if (form) {
        form.setAttribute('novalidate', 'novalidate');
        form.addEventListener('submit', function(e) { e.preventDefault(); });
    }
    document.querySelectorAll('button').forEach(function(btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });

    // Fermeture des modales par la croix (uniquement l'historique)
    document.addEventListener('click', function(e) {
        if (e.target && e.target.classList.contains('close')) {
            var modal = e.target.closest('.modal');
            if (modal && modal.id === 'historyModal') {
                closeHistoryModal();
            } else if (modal) {
                modal.style.display = 'none';
            }
        }
    });
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================

window.applyFilters = applyFilters;
window.resetFilters = resetFilters;
window.showModal = showModal;
window.closeHistoryModal = closeHistoryModal;
window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.createPaginationControls = createPaginationControls;
window.initUIControls = initUIControls;
window.forceHideSpinner = forceHideSpinner;
