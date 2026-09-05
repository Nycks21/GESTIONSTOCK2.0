'use strict';

// Spinner
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

// Modales
function showModal(id) {
    var m = document.getElementById(id || 'categorieModal');
    if (m) { m.style.display = 'flex'; document.body.style.overflow = 'hidden'; }
}
function closeCategorieModal() {
    var m = document.getElementById('categorieModal');
    if (m) { m.style.display = 'none'; document.body.style.overflow = ''; }
    currentCategorieId = null;
    clearFieldErrors(['categorieCode', 'categorieNom']);
}
function openAddCategorieModal(event) {
    if (event) event.preventDefault();
    currentCategorieId = null;
    document.getElementById('modalTitle').textContent = 'Ajouter une catégorie';
    document.getElementById('categorieForm').reset();
    document.getElementById('categorieActif').value = '1';
    document.getElementById('categorieParent').value = '';
    clearErrors();
    loadParentDropdown();
    showModal('categorieModal');
}

// Pagination (identique à celle des articles, avec loadCategories)
function createPaginationControls(totalPages) {
    var oldPagination = document.getElementById('pagination-container');
    if (oldPagination) oldPagination.remove();
    if (totalPages <= 1) {
        var wrapper = document.getElementById('paginationWrapper');
        if (wrapper) wrapper.innerHTML = '';
        return;
    }
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

    container.appendChild(createBtn('«', function () { if (AppState.page !== 1) { AppState.page = 1; loadCategories(); } }, AppState.page === 1));
    container.appendChild(createBtn('‹', function () { if (AppState.page > 1) { AppState.page--; loadCategories(); } }, AppState.page === 1));

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
            container.appendChild(createBtn(String(tp), function () { AppState.page = tp; loadCategories(); }));
        })(totalPages);
    }

    container.appendChild(createBtn('›', function () { if (AppState.page < totalPages) { AppState.page++; loadCategories(); } }, AppState.page === totalPages));
    container.appendChild(createBtn('»', function () { if (AppState.page !== totalPages) { AppState.page = totalPages; loadCategories(); } }, AppState.page === totalPages));

    var wrapper = document.getElementById('paginationWrapper');
    if (wrapper) { wrapper.innerHTML = ''; wrapper.appendChild(container); return; }
    var table = document.querySelector('.dash-table');
    if (table && table.parentNode) {
        table.parentNode.insertBefore(container, table.nextSibling);
    }
}

// Filtres
function applyFilters() {
    const search = document.getElementById('search-filter')?.value || '';
    const status = document.getElementById('status-filter')?.value || '';
    AppState.filters.search = search;
    AppState.filters.status = status;
    AppState.page = 1;
    loadCategories({ silent: true });
}
function resetFilters() {
    document.getElementById('search-filter').value = '';
    document.getElementById('status-filter').value = '';
    AppState.filters = { search: '', status: '' };
    AppState.page = 1;
    loadCategories({ silent: true });
}

// Nombre de lignes par page
function initRowsPerPage() {
    var select = document.getElementById('rows-per-page-top');
    if (!select) return;
    var currentSize = AppState.pageSize || DEFAULTS.PAGE_SIZE;
    var optionExists = false;
    for (var i = 0; i < select.options.length; i++) {
        if (select.options[i].value == currentSize) {
            select.selectedIndex = i;
            optionExists = true;
            break;
        }
    }
    if (!optionExists) {
        var opt = document.createElement('option');
        opt.value = currentSize;
        opt.textContent = currentSize + ' par page';
        select.appendChild(opt);
        select.value = currentSize;
    }
    select.addEventListener('change', function () {
        var val = this.value;
        if (val === 'all') { AppState.pageSize = 999999; }
        else { var newSize = parseInt(val, 10); if (!isNaN(newSize) && newSize > 0) AppState.pageSize = newSize; }
        AppState.page = 1;
        loadCategories();
    });
}

// Sécurité formulaire – FONCTIONS MANQUANTES AJOUTÉES
function preventFormAutoSubmit() {
    var form = document.getElementById('categorieForm');
    if (!form) return;
    form.setAttribute('novalidate', 'novalidate');
    form.addEventListener('submit', function (e) { e.preventDefault(); });
}
function ensureButtonsHaveTypeButton() {
    document.querySelectorAll('button').forEach(function (btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });
}

// Écouteurs de filtres
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

// Efface les erreurs
function clearFieldErrors(fields) {
    fields.forEach(function (id) {
        var errEl = document.getElementById('err-' + id);
        if (errEl) { errEl.textContent = ''; errEl.style.display = 'none'; }
    });
}

// Initialisation UI
function initUIControls() {
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') { closeCategorieModal(); }
    });
    initFilterListeners();
    initRowsPerPage();
    preventFormAutoSubmit();
    ensureButtonsHaveTypeButton();
}

// Expositions globales
window.applyFilters = applyFilters;
window.resetFilters = resetFilters;
window.showModal = showModal;
window.closeCategorieModal = closeCategorieModal;
window.openAddCategorieModal = openAddCategorieModal;
window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.createPaginationControls = createPaginationControls;
window.initUIControls = initUIControls;
window.clearFieldErrors = clearFieldErrors;
window.forceHideSpinner = forceHideSpinner;
window.preventFormAutoSubmit = preventFormAutoSubmit;
window.ensureButtonsHaveTypeButton = ensureButtonsHaveTypeButton;
