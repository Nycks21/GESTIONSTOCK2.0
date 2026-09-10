// ui.js – Interface utilisateur (spinner, pagination, filtres, initialisation)
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

function hideSpinner() {
    forceHideSpinner();
}

// ============================================================
// MODALES (ouverture/fermeture génériques)
// ============================================================

function showModal(id) {
    var m = document.getElementById(id || 'uniteModal');
    if (m) {
        m.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    }
}

// La fermeture est gérée par closeUniteModal() dans crud.js
// On garde une fonction générique si besoin, mais on utilise closeUniteModal depuis le HTML.

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
        if (AppState.page !== 1) {
            AppState.page = 1;
            loadUnites();
        }
    }, AppState.page === 1));

    container.appendChild(createBtn('‹', function () {
        if (AppState.page > 1) {
            AppState.page--;
            loadUnites();
        }
    }, AppState.page === 1));

    var maxVisible = 5;
    var start = Math.max(1, AppState.page - Math.floor(maxVisible / 2));
    var end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);

    if (start > 1) {
        container.appendChild(createBtn('1', function () {
            AppState.page = 1;
            loadUnites();
        }));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }

    for (var i = start; i <= end; i++) {
        (function (page) {
            container.appendChild(createBtn(String(page), function () {
                if (page !== AppState.page) {
                    AppState.page = page;
                    loadUnites();
                }
            }));
        })(i);
    }

    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        (function (tp) {
            container.appendChild(createBtn(String(tp), function () {
                AppState.page = tp;
                loadUnites();
            }));
        })(totalPages);
    }

    container.appendChild(createBtn('›', function () {
        if (AppState.page < totalPages) {
            AppState.page++;
            loadUnites();
        }
    }, AppState.page === totalPages));

    container.appendChild(createBtn('»', function () {
        if (AppState.page !== totalPages) {
            AppState.page = totalPages;
            loadUnites();
        }
    }, AppState.page === totalPages));

    wrapper.appendChild(container);
}

// ============================================================
// FILTRES
// ============================================================

function applyFilters() {
    var search = document.getElementById('search-filter')?.value || '';
    var status = document.getElementById('status-filter')?.value || '';
    AppState.filters.search = search;
    AppState.filters.status = status;
    AppState.page = 1;
    loadUnites({ silent: true });
}

function resetFilters() {
    document.getElementById('search-filter').value = '';
    document.getElementById('status-filter').value = '';
    AppState.filters = { search: '', status: '' };
    AppState.page = 1;
    loadUnites({ silent: true });
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
        if (val === 'all') {
            AppState.pageSize = 999999;
        } else {
            var newSize = parseInt(val, 10);
            if (!isNaN(newSize) && newSize > 0) AppState.pageSize = newSize;
        }
        AppState.page = 1;
        loadUnites();
    });
}

// ============================================================
// ÉCOUTEURS DE FILTRES
// ============================================================

function initFilterListeners() {
    var searchInput = document.getElementById('search-filter');
    var statusSelect = document.getElementById('status-filter');
    var timeoutId = null;

    if (searchInput) {
        searchInput.addEventListener('input', function () {
            clearTimeout(timeoutId);
            timeoutId = setTimeout(function () {
                applyFilters();
            }, 300);
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
    // Fermeture du modal avec la touche Échap
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            // Utiliser closeUniteModal défini dans crud.js
            if (typeof closeUniteModal === 'function') {
                closeUniteModal();
            }
        }
    });

    // Appliquer les écouteurs de filtres
    initFilterListeners();
    initRowsPerPage();

    // Sécuriser les formulaires et les boutons
    var form = document.getElementById('uniteForm');
    if (form) {
        form.setAttribute('novalidate', 'novalidate');
        form.addEventListener('submit', function (e) { e.preventDefault(); });
    }

    document.querySelectorAll('button').forEach(function (btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });

    // Gestion de la fermeture des modales par la croix (délégation d'événements)
    document.addEventListener('click', function (e) {
        var target = e.target;
        if (target && target.classList.contains('close')) {
            var modal = target.closest('.modal');
            if (modal && modal.id === 'uniteModal') {
                if (typeof closeUniteModal === 'function') {
                    closeUniteModal();
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
