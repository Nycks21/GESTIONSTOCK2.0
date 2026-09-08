window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/modules/sorties/handlers/',  // nos handlers
    LIST: 'GetDemandes.ashx',
    STATS: 'GetDemandesStats.ashx',   // optionnel
    ADD: 'SortieAdd.ashx',            // réutilisé depuis sorties
    ARTICLES: 'GetArticles.ashx'      // réutilisé depuis articles
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_SORTIE',
    SORT_ORDER: 'DESC'
};
