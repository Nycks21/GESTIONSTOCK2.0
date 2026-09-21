'use strict';

function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

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
function showModal(id) {
    var m = document.getElementById(id || 'categorieModal');
    if (m) {
        m.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    }
}

// ============================================================
// PAGINATION
// ============================================================
function createPaginationControls(totalPages) {
    var wrapper = document.getElementById('paginationWrapper');
    if (!wrapper) return;
    wrapper.innerHTML = '';
    if (totalPages <= 1) return;

    var container = document.createElement('div');
    container.id = 'pagination-container';
    container.style.cssText = 'margin:5px 0;display:flex;justify-content:center;gap:5px;flex-wrap:wrap;';

    var createBtn = function (text, onClick, disabled, isDots) {
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
    };

    container.appendChild(createBtn('«', function () {
        if (AppState.page !== 1) { AppState.page = 1; loadCategories(); }
    }, AppState.page === 1));

    container.appendChild(createBtn('‹', function () {
        if (AppState.page > 1) { AppState.page--; loadCategories(); }
    }, AppState.page === 1));

    var maxVisible = 5;
    var start = Math.max(1, AppState.page - Math.floor(maxVisible / 2));
    var end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);

    if (start > 1) {
        container.appendChild(createBtn('1', function () { AppState.page = 1; loadCategories(); }));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }
    for (var i = start; i <= end; i++) {
        (function (page) {
            container.appendChild(createBtn(String(page), function () {
                if (page !== AppState.page) { AppState.page = page; loadCategories(); }
            }));
        })(i);
    }
    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        (function (tp) {
            container.appendChild(createBtn(String(tp), function () {
                AppState.page = tp;
                loadCategories();
            }));
        })(totalPages);
    }

    container.appendChild(createBtn('›', function () {
        if (AppState.page < totalPages) { AppState.page++; loadCategories(); }
    }, AppState.page === totalPages));

    container.appendChild(createBtn('»', function () {
        if (AppState.page !== totalPages) { AppState.page = totalPages; loadCategories(); }
    }, AppState.page === totalPages));

    wrapper.appendChild(container);
}

// ============================================================
// FILTRES
// ============================================================
function applyFilters() {
    var searchEl = document.getElementById('search-filter');
    var statusEl = document.getElementById('status-filter');
    AppState.filters.search = searchEl ? searchEl.value : '';
    AppState.filters.status = statusEl ? statusEl.value : '';
    AppState.page = 1;
    loadCategories({ silent: true });
}

function resetFilters() {
    var s = document.getElementById('search-filter');
    var t2 = document.getElementById('status-filter');
    if (s) s.value = '';
    if (t2) t2.value = '';
    AppState.filters = { search: '', status: '' };
    AppState.page = 1;
    loadCategories({ silent: true });
}

// ============================================================
// LIGNES PAR PAGE
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
        opt.textContent = currentSize + ' / page';
        select.appendChild(opt);
        select.value = currentSize;
    }
    select.addEventListener('change', function () {
        var val = this.value;
        if (val === 'all') { AppState.pageSize = 999999; }
        else {
            var newSize = parseInt(val, 10);
            if (!isNaN(newSize) && newSize > 0) AppState.pageSize = newSize;
        }
        AppState.page = 1;
        loadCategories();
    });
}

// ============================================================
// ÉCOUTEURS DE FILTRES
// ============================================================
function initFilterListeners() {
    var searchInput = document.getElementById('search-filter');
    var statusSelect = document.getElementById('status-filter');
    if (searchInput) {
        var timeoutId = null;
        searchInput.addEventListener('input', function () {
            clearTimeout(timeoutId);
            timeoutId = setTimeout(function () { applyFilters(); }, 300);
        });
    }
    if (statusSelect) {
        statusSelect.addEventListener('change', applyFilters);
    }
}

// ============================================================
// INITIALISATION DES CONTRÔLES UI
// ============================================================
function initUIControls() {
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            if (typeof closeCategorieModal === 'function') {
                closeCategorieModal();
            }
        }
    });
    initFilterListeners();
    initRowsPerPage();

    var form = document.getElementById('categorieForm');
    if (form) {
        form.setAttribute('novalidate', 'novalidate');
        form.addEventListener('submit', function (e) { e.preventDefault(); });
    }
    document.querySelectorAll('button').forEach(function (btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });

    document.addEventListener('click', function (e) {
        if (e.target && e.target.classList.contains('close')) {
            var modal = e.target.closest('.modal');
            if (modal && modal.id === 'categorieModal') {
                if (typeof closeCategorieModal === 'function') {
                    closeCategorieModal();
                } else {
                    modal.style.display = 'none';
                }
            }
        }
    });
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.forceHideSpinner = forceHideSpinner;
window.showModal = showModal;
window.createPaginationControls = createPaginationControls;
window.applyFilters = applyFilters;
window.resetFilters = resetFilters;
window.initUIControls = initUIControls;
