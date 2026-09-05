const AppState = {
    entrees: [],
    total: 0,
    page: 1,
    pageSize: DEFAULTS.PAGE_SIZE,
    totalPages: 0,
    sortField: DEFAULTS.SORT_FIELD,
    sortOrder: DEFAULTS.SORT_ORDER,
    filters: {
        search: '',
        fournisseur: '',
        statut: ''
    },
    editingId: null,          // ID du bon en cours d'édition
    fournisseurs: [],
    articles: [],            // pour les lignes
    lignes: []               // stockage temporaire des lignes dans la modale (si besoin)
};
window.AppState = AppState;

// Fonction de mise à jour (pour compatibilité)
window.updateState = function (newState) {
    try {
        Object.assign(AppState, newState || {});
        if (typeof $ !== 'undefined' && typeof $(document).trigger === 'function') {
            $(document).trigger('stateChanged');
        } else if (typeof document !== 'undefined' && typeof Event === 'function') {
            document.dispatchEvent(new Event('stateChanged'));
        }
    } catch (err) {
        console.warn('updateState failed:', err);
    }
};
window.updateStats = window.updateState;
