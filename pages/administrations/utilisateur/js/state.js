'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// ÉTAT GLOBAL — Module Utilisateurs
// ─────────────────────────────────────────────────────────────────────────────

var currentMode = null;           // "ajout" | "modification"
var currentUserId = null;
var usersData = [];
var filteredUsers = [];
var currentPage = 1;
var rowsPerPage = 10;
var sortDirection = 1;
var isLicenceLimitReached = false;
var maxUsersAllowed = 0;
var selectedRestoreFile = null;
var selectedRestoreSource = null;
var restoreLogs = [];
var updateCheckInProgress = false;

// Exposer globalement
window.currentMode = currentMode;
window.currentUserId = currentUserId;
window.usersData = usersData;
window.filteredUsers = filteredUsers;
window.currentPage = currentPage;
window.rowsPerPage = rowsPerPage;
window.sortDirection = sortDirection;
window.isLicenceLimitReached = isLicenceLimitReached;
window.maxUsersAllowed = maxUsersAllowed;
window.selectedRestoreFile = selectedRestoreFile;
window.selectedRestoreSource = selectedRestoreSource;
window.restoreLogs = restoreLogs;
window.updateCheckInProgress = updateCheckInProgress;
