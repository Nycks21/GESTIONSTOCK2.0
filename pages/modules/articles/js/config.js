window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/modules/articles/handlers/',
    LIST: 'GetArticles.ashx',
    ADD: 'ArticlesAdd.ashx',
    EDIT: 'ArticlesEdit.ashx',
    DELETE: 'ArticlesDelete.ashx',
    STATS: 'GetStats.ashx',
    CATEGORIES: 'GetCategories.ashx',
    FOURNISSEURS: 'GetFournisseurs.ashx',
    UNITES: 'GetUnites.ashx',
    EMPLACEMENTS: 'GetEmplacements.ashx',
    MOUVEMENTS: 'GetMouvements.ashx',
    ADJUST: 'AdjustStock.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'NOM',
    SORT_ORDER: 'ASC'
};
