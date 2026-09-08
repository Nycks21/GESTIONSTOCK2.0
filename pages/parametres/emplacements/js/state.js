// state.js
const AppState = {
    emplacements: [],
    total: 0,
    page: 1,
    pageSize: DEFAULTS.PAGE_SIZE,
    totalPages: 0,
    sortField: DEFAULTS.SORT_FIELD,
    sortOrder: DEFAULTS.SORT_ORDER,
    filters: {
        search: '',
        type: '',
        parent: ''
    },
    editingId: null,
    types: [],
    parents: []
};

window.AppState = AppState;
window.updateState = function (newState) {
    Object.assign(AppState, newState || {});
    if (typeof $ !== 'undefined') $(document).trigger('stateChanged');
};
window.updateStats = window.updateState;
