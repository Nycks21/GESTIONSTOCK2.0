window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/demandes/accuse/handlers/',
    LIST: 'GetAccuse.ashx',
    STATS: 'GetAccuseStats.ashx', // on peut créer un handler stats si besoin
    ARTICLES: 'GetArticles.ashx'   // pour le modal de visualisation (si besoin)
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_SORTIE',
    SORT_ORDER: 'DESC'
};
