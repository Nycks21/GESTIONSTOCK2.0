// config.js
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/parametres/unites/handlers/',
    LIST: 'GetUnites.ashx',
    ADD: 'UniteAdd.ashx',
    EDIT: 'UniteEdit.ashx',
    DELETE: 'UniteDelete.ashx',
    STATS: 'GetUniteStats.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'NOM',
    SORT_ORDER: 'ASC'
};
