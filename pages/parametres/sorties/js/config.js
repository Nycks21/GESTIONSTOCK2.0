window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/parametres/sorties/handlers/',
    LIST: 'GetSorties.ashx',
    ADD: 'SortieAdd.ashx',
    EDIT: 'SortieEdit.ashx',
    DELETE: 'SortieDelete.ashx',
    STATS: 'GetSortieStats.ashx',
    ARTICLES: 'GetArticles.ashx',
    VALIDATE: 'SortieValidate.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_SORTIE',
    SORT_ORDER: 'DESC'
};
