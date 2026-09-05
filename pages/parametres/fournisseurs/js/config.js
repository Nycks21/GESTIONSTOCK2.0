// config.js
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/parametres/fournisseurs/handlers/',
    LIST: 'GetFournisseurs.ashx',
    ADD: 'FournisseurAdd.ashx',
    EDIT: 'FournisseurEdit.ashx',
    DELETE: 'FournisseurDelete.ashx',
    STATS: 'GetFournisseurStats.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'NOM',
    SORT_ORDER: 'ASC'
};
