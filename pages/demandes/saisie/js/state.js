const AppState = {
    sorties: [],
    total: 0,
    page: 1,
    pageSize: DEFAULTS.PAGE_SIZE,
    totalPages: 0,
    sortField: DEFAULTS.SORT_FIELD,
    sortOrder: DEFAULTS.SORT_ORDER,
    filters: {
        search: '',
        statut: ''
    },
    articles: []
};
window.AppState = AppState;
window.updateState = function (newState) {
    Object.assign(AppState, newState || {});
    if (typeof $ !== 'undefined') $(document).trigger('stateChanged');
};
