// ============================================================
// CONFIGURATION — STOCK
// ============================================================

window.BASE_PATH = window.BASE_PATH || '/';

window.API = {
    BASE: window.BASE_PATH,
    HANDLERS_PATH: 'pages/modules/stock/handlers/',
    LIST: 'GetStock.ashx',
    STATS: 'GetStatsStock.ashx',
    ARTICLES: 'GetArticlesForStock.ashx',
    EMPLACEMENTS: 'GetEmplacementsForStock.ashx',
    MOUVEMENTS: 'GetMouvements.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'ARTICLE_NOM',
    SORT_ORDER: 'ASC'
};
