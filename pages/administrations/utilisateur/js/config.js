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

// Liste des permissions (doit être strictement identique aux clés de CHECKBOX_ID_MAP
// et aux codes définis dans AuthHelper.AllMenus côté serveur).
var PERMISSIONS_LIST = [
    'accueil', 'unites', 'emplacements', 'articles', 'categories', 'fournisseurs',
    'entrees', 'sorties', 'stock', 'saisies', 'accuses', 'inventaire',
    'exploitation', 'utilisateurs', 'requetes'
];

// Mapping permission → ID de la checkbox HTML
var CHECKBOX_ID_MAP = {
    'accueil': 'permDashboard',
    'unites': 'permUnites',
    'emplacements': 'permEmplacements',
    'articles': 'permArticles',
    'categories': 'permCategories',
    'fournisseurs': 'permFournisseurs',
    'entrees': 'permEntrees',
    'sorties': 'permSorties',
    'stock': 'permStock',
    'saisies': 'permSaisies',
    'accuses': 'permAccuses',
    'inventaire': 'permInventaire',
    'exploitation': 'permExploitation',
    'utilisateurs': 'permUser',
    'requetes': 'permRequetes'
};

// ✅ Permissions par défaut par ROLEID (0 = SuperAdmin, 1 = Admin, 2 = User, 3 = Logisticien, 4 = Comptable)
var DEFAULT_ROLE_PERMISSIONS = {
    0: ['accueil', 'unites', 'emplacements', 'articles', 'categories', 'fournisseurs', 'entrees', 'sorties', 'stock', 'saisies', 'accuses', 'inventaire', 'exploitation', 'utilisateurs', 'requetes'], // SuperAdmin
    1: ['accueil', 'unites', 'emplacements', 'articles', 'categories', 'fournisseurs', 'entrees', 'sorties', 'stock', 'saisies', 'accuses', 'inventaire', 'exploitation', 'utilisateurs'],          // Admin
    2: ['accueil','saisies', 'accuses'],                                                                                                                                                                       // User
    3: ['accueil','unites', 'emplacements', 'articles', 'categories', 'fournisseurs', 'entrees', 'sorties', 'stock', 'inventaire', 'exploitation'],                                                           // Logisticien
    4: ['accueil','entrees', 'sorties', 'stock', 'saisies', 'accuses', 'inventaire', 'exploitation']                                                                                                          // Comptable
};

var CURRENT_VERSION = document.querySelector('[data-version]')?.getAttribute('data-version') || '2.1.17';

// Exposer globalement
window.API_USERS = API_USERS;
window.PERMISSIONS_LIST = PERMISSIONS_LIST;
window.CHECKBOX_ID_MAP = CHECKBOX_ID_MAP;
window.DEFAULT_ROLE_PERMISSIONS = DEFAULT_ROLE_PERMISSIONS;
window.CURRENT_VERSION = CURRENT_VERSION;
