// ============================================================
// UI - SORTIES
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

function showModal(id) {
    var m = document.getElementById(id || 'sortieModal');
    if (m) { m.style.display = 'flex'; document.body.style.overflow = 'hidden'; }
}
function closeModal(id) {
    var m = document.getElementById(id || 'sortieModal');
    if (m) { m.style.display = 'none'; document.body.style.overflow = ''; }
}

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
        isDots   = isDots   || false;
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
            btn.addEventListener('click', function (e) { e.preventDefault(); onClick(); });
        }
        if (disabled) btn.disabled = true;
        return btn;
    };

    container.appendChild(createBtn('«', function () {
        if (AppState.page !== 1) { AppState.page = 1; loadSorties(); }
    }, AppState.page === 1));
    container.appendChild(createBtn('‹', function () {
        if (AppState.page > 1) { AppState.page--; loadSorties(); }
    }, AppState.page === 1));

    var maxVisible = 5;
    var start = Math.max(1, AppState.page - Math.floor(maxVisible / 2));
    var end   = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);

    if (start > 1) {
        container.appendChild(createBtn('1', function () { AppState.page = 1; loadSorties(); }));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }
    for (var i = start; i <= end; i++) {
        (function (page) {
            container.appendChild(createBtn(String(page), function () {
                if (page !== AppState.page) { AppState.page = page; loadSorties(); }
            }));
        })(i);
    }
    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        (function (tp) {
            container.appendChild(createBtn(String(tp), function () { AppState.page = tp; loadSorties(); }));
        })(totalPages);
    }

    container.appendChild(createBtn('›', function () {
        if (AppState.page < totalPages) { AppState.page++; loadSorties(); }
    }, AppState.page === totalPages));
    container.appendChild(createBtn('»', function () {
        if (AppState.page !== totalPages) { AppState.page = totalPages; loadSorties(); }
    }, AppState.page === totalPages));

    wrapper.appendChild(container);
}

// ============================================================
// LIGNES
// ============================================================
// ⚠️ IMPORTANT : les classes CSS des inputs sont synchronisées
//    avec celles déclarées dans crud.js → EDITABLE_IN_EDIT
//    (.ligne-quantite-r est le SEUL champ actif en EDIT)
// ============================================================
function ajouterLigne(articleId, qteD, qteR, obs) {
    var tbody = document.getElementById('lignesBody');
    if (!tbody) return;
    var rowCount = tbody.children.length;
    var tr = document.createElement('tr');
    tr.dataset.index = rowCount;

    var artPh = T('sorties.modal.lignes_article_select', '-- Article --');

    var optionsHtml = AppState.articles.map(function (a) {
        return '<option value="' + a.ID + '"' + (a.ID === articleId ? ' selected' : '') + '>' +
               a.CODE + ' - ' + a.NOM + '</option>';
    }).join('');

    tr.innerHTML =
        '<td>' + (rowCount + 1) + '</td>' +
        '<td>' +
            '<select class="form-control form-control-sm ligne-article" required>' +
                '<option value="">' + artPh + '</option>' +
                optionsHtml +
            '</select>' +
        '</td>' +
        '<td><input type="number" class="form-control form-control-sm ligne-quantite-d" ' +
            'step="0.01" min="0" value="' + (qteD || '') + '" required /></td>' +
        '<td><input type="number" class="form-control form-control-sm ligne-quantite-r" ' +
            'step="0.01" min="0" value="' + (qteR || '') + '" /></td>' +
        '<td><input type="text" class="form-control form-control-sm ligne-observations" ' +
            'value="' + (obs || '') + '" /></td>' +
        '<td style="text-align:center;">' +
            '<button type="button" class="btn-icon btn-danger" onclick="supprimerLigne(this)" ' +
                'title="Supprimer la ligne">' +
                '<i class="fas fa-trash"></i>' +
            '</button>' +
        '</td>';

    tbody.appendChild(tr);

    if (typeof enhanceArticleSelect === 'function') {
        enhanceArticleSelect(tr.querySelector('.ligne-article'));
    }
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
        var firstCell = tr.querySelector('td:first-child');
        if (firstCell) firstCell.textContent = i + 1;
    });
}

