// state.js
const AppState = {
    unites: [],
    total: 0,
    page: 1,
    pageSize: DEFAULTS.PAGE_SIZE,
    totalPages: 0,
    sortField: DEFAULTS.SORT_FIELD,
    sortOrder: DEFAULTS.SORT_ORDER,
    filters: {
        search: '',
        status: '' // '1' ou '0' ou ''
    },
    editingId: null
};

window.AppState = AppState;

window.updateState = function (newState) {
    Object.assign(AppState, newState || {});
    if (typeof $ !== 'undefined' && typeof $(document).trigger === 'function') {
        $(document).trigger('stateChanged');
    } else if (typeof document !== 'undefined' && typeof Event === 'function') {
        document.dispatchEvent(new Event('stateChanged'));
    }
};
window.updateStats = window.updateState;
