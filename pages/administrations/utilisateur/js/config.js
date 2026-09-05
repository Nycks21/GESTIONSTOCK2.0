'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURATION — Module Utilisateurs
// ─────────────────────────────────────────────────────────────────────────────

var API_USERS = {
    list: 'api/ListUser.aspx',
    create: 'api/users.aspx',
    update: 'api/updateUser.aspx',
    delete: 'api/DeleteUser.aspx',
    checkLicence: 'api/CheckLicence.aspx',
    backup: 'api/BackupDatabase.aspx',
    restore: 'api/RestoreDatabase.aspx',
    restoreUpload: 'api/RestoreDatabaseForm.aspx',
    checkFile: 'api/CheckFile.aspx',
    deleteFile: 'api/DeleteFile.aspx',
    getBackupList: 'api/GetBackupList.aspx',
    notifyMaintenance: 'api/NotifyMaintenance.aspx',
    checkUpdates: 'api/CheckUpdates.aspx'
};

var PERMISSIONS_LIST = [
    'accueil', 'articles', 'categories', 'fournisseurs', 'entrees', 'sorties', 'inventaire', 'mouvements', 'rapports-stock', 'parametres-stock', 'parametres-users', 'requetes'
];

var CHECKBOX_ID_MAP = {
    'accueil': 'permDashboard',
    'articles': 'permArticles',
    'categories': 'permCategories',
    'fournisseurs': 'permFournisseurs',
    'entrees': 'permEntrees',
    'sorties': 'permSorties',
    'inventaire': 'permInventaire',
    'mouvements': 'permMouvements',
    'parametres-stock': 'permRapports-stock',
    'parametres-users': 'permParametres-users',
    'requetes': 'requetes'
};

var DEFAULT_ROLE_PERMISSIONS = {
    'Administrateur': ['accueil', 'articles', 'categories', 'fournisseurs', 'entrees', 'sorties', 'inventaire', 'mouvements', 'parametres-stock', 'parametres-users'],
    'SuperAdmin': ['accueil', 'articles', 'categories', 'fournisseurs', 'entrees', 'sorties', 'inventaire', 'mouvements', 'parametres-stock', 'parametres-users', 'requetes'],
};

var CURRENT_VERSION = document.querySelector('[data-version]')?.getAttribute('data-version') || '2.1.17';

// Exposer globalement
window.API_USERS = API_USERS;
window.PERMISSIONS_LIST = PERMISSIONS_LIST;
window.CHECKBOX_ID_MAP = CHECKBOX_ID_MAP;
window.DEFAULT_ROLE_PERMISSIONS = DEFAULT_ROLE_PERMISSIONS;
window.CURRENT_VERSION = CURRENT_VERSION;
