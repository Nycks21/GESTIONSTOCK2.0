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
// MODALES (générique)
// ============================================================
function showModal(id) {
    var m = document.getElementById(id || 'emplacementModal');
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

    container.appendChild(createBtn('«', function () {
        if (AppState.page !== 1) { AppState.page = 1; loadEmplacements(); }
    }, AppState.page === 1));

    container.appendChild(createBtn('‹', function () {
        if (AppState.page > 1) { AppState.page--; loadEmplacements(); }
    }, AppState.page === 1));

    var maxVisible = 5;
    var start = Math.max(1, AppState.page - Math.floor(maxVisible / 2));
    var end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);
    if (start > 1) {
        container.appendChild(createBtn('1', function () { AppState.page = 1; loadEmplacements(); }));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }
    for (var i = start; i <= end; i++) {
        (function (page) {
            container.appendChild(createBtn(String(page), function () {
                if (page !== AppState.page) { AppState.page = page; loadEmplacements(); }
            }));
        })(i);
    }
    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        (function (tp) {
            container.appendChild(createBtn(String(tp), function () { AppState.page = tp; loadEmplacements(); }));
        })(totalPages);
    }

    container.appendChild(createBtn('›', function () {
        if (AppState.page < totalPages) { AppState.page++; loadEmplacements(); }
    }, AppState.page === totalPages));

    container.appendChild(createBtn('»', function () {
        if (AppState.page !== totalPages) { AppState.page = totalPages; loadEmplacements(); }
    }, AppState.page === totalPages));

    wrapper.innerHTML = '';
    wrapper.appendChild(container);
}

// ============================================================
// FILTRES
// ============================================================
function applyFilters() {
    var searchEl = document.getElementById('search-filter');
    var typeEl = document.getElementById('type-filter');
    var parentEl = document.getElementById('parent-filter');
    AppState.filters.search = searchEl ? searchEl.value : '';
    AppState.filters.type = typeEl ? typeEl.value : '';
    AppState.filters.parent = parentEl ? parentEl.value : '';
    AppState.page = 1;
    loadEmplacements({ silent: true });
}

function resetFilters() {
    var s = document.getElementById('search-filter');
    var tp = document.getElementById('type-filter');
    var p = document.getElementById('parent-filter');
    if (s) s.value = '';
    if (tp) tp.value = '';
    if (p) p.value = '';
    AppState.filters = { search: '', type: '', parent: '' };
    AppState.page = 1;
    loadEmplacements({ silent: true });
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
        if (val === 'all') AppState.pageSize = 999999;
        else {
            var newSize = parseInt(val, 10);
            if (!isNaN(newSize) && newSize > 0) AppState.pageSize = newSize;
        }
        AppState.page = 1;
        loadEmplacements();
    });
}

// ============================================================
// ÉCOUTEURS DE FILTRES
// ============================================================
function initFilterListeners() {
    var searchInput = document.getElementById('search-filter');
    var typeSelect = document.getElementById('type-filter');
    var parentSelect = document.getElementById('parent-filter');
    var timeoutId = null;
    if (searchInput) {
        searchInput.addEventListener('input', function () {
            clearTimeout(timeoutId);
            timeoutId = setTimeout(function () { applyFilters(); }, 300);
        });
    }
    if (typeSelect) typeSelect.addEventListener('change', applyFilters);
    if (parentSelect) parentSelect.addEventListener('change', applyFilters);
}

// ============================================================
// INITIALISATION UI
// ============================================================
function initUIControls() {
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            if (typeof closeEmplacementModal === 'function') {
                closeEmplacementModal();
            }
        }
    });
    initFilterListeners();
    initRowsPerPage();
    var form = document.getElementById('emplacementForm');
    if (form) {
        form.setAttribute('novalidate', 'novalidate');
        form.addEventListener('submit', function (e) { e.preventDefault(); });
    }
    document.querySelectorAll('button').forEach(function (btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.applyFilters = applyFilters;
window.resetFilters = resetFilters;
window.showModal = showModal;
window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.createPaginationControls = createPaginationControls;
window.initUIControls = initUIControls;
