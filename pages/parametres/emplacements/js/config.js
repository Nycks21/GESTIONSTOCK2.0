// config.js
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/parametres/emplacements/handlers/',
    LIST: 'GetEmplacements.ashx',
    ADD: 'EmplacementAdd.ashx',
    EDIT: 'EmplacementEdit.ashx',
    DELETE: 'EmplacementDelete.ashx',
    STATS: 'GetStatsEmplacements.ashx',
    TYPES: 'GetTypes.ashx',           // pour liste des types distincts
    PARENTS: 'GetParents.ashx'        // pour liste des parents
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'NOM',
    SORT_ORDER: 'ASC'
};
