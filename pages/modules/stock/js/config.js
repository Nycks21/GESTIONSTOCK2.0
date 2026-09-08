window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/modules/stock/handlers/',
    LIST: 'GetStock.ashx',
    STATS: 'GetStatsStock.ashx',
    ARTICLES: 'GetArticlesForStock.ashx',
    EMPLACEMENTS: 'GetEmplacementsForStock.ashx',
    ADJUST: 'StockAdjust.ashx',
    MOUVEMENTS: 'GetMouvements.ashx'   // <-- ajout
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'ARTICLE_NOM',
    SORT_ORDER: 'ASC'
};
