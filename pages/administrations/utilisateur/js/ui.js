'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// UI — Module Utilisateurs (Spinner, Modales, Filtres, Pagination, Sidebar)
// ─────────────────────────────────────────────────────────────────────────────

// ============================================================================
// SPINNER
// ============================================================================

function forceHideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none';
    s.style.visibility = 'hidden';
    s.style.opacity = '0';
    if (s.setAttribute) s.setAttribute('aria-hidden', 'true');
}

function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.opacity = '1';
    s.style.visibility = 'visible';
    s.style.display = 'flex';
    if (s.removeAttribute) s.removeAttribute('aria-hidden');
}

function hideSpinner() {
    forceHideSpinner();
}

function showPreloader() {
    var preloader = document.getElementById('preloader');
    if (preloader) {
        preloader.style.display = 'flex';
        preloader.classList.remove('hide');
    }
}

function hidePreloader() {
    var preloader = document.getElementById('preloader');
    if (preloader) {
        preloader.classList.add('hide');
        setTimeout(function() {
            if (preloader) preloader.style.display = 'none';
        }, 500);
    }
}

// ============================================================================
// MODALES
// ============================================================================

function showModal() {
    var modal = document.getElementById('addUserModal');
    if (modal) {
        modal.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    }
}

function closeAddUserModal(event) {
    if (event) { event.preventDefault(); event.stopPropagation(); }
    var modal = document.getElementById('addUserModal');
    if (modal) {
        modal.style.display = 'none';
        document.body.style.overflow = '';
    }
    currentMode = null;
    currentUserId = null;
    return false;
}

// ============================================================================
// FILTRES ET PAGINATION
// ============================================================================

function createFilterControls() {
    var oldContainer = document.getElementById('filter-container');
    if (oldContainer) oldContainer.remove();

    var filterContainer = document.createElement('div');
    filterContainer.id = 'filter-container';
    filterContainer.style.cssText = `
        margin: 0 0 20px 0;
        padding: 15px 20px;
        background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
        border-radius: 10px;
        display: flex;
        gap: 15px;
        flex-wrap: wrap;
        align-items: flex-end;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border: 1px solid #dee2e6;
    `;

    // ✅ FIX : options du filtre rôle = ROLEID numérique (0-4)
    filterContainer.innerHTML = `
        <div style="flex: 2; min-width: 200px;">
            <label style="display: block; margin-bottom: 8px; font-weight: 600;"><i class="fas fa-search"></i> Recherche :</label>
            <input type="text" id="search-filter" placeholder="Nom, email, téléphone..." style="width:100%; padding:10px 12px; border:1px solid #ced4da; border-radius:6px;">
        </div>
        <div style="min-width: 160px;">
            <label style="display: block; margin-bottom: 8px; font-weight: 600;"><i class="fas fa-filter"></i> Rôle :</label>
            <select id="role-filter" style="width:100%; padding:10px 12px; border:1px solid #ced4da; border-radius:6px;">
                <option value="">Tous les rôles</option>
                <option value="0">SuperAdmin</option>
                <option value="1">Admin</option>
                <option value="2">User</option>
                <option value="3">Logisticien</option>
                <option value="4">Comptable</option>
            </select>
        </div>
        <div style="min-width: 140px;">
            <label style="display: block; margin-bottom: 8px; font-weight: 600;"><i class="fas fa-chart-line"></i> Statut :</label>
            <select id="status-filter" style="width:100%; padding:10px 12px; border:1px solid #ced4da; border-radius:6px;">
                <option value="">Tous</option>
                <option value="actif">Actif</option>
                <option value="inactif">Inactif</option>
            </select>
        </div>
        <div style="min-width: 140px;">
            <label style="display: block; margin-bottom: 8px; font-weight: 600;"><i class="fas fa-table"></i> Lignes/page :</label>
            <select id="rows-per-page-top" style="width:100%; padding:10px 12px; border:1px solid #ced4da; border-radius:6px;">
                <option value="5">5 lignes</option>
                <option value="10" selected>10 lignes</option>
                <option value="20">20 lignes</option>
                <option value="50">50 lignes</option>
                <option value="100">100 lignes</option>
                <option value="-1">Tous</option>
            </select>
        </div>
        <div>
            <button id="reset-filters" style="padding:10px 24px; background:#6c757d; color:white; border:none; border-radius:6px; cursor:pointer;">
                <i class="fas fa-undo-alt"></i> Réinitialiser
            </button>
        </div>
    `;

    var dashCardBody = document.querySelector('.dash-card-body');
    if (dashCardBody) {
        dashCardBody.insertBefore(filterContainer, dashCardBody.firstChild);
    } else {
        var table = document.querySelector('.dash-table');
        if (table && table.parentNode) table.parentNode.insertBefore(filterContainer, table);
    }

    document.getElementById('search-filter')?.addEventListener('input', applyFilters);
    document.getElementById('role-filter')?.addEventListener('change', applyFilters);
    document.getElementById('status-filter')?.addEventListener('change', applyFilters);
    document.getElementById('rows-per-page-top')?.addEventListener('change', function(e) {
        rowsPerPage = parseInt(e.target.value);
        currentPage = 1;
        renderSimpleTable();
    });
    document.getElementById('reset-filters')?.addEventListener('click', resetFilters);
}

