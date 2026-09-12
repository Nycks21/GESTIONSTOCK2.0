// ============================================================
// ÉTAT GLOBAL — STOCK
// ============================================================

// ✅ Fallback si DEFAULTS n'est pas encore chargé
var _defs = window.DEFAULTS || {
    PAGE_SIZE: 10,
    SORT_FIELD: 'ARTICLE_NOM',
    SORT_ORDER: 'ASC'
};

// ✅ Toujours réassigner window.AppState (pas de const → pas d'erreur au rechargement)
window.AppState = {
    stock: [],
    total: 0,
    page: 1,
    pageSize: _defs.PAGE_SIZE,
    totalPages: 0,
    sortField: _defs.SORT_FIELD,
    sortOrder: _defs.SORT_ORDER,
    filters: {
        search: '',
        article: '',
        emplacement: ''
    },
    editingId: null,
    articles: [],
    emplacements: []
};

window.updateState = function (newState) {
    Object.assign(window.AppState, newState || {});
    if (typeof $ !== 'undefined') $(document).trigger('stateChanged');
};
