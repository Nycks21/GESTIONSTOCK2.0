window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: '',  // vide car les chemins sont complets
    LIST: 'pages/demandes/saisie/handlers/GetDemandes.ashx',
    STATS: 'pages/demandes/saisie/handlers/GetDemandesStats.ashx',
    ADD: 'pages/modules/sorties/handlers/SortieAdd.ashx',
    EDIT: 'pages/modules/sorties/handlers/SortieEdit.ashx',
    DELETE: 'pages/modules/sorties/handlers/SortieDelete.ashx',
    ARTICLES: '../../../modules/sorties/handlers/GetArticles.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_SORTIE',
    SORT_ORDER: 'DESC'
};