function getLignesFromModal() {
    var lignes = [];
    document.querySelectorAll('#lignesBody tr').forEach(function (tr) {
        var articleSelect = tr.querySelector('.ligne-article');
        var qteDInput     = tr.querySelector('.ligne-quantite-d');
        var qteRInput     = tr.querySelector('.ligne-quantite-r');
        var obsInput      = tr.querySelector('.ligne-observations');

        var articleId = articleSelect ? articleSelect.value : '';
        var qteD = qteDInput ? (parseFloat(qteDInput.value) || 0) : 0;
        var qteR = qteRInput ? (parseFloat(qteRInput.value) || 0) : 0;
        var obs  = obsInput  ? obsInput.value : '';

        if (articleId && qteD > 0) {
            lignes.push({
                articleId:    articleId,
                quantiteD:    qteD,
                quantiteR:    qteR,
                observations: obs
            });
        }
    });
    return lignes;
}

function resetFilters() {
    var s = document.getElementById('search-filter');
    var d = document.getElementById('destination-filter');
    var t = document.getElementById('statut-filter');
    if (s) s.value = '';
    if (d) d.value = '';
    if (t) t.value = '';
    AppState.filters.search      = '';
    AppState.filters.destination = '';
    AppState.filters.statut      = '';
    AppState.page = 1;
    loadSorties({ silent: true });
}

// ============================================================
// HANDLERS UNIQUES (filtres, tri, taille de page)
// ============================================================
function initUIControls() {
    // Fermeture modale par Échap
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            closeModal('sortieModal');
            closeModal('modalImport');
        }
    });

    // Empêche la soumission native du formulaire
    var form = document.getElementById('sortieForm');
    if (form) {
        form.setAttribute('novalidate', 'novalidate');
        form.addEventListener('submit', function (e) { e.preventDefault(); });
    }

    // Sécurité : boutons sans type → type="button" (évite submit accidentel)
    document.querySelectorAll('button').forEach(function (btn) {
        if (!btn.getAttribute('type')) btn.setAttribute('type', 'button');
    });

    // ─── Taille de page ───
    var rowsSelect = document.getElementById('rows-per-page-top');
    if (rowsSelect) {
        rowsSelect.addEventListener('change', function () {
            var val = this.value;
            AppState.pageSize = (val === 'all') ? 999999 : parseInt(val, 10);
            AppState.page = 1;
            loadSorties();
        });
    }

    // ─── Recherche (debounce) ───
    var searchInput = document.getElementById('search-filter');
    if (searchInput) {
        var timeoutId = null;
        searchInput.addEventListener('input', function () {
            clearTimeout(timeoutId);
            var self = this;
            timeoutId = setTimeout(function () {
                AppState.filters.search = self.value.trim();
                AppState.page = 1;
                loadSorties({ silent: true });
            }, 300);
        });
    }

    // ─── Filtre destination ───
    var destFilter = document.getElementById('destination-filter');
    if (destFilter) {
        destFilter.addEventListener('change', function () {
            AppState.filters.destination = this.value;
            AppState.page = 1;
            loadSorties({ silent: true });
        });
    }

    // ─── Filtre statut ───
    var statutFilter = document.getElementById('statut-filter');
    if (statutFilter) {
        statutFilter.addEventListener('change', function () {
            AppState.filters.statut = this.value;
            AppState.page = 1;
            loadSorties({ silent: true });
        });
    }

    // ─── Reset filtres ───
    var resetBtn = document.getElementById('btnResetFilters');
    if (resetBtn) {
        resetBtn.addEventListener('click', function () { resetFilters(); });
    }

    // ─── Tri colonnes (délégation, pas d'onclick inline requis) ───
    window.sortData = function (field) {
        if (AppState.sortField === field) {
            AppState.sortOrder = AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC';
        } else {
            AppState.sortField = field;
            AppState.sortOrder = 'ASC';
        }
        loadSorties();
    };
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.showSpinner              = showSpinner;
window.hideSpinner              = hideSpinner;
window.forceHideSpinner         = forceHideSpinner;
window.showModal                = showModal;
window.closeModal               = closeModal;
window.createPaginationControls = createPaginationControls;
window.ajouterLigne             = ajouterLigne;
window.supprimerLigne           = supprimerLigne;
window.reindexerLignes          = reindexerLignes;
window.getLignesFromModal       = getLignesFromModal;
window.initUIControls           = initUIControls;
window.resetFilters             = resetFilters;