function resetFilters() {
    var searchInput = document.getElementById('search-filter');
    var roleFilter = document.getElementById('role-filter');
    var statusFilter = document.getElementById('status-filter');
    var rowsSelect = document.getElementById('rows-per-page-top');
    if (searchInput) searchInput.value = '';
    if (roleFilter) roleFilter.value = '';
    if (statusFilter) statusFilter.value = '';
    if (rowsSelect) rowsSelect.value = '10';
    rowsPerPage = 10;
    currentPage = 1;
    applyFilters();
    Swal.fire({ icon: 'success', title: 'Filtres réinitialisés', timer: 1500, showConfirmButton: false });
}

function applyFilters() {
    var searchTerm = document.getElementById('search-filter')?.value.toLowerCase().trim() || '';
    var roleFilter = document.getElementById('role-filter')?.value || '';
    var statusFilter = document.getElementById('status-filter')?.value || '';

    filteredUsers = usersData.filter(function(user) {
        var matchSearch = true;
        if (searchTerm) {
            matchSearch = (user.NOM && user.NOM.toLowerCase().includes(searchTerm)) ||
                (user.USERNAME && user.USERNAME.toLowerCase().includes(searchTerm)) ||
                (user.EMAIL && user.EMAIL.toLowerCase().includes(searchTerm)) ||
                (user.TELEPHONE && user.TELEPHONE.toLowerCase().includes(searchTerm));
        }

        // ✅ FIX : comparaison par ROLEID numérique (String pour gérer "0" !== "")
        var matchRole = true;
        if (roleFilter !== '') {
            matchRole = String(user.ROLEID) === roleFilter;
        }

        var matchStatus = true;
        if (statusFilter) {
            var isActive = (user.ACTIVE === true || user.ACTIVE === 1 || user.ACTIVE === 'true');
            matchStatus = (statusFilter === 'actif') ? isActive : !isActive;
        }
        return matchSearch && matchRole && matchStatus;
    });
    currentPage = 1;
    renderSimpleTable();
}

function goToPage(page) {
    currentPage = page;
    renderSimpleTable();
}

function createPaginationControls(totalPages) {
    var oldPagination = document.getElementById('pagination-container');
    if (oldPagination) oldPagination.remove();
    if (totalPages <= 1) return;

    var container = document.createElement('div');
    container.id = 'pagination-container';
    container.style.cssText = 'margin:20px 0; display:flex; justify-content:center; gap:5px; flex-wrap:wrap;';

    var createBtn = function(text, onClick, disabled, isDots) {
        disabled = disabled || false;
        isDots = isDots || false;
        var btn = document.createElement('button');
        btn.textContent = text;
        if (isDots) {
            btn.style.cssText = 'padding:8px 12px; border:none; background:transparent; color:#6c757d; cursor:default;';
            return btn;
        }
        var isActive = (text == currentPage && !isNaN(text));
        btn.style.cssText = 'padding:8px 14px; border:1px solid ' + (isActive ? '#007bff' : '#dee2e6') + ';'
            + 'background:' + (isActive ? '#007bff' : (disabled ? '#e9ecef' : 'white')) + ';'
            + 'color:' + (isActive ? 'white' : (disabled ? '#6c757d' : '#007bff')) + ';'
            + 'cursor:' + (disabled || isActive ? 'default' : 'pointer') + ';border-radius:6px;font-weight:' + (isActive ? '700' : '500') + ';min-width:40px;';
        if (onClick && !disabled && !isActive) btn.onclick = onClick;
        if (disabled) btn.disabled = true;
        return btn;
    };

    container.appendChild(createBtn('«', function() { goToPage(1); }, currentPage === 1));
    container.appendChild(createBtn('‹', function() { if (currentPage > 1) { currentPage--; renderSimpleTable(); } }, currentPage === 1));

    var maxVisible = 5;
    var start = Math.max(1, currentPage - Math.floor(maxVisible / 2));
    var end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);

    if (start > 1) {
        container.appendChild(createBtn('1', function() { goToPage(1); }));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }
    for (var i = start; i <= end; i++) {
        (function(page) {
            container.appendChild(createBtn(page, function() { goToPage(page); }, false));
        })(i);
    }
    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        (function(tp) {
            container.appendChild(createBtn(tp, function() { goToPage(tp); }));
        })(totalPages);
    }
    container.appendChild(createBtn('›', function() { if (currentPage < totalPages) { currentPage++; renderSimpleTable(); } }, currentPage === totalPages));
    container.appendChild(createBtn('»', function() { goToPage(totalPages); }, currentPage === totalPages));

    var table = document.querySelector('.dash-table');
    if (table && table.parentNode) {
        table.parentNode.insertBefore(container, table.nextSibling);
    }
}

