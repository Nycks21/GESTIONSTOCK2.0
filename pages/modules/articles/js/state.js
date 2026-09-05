// state.js
const AppState = {
    articles: [],
    total: 0,
    page: 1,
    pageSize: DEFAULTS.PAGE_SIZE,
    totalPages: 0,
    sortField: DEFAULTS.SORT_FIELD,
    sortOrder: DEFAULTS.SORT_ORDER,
    filters: {
        search: '',
        category: '',
        status: '',
    },
    editingId: null, // pour le modal (stocke l'ID de l'article en édition)
    categories: [],
    fournisseurs: [],
    unites: [],
};

// Exposer explicitement sur `window` pour éviter les erreurs de portée
window.AppState = AppState;

// Mise à jour de l'état global. Robuste si jQuery n'est pas encore chargé.
window.updateState = function (newState) {
    try {
        Object.assign(AppState, newState || {});
        if (typeof $ !== 'undefined' && typeof $(document).trigger === 'function') {
            $(document).trigger('stateChanged');
        } else if (typeof document !== 'undefined' && typeof Event === 'function') {
            document.dispatchEvent(new Event('stateChanged'));
        }
    } catch (err) {
        console.warn('updateState/updateStats failed:', err);
    }
};

// Alias historical/alternate name used elsewhere in the app
window.updateStats = window.updateState;
