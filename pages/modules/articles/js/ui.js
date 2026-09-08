'use strict';

// Spinner
function forceHideSpinner() {
    const s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none';
    s.style.visibility = 'hidden';
    s.style.opacity = '0';
    s.setAttribute('aria-hidden', 'true');
}
function showSpinner() {
    const s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'flex';
    s.style.visibility = 'visible';
    s.style.opacity = '1';
    s.removeAttribute('aria-hidden');
}
function hideSpinner() { forceHideSpinner(); }

function createPaginationControls(totalPages) {
    const wrapper = document.getElementById('paginationWrapper');
    if (!wrapper) return;
    if (totalPages <= 1) { wrapper.innerHTML = ''; return; }

    const container = document.createElement('div');
    container.id = 'pagination-container';
    container.style.cssText = 'margin:5px 0;display:flex;justify-content:center;gap:5px;flex-wrap:wrap;';

    function createBtn(text, onClick, disabled, isDots) {
        disabled = disabled || false;
        isDots = isDots || false;
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.textContent = text;
        if (isDots) {
            btn.style.cssText = 'padding:8px 12px;border:none;background:transparent;color:#6c757d;cursor:default;';
            btn.disabled = true;
            return btn;
        }
        const numericValue = Number(text);
        const isActive = !isNaN(numericValue) && numericValue === AppState.page;
        btn.style.cssText = `padding:8px 14px;border:1px solid ${isActive ? '#007bff' : '#dee2e6'};
            background:${isActive ? '#007bff' : (disabled ? '#e9ecef' : 'white')};
            color:${isActive ? 'white' : (disabled ? '#6c757d' : '#007bff')};
            cursor:${disabled || isActive ? 'default' : 'pointer'};border-radius:6px;
            font-weight:${isActive ? '700' : '500'};min-width:40px;`;
        if (onClick && !disabled && !isActive) {
            btn.addEventListener('click', function(e) {
                e.preventDefault();
                onClick();
            });
        }
        if (disabled) btn.disabled = true;
        return btn;
    }

    container.appendChild(createBtn('«', function() {
        if (AppState.page !== 1) { AppState.page = 1; loadArticles(); }
    }, AppState.page === 1));

    container.appendChild(createBtn('‹', function() {
        if (AppState.page > 1) { AppState.page--; loadArticles(); }
    }, AppState.page === 1));

    const maxVisible = 5;
    let start = Math.max(1, AppState.page - Math.floor(maxVisible/2));
    let end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);
    if (start > 1) {
        container.appendChild(createBtn('1', function() { AppState.page = 1; loadArticles(); }));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }
    for (let i = start; i <= end; i++) {
        (function(page) {
            container.appendChild(createBtn(String(page), function() {
                if (page !== AppState.page) { AppState.page = page; loadArticles(); }
            }));
        })(i);
    }
    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        (function(tp) {
            container.appendChild(createBtn(String(tp), function() { AppState.page = tp; loadArticles(); }));
        })(totalPages);
    }

    container.appendChild(createBtn('›', function() {
        if (AppState.page < totalPages) { AppState.page++; loadArticles(); }
    }, AppState.page === totalPages));

    container.appendChild(createBtn('»', function() {
        if (AppState.page !== totalPages) { AppState.page = totalPages; loadArticles(); }
    }, AppState.page === totalPages));

    wrapper.innerHTML = '';
    wrapper.appendChild(container);
}

function applyFilters() {
    const search = document.getElementById('search-filter')?.value || '';
    const category = document.getElementById('category-filter')?.value || '';
    const status = document.getElementById('status-filter')?.value || '';
    AppState.filters.search = search;
    AppState.filters.category = category;
    AppState.filters.status = status;
    AppState.page = 1;
    loadArticles({ silent: true });
}

function resetFilters() {
    document.getElementById('search-filter').value = '';
    document.getElementById('category-filter').value = '';
    document.getElementById('status-filter').value = '';
    AppState.filters = { search: '', category: '', status: '' };
    AppState.page = 1;
    loadArticles({ silent: true });
}

