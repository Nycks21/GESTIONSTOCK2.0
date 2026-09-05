window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/modules/categories/handlers/',
    LIST: 'GetCategories.ashx',
    ADD: 'CategorieAdd.ashx',
    EDIT: 'CategorieEdit.ashx',
    DELETE: 'CategorieDelete.ashx',
    STATS: 'GetCategorieStats.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'NOM',
    SORT_ORDER: 'ASC'
};
