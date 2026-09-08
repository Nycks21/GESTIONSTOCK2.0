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
    var m = document.getElementById(id || 'sortieModal');
    if (m) {
        m.style.display = 'flex';
        document.body.style.overflow = 'hidden';
    }
}
function closeModal(id) {
    var m = document.getElementById(id || 'sortieModal');
    if (m) {
        m.style.display = 'none';
        document.body.style.overflow = '';
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
        if (AppState.page !== 1) {
            AppState.page = 1;
            loadSorties();
        }
    }, AppState.page === 1));

    container.appendChild(createBtn('‹', function () {
        if (AppState.page > 1) {
            AppState.page--;
            loadSorties();
        }
    }, AppState.page === 1));

    var maxVisible = 5;
    var start = Math.max(1, AppState.page - Math.floor(maxVisible / 2));
    var end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);

    if (start > 1) {
        container.appendChild(createBtn('1', function () {
            AppState.page = 1;
            loadSorties();
        }));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }

    for (var i = start; i <= end; i++) {
        (function (page) {
            container.appendChild(createBtn(String(page), function () {
                if (page !== AppState.page) {
                    AppState.page = page;
                    loadSorties();
                }
            }));
        })(i);
    }

    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        (function (tp) {
            container.appendChild(createBtn(String(tp), function () {
                AppState.page = tp;
                loadSorties();
            }));
        })(totalPages);
    }

    container.appendChild(createBtn('›', function () {
        if (AppState.page < totalPages) {
            AppState.page++;
            loadSorties();
        }
    }, AppState.page === totalPages));

    container.appendChild(createBtn('»', function () {
        if (AppState.page !== totalPages) {
            AppState.page = totalPages;
            loadSorties();
        }
    }, AppState.page === totalPages));

    wrapper.appendChild(container);
}

// ============================================================
// GESTION DES LIGNES (SORTIE)
// ============================================================
function ajouterLigne(articleId, qteD, qteR, obs) {
    var tbody = document.getElementById('lignesBody');
    if (!tbody) return;
    var rowCount = tbody.children.length;
    var tr = document.createElement('tr');
    tr.dataset.index = rowCount;
    tr.innerHTML = `
        <td>${rowCount + 1}</td>
        <td>
            <select class="form-control form-control-sm ligne-article" required>
                <option value="">-- Article --</option>
                ${AppState.articles.map(a => `<option value="${a.ID}" ${a.ID === articleId ? 'selected' : ''}>${a.CODE} - ${a.NOM}</option>`).join('')}
            </select>
        </td>
        <td><input type="number" class="form-control form-control-sm ligne-qted" step="0.01" min="0" value="${qteD || ''}" required /></td>
        <td><input type="number" class="form-control form-control-sm ligne-qter" step="0.01" min="0" value="${qteR || ''}" /></td>
        <td><input type="text" class="form-control form-control-sm ligne-obs" value="${obs || ''}" /></td>
        <td><button type="button" class="btn btn-sm btn-danger" onclick="supprimerLigne(this)"><i class="fas fa-trash"></i></button></td>
    `;
    tbody.appendChild(tr);
    enhanceArticleSelect(tr.querySelector('.ligne-article'));
}

function supprimerLigne(btn) {
    var tr = btn.closest('tr');
    if (tr) tr.remove();
    reindexerLignes();
}

function reindexerLignes() {
    var rows = document.querySelectorAll('#lignesBody tr');
    rows.forEach(function (tr, i) {
        tr.dataset.index = i;
        tr.querySelector('td:first-child').textContent = i + 1;
    });
}

function getLignesFromModal() {
    var lignes = [];
    document.querySelectorAll('#lignesBody tr').forEach(function (tr) {
        var articleSelect = tr.querySelector('.ligne-article');
        var articleId = articleSelect ? articleSelect.value : '';
        var qteD = parseFloat(tr.querySelector('.ligne-qted').value) || 0;
        var qteR = parseFloat(tr.querySelector('.ligne-qter').value) || 0;
        var obs = tr.querySelector('.ligne-obs') ? tr.querySelector('.ligne-obs').value : '';
        if (articleId && qteD > 0) {
            lignes.push({ articleId: articleId, quantiteD: qteD, quantiteR: qteR, observations: obs });
        }
    });
    return lignes;
}

// ============================================================
// INITIALISATION DES CONTRÔLES UI
// ============================================================
function initUIControls() {
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            closeModal('sortieModal');
            closeModal('modalImport');
        }
    });
    var form = document.getElementById('sortieForm');
    if (form) {
        form.setAttribute('novalidate', 'novalidate');
        form.addEventListener('submit', function (e) { e.preventDefault(); });
    }
    document.querySelectorAll('button').forEach(function (btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });
    var rowsSelect = document.getElementById('rows-per-page-top');
    if (rowsSelect) {
        rowsSelect.addEventListener('change', function () {
            var val = this.value;
            AppState.pageSize = (val === 'all') ? 999999 : parseInt(val, 10);
            AppState.page = 1;
            loadSorties();
        });
    }
}

// Expositions globales
window.showSpinner = showSpinner;
window.hideSpinner = hideSpinner;
window.showModal = showModal;
window.closeModal = closeModal;
window.createPaginationControls = createPaginationControls;
window.ajouterLigne = ajouterLigne;
window.supprimerLigne = supprimerLigne;
window.getLignesFromModal = getLignesFromModal;
window.initUIControls = initUIControls;