function updateCounter() {
    var counter = document.getElementById('record-counter');
    if (!counter) {
        counter = document.createElement('div');
        counter.id = 'record-counter';
        counter.style.cssText = 'margin:15px 0 0; padding:10px 15px; text-align:center; font-size:14px; background:#f8f9fa; border-radius:6px; border:1px solid #e9ecef;';
        var pagination = document.getElementById('pagination-container');
        if (pagination && pagination.parentNode) {
            pagination.parentNode.insertBefore(counter, pagination);
        } else {
            var table = document.querySelector('.dash-table');
            if (table && table.parentNode) {
                table.parentNode.insertBefore(counter, table.nextSibling);
            }
        }
    }
    var start = filteredUsers.length === 0 ? 0 : (currentPage - 1) * rowsPerPage + 1;
    var end = Math.min(currentPage * rowsPerPage, filteredUsers.length);
    counter.innerHTML = '<i class="fas fa-chart-bar"></i> <strong>Affichage :</strong> ' + (filteredUsers.length === 0 ? '0' : start) + ' à ' + end + ' sur <strong>' + filteredUsers.length + '</strong> enregistrement' + (filteredUsers.length > 1 ? 's' : '');
}

// ============================================================================
// SIDEBAR
// ============================================================================

function openSidebar() {
    var sidebar = document.getElementById('controlSidebar');
    var overlay = document.getElementById('sidebarOverlay');
    if (sidebar) sidebar.style.right = '0';
    if (overlay) {
        overlay.style.display = 'block';
        document.body.style.overflow = 'hidden';
    }
}

function closeSidebar() {
    var sidebar = document.getElementById('controlSidebar');
    var overlay = document.getElementById('sidebarOverlay');
    if (sidebar) sidebar.style.right = '-300px';
    if (overlay) {
        overlay.style.display = 'none';
        document.body.style.overflow = '';
    }
}

function initSidebar() {
    var toggleBtn = document.getElementById('toggleSidebarBtn');
    var closeBtn = document.getElementById('closeSidebarBtn');
    var overlay = document.getElementById('sidebarOverlay');

    if (toggleBtn) toggleBtn.addEventListener('click', openSidebar);
    if (closeBtn) closeBtn.addEventListener('click', closeSidebar);
    if (overlay) overlay.addEventListener('click', closeSidebar);

    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') closeSidebar();
    });
}

// ============================================================================
// DARK MODE
// ============================================================================

function initDarkMode() {
    // Implémentez si nécessaire
}

// ============================================================================
// FORMULAIRES
// ============================================================================

function preventFormAutoSubmit() {
    var form = document.getElementById('form1');
    if (form) {
        form.addEventListener('submit', function(e) {
            var submitter = e.submitter;
            if (submitter && submitter.classList &&
                (submitter.classList.contains('btn-success') ||
                    submitter.classList.contains('btn-primary') ||
                    submitter.classList.contains('btn-danger') ||
                    (submitter.getAttribute('onclick') && submitter.getAttribute('onclick').includes('openAddUserModal')) ||
                    (submitter.getAttribute('onclick') && submitter.getAttribute('onclick').includes('exportUsers')))) {
                e.preventDefault();
                return false;
            }
            return true;
        });
    }
}

function ensureButtonsHaveTypeButton() {
    var buttons = document.querySelectorAll('.action-buttons button, .dash-table button, .modal-footer button');
    buttons.forEach(function(btn) {
        if (!btn.hasAttribute('type') || btn.getAttribute('type') !== 'button') {
            btn.setAttribute('type', 'button');
        }
    });
}

// Exposer globalement
window.forceHideSpinner = forceHideSpinner;
window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.showPreloader = showPreloader;
window.hidePreloader = hidePreloader;
window.showModal = showModal;
window.closeAddUserModal = closeAddUserModal;
window.createFilterControls = createFilterControls;
window.resetFilters = resetFilters;
window.applyFilters = applyFilters;
window.goToPage = goToPage;
window.createPaginationControls = createPaginationControls;
window.updateCounter = updateCounter;
window.openSidebar = openSidebar;
window.closeSidebar = closeSidebar;
window.initSidebar = initSidebar;
window.initDarkMode = initDarkMode;
window.preventFormAutoSubmit = preventFormAutoSubmit;
window.ensureButtonsHaveTypeButton = ensureButtonsHaveTypeButton;
