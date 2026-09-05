window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/modules/entrees/handlers/',
    LIST: 'GetEntrees.ashx',
    ADD: 'EntreeAdd.ashx',
    EDIT: 'EntreeEdit.ashx',
    DELETE: 'EntreeDelete.ashx',
    STATS: 'GetEntreeStats.ashx',
    FOURNISSEURS: 'GetFournisseurs.ashx',
    ARTICLES: 'GetArticles.ashx',
    VALIDATE: 'EntreeValidate.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_ENTREE',
    SORT_ORDER: 'DESC'
};
