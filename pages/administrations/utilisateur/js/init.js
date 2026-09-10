'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// INITIALISATION — Module Utilisateurs
// ─────────────────────────────────────────────────────────────────────────────

function init() {
    console.log("🔵 Page chargée - Initialisation userJS");
    forceHideSpinner();
    preventFormAutoSubmit();
    ensureButtonsHaveTypeButton();
    loadUsers();
    attachRoleChangeListener();
    initSidebar();
    initDarkMode();
    checkLicenceLimit();
    autoCheckForUpdates();
}

function attachRoleChangeListener() {
    var roleSelect = document.getElementById('userRole');
    if (roleSelect) {
        roleSelect.removeEventListener('change', onRoleChangeHandler);
        roleSelect.addEventListener('change', onRoleChangeHandler);
    }
}

function onRoleChangeHandler(event) {
    // ✅ FIX : la valeur du <select> est maintenant numérique ("0" à "4")
    var selectedRole = event.target.value;
    var currentPermissions = getSelectedPermissions();

    // ✅ FIX : fallback sur '1' (Admin) — clé numérique cohérente avec DEFAULT_ROLE_PERMISSIONS
    var defaultPermissions = DEFAULT_ROLE_PERMISSIONS[selectedRole] || DEFAULT_ROLE_PERMISSIONS['1'] || [];

    var hasCustomPermissions = currentPermissions.length > 0 &&
        JSON.stringify(currentPermissions.slice().sort()) !== JSON.stringify(defaultPermissions.slice().sort());

    if (hasCustomPermissions && currentMode === 'modification') {
        Swal.fire({
            title: 'Changer les permissions ?',
            // ✅ Affichage lisible : conversion ROLEID → nom
            text: 'Cet utilisateur a des permissions personnalisées. Voulez-vous les remplacer par les permissions par défaut du rôle "' + getUserRoleName(selectedRole) + '" ?',
            icon: 'question',
            showCancelButton: true,
            confirmButtonText: 'Oui, remplacer',
            cancelButtonText: 'Non, garder',
            confirmButtonColor: '#3085d6'
        }).then(function(result) {
            if (result.isConfirmed) {
                applyDefaultPermissionsByRole(selectedRole);
                Swal.fire({
                    icon: 'success',
                    title: 'Permissions mises à jour',
                    text: 'Les permissions par défaut pour ' + getUserRoleName(selectedRole) + ' ont été appliquées',
                    timer: 1500,
                    showConfirmButton: false
                });
            }
        });
    } else {
        applyDefaultPermissionsByRole(selectedRole);
    }
}

window.addEventListener('load', function() {
    setTimeout(hidePreloader, 500);
});

window.init = init;
window.attachRoleChangeListener = attachRoleChangeListener;
window.onRoleChangeHandler = onRoleChangeHandler;

$(document).ready(init);
