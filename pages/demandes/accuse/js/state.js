// ============================================================
// ÉTAT GLOBAL — ACCUSE
// ============================================================

// ✅ Fallback si DEFAULTS n'est pas encore chargé
var _defs = window.DEFAULTS || {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_SORTIE',
    SORT_ORDER: 'DESC'
};

// ✅ Toujours réassigner window.AppState (pas de const → pas d'erreur au rechargement)
window.AppState = {
    sorties: [],
    total: 0,
    page: 1,
    pageSize: _defs.PAGE_SIZE,
    totalPages: 0,
    sortField: _defs.SORT_FIELD,
    sortOrder: _defs.SORT_ORDER,
    filters: {
        search: '',
        destination: ''
    },
    articles: []
};
