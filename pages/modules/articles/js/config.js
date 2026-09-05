// config.js
window.API = {
    // BASE = racine du site (définie dans la page avec ResolveUrl("~/"))
    BASE: window.BASE_PATH || '/',
    // Chemin relatif depuis la racine vers le dossier des handlers des articles
    HANDLERS_PATH: 'pages/modules/articles/handlers/',
    // Endpoints (nom des fichiers .ashx)
    LIST: 'GetArticles.ashx',
    ADD: 'ArticlesAdd.ashx',
    EDIT: 'ArticlesEdit.ashx',
    DELETE: 'ArticlesDelete.ashx',
    STATS: 'GetStats.ashx',
    CATEGORIES: 'GetCategories.ashx',
    FOURNISSEURS: 'GetFournisseurs.ashx',
    UNITES: 'GetUnites.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'NOM',
    SORT_ORDER: 'ASC'
};
