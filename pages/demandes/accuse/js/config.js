// ============================================================
// CONFIGURATION — ACCUSE
// ============================================================

// BASE_PATH : fallback sûr
window.BASE_PATH = window.BASE_PATH || '/';

// ✅ Toujours réassigner (idempotent : pas d'erreur au rechargement)
window.API = {
    BASE: window.BASE_PATH,
    HANDLERS_PATH: 'pages/demandes/accuse/handlers/',
    LIST: 'GetAccuse.ashx',
    STATS: 'GetAccuseStats.ashx',
    ARTICLES: 'GetArticles.ashx',
    SET_ACCUSE: 'SetAccuse.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_SORTIE',
    SORT_ORDER: 'DESC'
};