function initRowsPerPage() {
    const select = document.getElementById('rows-per-page-top');
    if (!select) return;
    const currentSize = AppState.pageSize || DEFAULTS.PAGE_SIZE;
    let exists = false;
    for (let i = 0; i < select.options.length; i++) {
        if (select.options[i].value == currentSize) {
            select.selectedIndex = i;
            exists = true;
            break;
        }
    }
    if (!exists) {
        const opt = document.createElement('option');
        opt.value = currentSize;
        opt.textContent = currentSize + ' par page';
        select.appendChild(opt);
        select.value = currentSize;
    }
    select.addEventListener('change', function () {
        const val = this.value;
        if (val === 'all') AppState.pageSize = 999999;
        else {
            const newSize = parseInt(val, 10);
            if (!isNaN(newSize) && newSize > 0) AppState.pageSize = newSize;
        }
        AppState.page = 1;
        loadArticles();
    });
}

function initFilterListeners() {
    const searchInput = document.getElementById('search-filter');
    let timeoutId = null;
    if (searchInput) {
        searchInput.addEventListener('input', function () {
            clearTimeout(timeoutId);
            timeoutId = setTimeout(function() { applyFilters(); }, 300);
        });
    }
    document.getElementById('category-filter')?.addEventListener('change', applyFilters);
    document.getElementById('status-filter')?.addEventListener('change', applyFilters);
}

// ============================================================
// RENDRE LES MODALES DÉPLAÇABLES (DRAG)
// ============================================================
function makeModalDraggable(modalId) {
    var modal = document.getElementById(modalId);
    if (!modal) return;

    var header = modal.querySelector('.modal-header');
    if (!header) return;

    var isDragging = false;
    var offsetX = 0, offsetY = 0;

    // Curseur "move" sur l'en-tête
    header.style.cursor = 'move';

    // Démarrer le drag
    header.addEventListener('mousedown', function(e) {
        // Ignorer si on clique sur un bouton, input, select, etc.
        var tag = e.target.tagName;
        if (tag === 'BUTTON' || tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA' || tag === 'A') {
            return;
        }

        isDragging = true;

        // Récupérer la position actuelle du modal
        var rect = modal.getBoundingClientRect();
        offsetX = e.clientX - rect.left;
        offsetY = e.clientY - rect.top;

        // Passer en position fixed avec des coordonnées absolues
        modal.style.position = 'fixed';
        modal.style.left = rect.left + 'px';
        modal.style.top = rect.top + 'px';
        modal.style.margin = '0';
        modal.style.transform = 'none';

        // Empêcher la sélection de texte pendant le drag
        document.body.style.userSelect = 'none';
    });

    // Déplacer le modal
    document.addEventListener('mousemove', function(e) {
        if (!isDragging) return;

        var newLeft = e.clientX - offsetX;
        var newTop = e.clientY - offsetY;

        // Optionnel : empêcher de sortir de l'écran
        var winWidth = window.innerWidth;
        var winHeight = window.innerHeight;
        var modalWidth = modal.offsetWidth;
        var modalHeight = modal.offsetHeight;

        newLeft = Math.max(0, Math.min(newLeft, winWidth - modalWidth));
        newTop = Math.max(0, Math.min(newTop, winHeight - modalHeight));

        modal.style.left = newLeft + 'px';
        modal.style.top = newTop + 'px';
    });

    // Fin du drag
    document.addEventListener('mouseup', function() {
        if (isDragging) {
            isDragging = false;
            document.body.style.userSelect = '';
        }
    });
}

function initUIControls() {
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeAdjustModal();
            closeHistoryModal();
            closeArticleModal();
        }
    });
    const closeButtons = document.querySelectorAll('.modal .close');
    closeButtons.forEach(btn => {
        btn.addEventListener('click', function() {
            const modal = this.closest('.modal');
            if (modal) modal.style.display = 'none';
        });
    });
    initFilterListeners();
    initRowsPerPage();
    // Sécuriser les boutons
    document.querySelectorAll('button').forEach(btn => {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });
}


window.applyFilters = applyFilters;
window.resetFilters = resetFilters;
window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.createPaginationControls = createPaginationControls;
window.initUIControls = initUIControls;
