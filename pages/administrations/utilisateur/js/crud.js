"use strict";

// ============================================================
// CRUD — Module Utilisateurs
// ============================================================

// ============================================================================
// PERMISSIONS
// ============================================================================
function applyDefaultPermissionsByRole(roleId) {
    var key = String(roleId);
    var defaultPermissions = DEFAULT_ROLE_PERMISSIONS[key] || DEFAULT_ROLE_PERMISSIONS["1"] || [];
    for (var i = 0; i < PERMISSIONS_LIST.length; i++) {
        var perm = PERMISSIONS_LIST[i];
        var checkbox = document.getElementById(CHECKBOX_ID_MAP[perm]);
        if (checkbox) checkbox.checked = defaultPermissions.indexOf(perm) !== -1;
    }
}
function setPermissionsCheckboxes(permissions) {
    for (var perm in CHECKBOX_ID_MAP) {
        if (CHECKBOX_ID_MAP.hasOwnProperty(perm)) {
            var checkbox = document.getElementById(CHECKBOX_ID_MAP[perm]);
            if (checkbox) checkbox.checked = permissions && permissions.indexOf(perm) !== -1;
        }
    }
}
function getSelectedPermissions() {
    var selected = [];
    for (var perm in CHECKBOX_ID_MAP) {
        if (CHECKBOX_ID_MAP.hasOwnProperty(perm)) {
            var checkbox = document.getElementById(CHECKBOX_ID_MAP[perm]);
            if (checkbox && checkbox.checked) selected.push(perm);
        }
    }
    return selected;
}
function setPermissionsCheckboxesEnabled(enabled) {
    for (var checkboxId in CHECKBOX_ID_MAP) {
        if (CHECKBOX_ID_MAP.hasOwnProperty(checkboxId)) {
            var checkbox = document.getElementById(CHECKBOX_ID_MAP[checkboxId]);
            if (checkbox) {
                checkbox.disabled = !enabled;
                checkbox.style.opacity = enabled ? "1" : "0.5";
            }
        }
    }
}

// ============================================================================
// MODAL AJOUT / MODIF
// ============================================================================
async function openAddUserModal(event) {
    if (event) { event.preventDefault(); event.stopPropagation(); }

    var licenceInfo = await checkLicenceLimit();
    if (licenceInfo.reached) {
        showLicenceLimitAlert(licenceInfo.current, licenceInfo.max);
        return false;
    }

    currentMode = "ajout";
    currentUserId = null;
    resetModalForm();

    var usernameField = document.getElementById("username");
    if (usernameField) {
        usernameField.disabled = false;
        usernameField.style.backgroundColor = "#ffffff";
        usernameField.style.cursor = "text";
    }
    var passwordField = document.getElementById("userPassword");
    if (passwordField) {
        passwordField.required = true;
        passwordField.placeholder = T('users.msg.password_placeholder_new', 'Mot de passe (min. 8 caractères)');
    }

    var defaultRole = document.getElementById("userRole")?.value || "1";
    applyDefaultPermissionsByRole(defaultRole);

    document.querySelector("#userModalTitle").innerHTML =
        '<i class="fas fa-user-plus"></i> ' + T('users.modal.add_title', 'Ajouter un utilisateur');
    showModal();
    return false;
}

function openEditUserModal(userId, event) {
    if (event) { event.preventDefault(); event.stopPropagation(); }
    var user = findUserById(userId);
    if (!user) {
        Swal.fire({
            icon: "error",
            title: T('users.msg.error_title', 'Erreur'),
            text: T('users.msg.user_not_found', 'Utilisateur introuvable')
        });
        return;
    }

    currentMode = "modification";
    currentUserId = userId;

    document.getElementById("username").value      = user.USERNAME || "";
    document.getElementById("Nom").value           = user.NOM || "";
    document.getElementById("userEmail").value     = user.EMAIL || "";
    document.getElementById("userTelephone").value = user.TELEPHONE || "";
    document.getElementById("userPassword").value  = "";
    document.getElementById("userStatut").value =
        (user.ACTIVE === true || user.ACTIVE === 1 || user.ACTIVE === "true") ? "Actif" : "Inactif";

    var roleSelect = document.getElementById("userRole");
    if (roleSelect) {
        roleSelect.value = String(user.ROLEID);
        if (roleSelect.value !== String(user.ROLEID)) {
            console.error("❌ Option manquante dans #userRole pour ROLEID=" + user.ROLEID);
            Swal.fire({
                icon: "error",
                title: T('users.msg.role_error_title', 'Erreur de rôle'),
                text: T('users.msg.role_missing_option',
                        "Le rôle ROLEID={id} n'existe pas dans la liste.",
                        { id: user.ROLEID })
            });
        }
    }

    var passwordField = document.getElementById("userPassword");
    if (passwordField) {
        passwordField.required = false;
        passwordField.placeholder = T('users.msg.password_placeholder_keep',
                                      'Laisser vide pour conserver le mot de passe actuel');
    }

    var usernameField = document.getElementById("username");
    if (usernameField) {
        usernameField.disabled = true;
        usernameField.style.backgroundColor = "#e9ecef";
        usernameField.style.cursor = "not-allowed";
    }

    var userPermissions = user.PERMISSIONS || [];
    if (userPermissions.length > 0) setPermissionsCheckboxes(userPermissions);
    else applyDefaultPermissionsByRole(user.ROLEID);
    setPermissionsCheckboxesEnabled(true);

    document.querySelector("#userModalTitle").innerHTML =
        '<i class="fas fa-user-edit"></i> ' + T('users.modal.edit_title', "Modifier l'utilisateur");
    showModal();
    return false;
}

function resetModalForm() {
    ["username", "Nom", "userEmail", "userTelephone", "userPassword"].forEach(function (field) {
        var el = document.getElementById(field);
        if (el) el.value = "";
    });
    var roleSelect = document.getElementById("userRole");
    if (roleSelect) roleSelect.value = "1";
    var statutSelect = document.getElementById("userStatut");
    if (statutSelect) statutSelect.value = "Actif";
    setPermissionsCheckboxes([]);
    setPermissionsCheckboxesEnabled(true);
}

// ============================================================================
// CRÉATION / MODIFICATION
// ============================================================================
async function createUserFromModal() {
    var licenceInfo = await checkLicenceLimit();
    if (licenceInfo.reached) { showLicenceLimitAlert(licenceInfo.current, licenceInfo.max); return; }

    var username  = document.getElementById("username")?.value.trim() || "";
    var nom       = document.getElementById("Nom")?.value.trim() || "";
    var email     = document.getElementById("userEmail")?.value.trim() || "";
    var role      = document.getElementById("userRole")?.value || "";
    var telephone = document.getElementById("userTelephone")?.value.trim() || "";
    var password  = document.getElementById("userPassword")?.value.trim() || "";
    var statut    = document.getElementById("userStatut")?.value || "Actif";
    var permissions = getSelectedPermissions();

    if (!username || !nom || !email || !password) {
        Swal.fire({
            icon: "error",
            title: T('users.msg.missing_fields', 'Champs manquants'),
            text:  T('users.msg.missing_fields_text', 'Veuillez remplir tous les champs obligatoires.')
        });
        return;
    }
    if (password.length < 8) {
        Swal.fire({
            icon: "error",
            title: T('users.msg.password_too_short', 'Mot de passe trop court'),
            text:  T('users.msg.password_too_short_text', 'Le mot de passe doit contenir au moins 8 caractères.')
        });
        return;
    }
    var emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        Swal.fire({
            icon: "error",
            title: T('users.msg.email_invalid', 'Email invalide'),
            text:  T('users.msg.email_invalid_text', 'Veuillez entrer une adresse email valide.')
        });
        return;
    }

    var roleId = getRoleId(role);
    if (roleId === null || roleId === undefined) {
        Swal.fire({
            icon: "error",
            title: T('users.msg.role_invalid', 'Rôle invalide'),
            text:  T('users.msg.role_invalid_text',
                     'Le rôle sélectionné est introuvable. Valeur reçue : "{value}"',
                     { value: role })
        });
        return;
    }

    showSpinner();
    var body = {
        USERNAME: username, NOM: nom, PWD: password, EMAIL: email,
        TELEPHONE: telephone, ROLEID: roleId,
        ACTIVE: statut === "Actif" ? 1 : 0,
        PERMISSIONS: permissions
    };

    try {
        var res  = await fetch(apiUrl(API_USERS.create), {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body)
        });
        var data = await safeJson(res);
        if (data.success) {
            Swal.fire({
                icon: "success",
                title: T('users.msg.success_title', 'Succès'),
                text: data.message,
                timer: 1500, showConfirmButton: false
            });
            setTimeout(function () { closeAddUserModal(); loadUsers(); }, 1500);
        } else {
            Swal.fire({ icon: "error", title: T('users.msg.error_title', 'Erreur'), text: data.message });
        }
    } catch (err) {
        Swal.fire({ icon: "error", title: T('users.msg.error_title', 'Erreur'), text: err.message });
    } finally {
        hideSpinner();
    }
}

async function updateUserFromModal() {
    var nom       = document.getElementById("Nom")?.value.trim() || "";
    var email     = document.getElementById("userEmail")?.value.trim() || "";
    var role      = document.getElementById("userRole")?.value || "";
    var telephone = document.getElementById("userTelephone")?.value.trim() || "";
    var password  = document.getElementById("userPassword")?.value.trim() || "";
    var statut    = document.getElementById("userStatut")?.value || "Actif";
    var permissions = getSelectedPermissions();

    if (!nom || !email) {
        Swal.fire({
            icon: "error",
            title: T('users.msg.missing_fields', 'Champs manquants'),
            text:  T('users.msg.missing_fields_text', 'Veuillez remplir tous les champs obligatoires.')
        });
        return;
    }
    var emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        Swal.fire({
            icon: "error",
            title: T('users.msg.email_invalid', 'Email invalide'),
            text:  T('users.msg.email_invalid_text', 'Veuillez entrer une adresse email valide.')
        });
        return;
    }
    if (password && password.length < 8) {
        Swal.fire({
            icon: "error",
            title: T('users.msg.password_too_short', 'Mot de passe trop court'),
            text:  T('users.msg.password_too_short_text', 'Le mot de passe doit contenir au moins 8 caractères.')
        });
        return;
    }

    var roleId = getRoleId(role);
    if (roleId === null || roleId === undefined) {
        Swal.fire({
            icon: "error",
            title: T('users.msg.role_invalid', 'Rôle invalide'),
            text:  T('users.msg.role_invalid_text',
                     'Le rôle sélectionné est introuvable. Valeur reçue : "{value}"',
                     { value: role })
        });
        return;
    }

    var user = findUserById(currentUserId);
    var etaitInactif = user && user.ACTIVE !== true && user.ACTIVE !== 1 && user.ACTIVE !== "true";
    var deviensActif = etaitInactif && statut === "Actif";

    if (deviensActif) {
        var licenceInfo = await checkLicenceLimit();
        if (licenceInfo.reached) { showLicenceLimitAlert(licenceInfo.current, licenceInfo.max); return; }
    }

    showSpinner();
    var params = new URLSearchParams();
    params.append("id", currentUserId);
    params.append("nom", nom);
    params.append("email", email);
    params.append("roleId", roleId);
    params.append("telephone", telephone);
    params.append("active", statut === "Actif" ? 1 : 0);
    params.append("permissions", JSON.stringify(permissions));
    if (password) params.append("password", password);

    try {
        var res = await fetch(apiUrl(API_USERS.update + "?" + params.toString()), { method: "POST" });
        var result = await safeJson(res);
        if (result.success || result.status === "success") {
            Swal.fire({
                icon: "success",
                title: T('users.msg.success_title', 'Succès'),
                text:  T('users.msg.user_updated', 'Utilisateur modifié !'),
                timer: 1500, showConfirmButton: false
            });
            setTimeout(function () { closeAddUserModal(); loadUsers(); }, 1500);
        } else {
            Swal.fire({ icon: "error", title: T('users.msg.error_title', 'Erreur'), text: result.message });
        }
    } catch (err) {
        Swal.fire({ icon: "error", title: T('users.msg.error_title', 'Erreur'), text: err.message });
    } finally {
        hideSpinner();
    }
}

async function saveUser(event) {
    if (event) { event.preventDefault(); event.stopPropagation(); }
    if (currentMode === "modification")      await updateUserFromModal();
    else if (currentMode === "ajout")        await createUserFromModal();
    else Swal.fire({
        icon: "warning",
        title: T('users.msg.no_action', 'Aucune action'),
        text:  T('users.msg.no_action_text', 'Veuillez sélectionner "Ajouter" ou "Modifier" d\'abord')
    });
    return false;
}

// ============================================================================
// SUPPRESSION
// ============================================================================
async function supprimerContact(id, event) {
    if (event) { event.preventDefault(); event.stopPropagation(); }
    var result = await Swal.fire({
        title: T('users.msg.delete_confirm', 'Voulez-vous vraiment supprimer cet utilisateur ?'),
        text:  T('users.msg.delete_confirm', 'Voulez-vous vraiment supprimer cet utilisateur ?'),
        icon: "warning",
        showCancelButton: true,
        confirmButtonText: T('users.msg.delete_yes', 'Oui, supprimer'),
        cancelButtonText:  T('button.cancel', 'Annuler'),
        confirmButtonColor: "#d33"
    });

    if (result.isConfirmed) {
        showSpinner();
        try {
            var res = await fetch(apiUrl(API_USERS.delete), {
                method: "POST",
                headers: { "Content-Type": "application/x-www-form-urlencoded" },
                body: "id=" + encodeURIComponent(id)
            });
            var text = await res.text();
            var cleanText = text.replace(/[\uFEFF\uFFFE\u200B\u200C\u200D\u2060]/g, "")
                                 .replace(/ï»¿/g, "").replace(/﻿/g, "").trim();

            if (cleanText.indexOf('"success":true') !== -1 ||
                cleanText.indexOf('"status":"success"') !== -1) {
                Swal.fire({
                    icon: "success",
                    title: T('users.msg.success_title', 'Supprimé'),
                    text:  T('users.msg.user_deleted', 'Utilisateur supprimé'),
                    timer: 1500, showConfirmButton: false
                });
                setTimeout(function () { loadUsers(); }, 1500);
            } else {
                var errorMatch = cleanText.match(/"message":"([^"]+)"/);
                var errorMsg = errorMatch ? errorMatch[1] : T('users.msg.delete_failed', 'Erreur lors de la suppression');
                Swal.fire({ icon: "error", title: T('users.msg.error_title', 'Erreur'), text: errorMsg });
            }
        } catch (err) {
            Swal.fire({ icon: "error", title: T('users.msg.error_title', 'Erreur'), text: err.message });
        } finally {
            hideSpinner();
        }
    }
    return false;
}

// ============================================================================
// BACKUP
// ============================================================================
async function backupDatabase() {
    var userRole = document.getElementById("hfUserRole")?.value;
    if (userRole !== "0") {
        Swal.fire({
            icon: "error",
            title: T('users.backup.access_denied', 'Accès refusé'),
            text:  T('users.backup.access_denied_text', 'Seul un Super Admin peut effectuer une sauvegarde.'),
            confirmButtonColor: "#dc3545"
        });
        return;
    }

    var result = await Swal.fire({
        title: T('users.backup.plan_title', '🔄 Planifier la sauvegarde'),
        html:
            '<div style="text-align:left;font-size:12px;">' +
                '<div style="margin-top:15px;padding:10px;background:#d1ecf1;border-left:4px solid #17a2b8;border-radius:5px;">' +
                    '<p><strong>' + T('users.backup.warning_title', '⚠️ Attention :') + '</strong></p>' +
                    '<ul>' +
                        '<li>' + T('users.backup.warning_1', '...') + '</li>' +
                        '<li>' + T('users.backup.warning_2', '...') + '</li>' +
                        '<li>' + T('users.backup.warning_3', '...') + '</li>' +
                        '<li>' + T('users.backup.warning_4', '...') + '</li>' +
                    '</ul>' +
                '</div>' +
                '<br>' +
                '<label for="backupTime" style="font-weight:bold;">' + T('users.backup.time_label', '📅 Heure de la sauvegarde :') + '</label>' +
                '<input type="time" id="backupTime" class="swal2-input" value="' + getDefaultTime() + '">' +
                '<p style="font-size:12px;color:#6c757d;margin-top:5px;">' +
                    '<i class="fas fa-info-circle" style="color:#ff0000;"></i> ' +
                    T('users.backup.time_info', '...') +
                '</p>' +
                '<div style="margin-top:15px;padding:10px;background:#d1ecf1;border-left:4px solid #17a2b8;border-radius:5px;">' +
                    '<label style="display:flex;align-items:center;gap:10px;cursor:pointer;">' +
                        '<input type="checkbox" id="blockUsers" checked style="width:18px;height:18px;">' +
                        '<span style="font-weight:bold;">' + T('users.backup.block_users', '🔒 Bloquer les connexions après la déconnexion') + '</span>' +
                    '</label>' +
                    '<p style="font-size:12px;color:#0c5460;margin:5px 0 0 28px;">' +
                        T('users.backup.block_users_hint', '...') +
                    '</p>' +
                '</div>' +
                '<div style="margin-top:15px;padding:8px;background:#e8f4fd;border-radius:5px;text-align:center;">' +
                    '<i class="fas fa-hourglass-half"></i> ' +
                    T('users.backup.countdown_hint', '...') +
                '</div>' +
            '</div>',
        icon: "warning",
        showCancelButton: true,
        confirmButtonText: T('users.backup.confirm_btn', '📀 Planifier la sauvegarde'),
        cancelButtonText:  T('users.backup.cancel_btn', 'Annuler'),
        confirmButtonColor: "#28a745",
        cancelButtonColor: "#dc3545",
        didOpen: function () {
            var confirmBtn = Swal.getConfirmButton();
            confirmBtn.disabled = true;
            confirmBtn.style.opacity = "0.6";
            confirmBtn.style.cursor = "not-allowed";

            var countdownDisplay = document.getElementById("countdownDisplay");
            var seconds = 5;
            var interval = setInterval(function () {
                seconds--;
                if (countdownDisplay) countdownDisplay.textContent = seconds;
                if (confirmBtn) confirmBtn.textContent = T('users.backup.confirm_countdown', '📀 Planifier ({n}s)', { n: seconds });
                if (seconds <= 0) {
                    clearInterval(interval);
                    if (confirmBtn) {
                        confirmBtn.textContent = T('users.backup.confirm_btn', '📀 Planifier la sauvegarde');
                        confirmBtn.disabled = false;
                        confirmBtn.style.opacity = "1";
                        confirmBtn.style.cursor = "pointer";
                    }
                    if (countdownDisplay) {
                        countdownDisplay.textContent = "0";
                        countdownDisplay.style.color = "#28a745";
                    }
                }
            }, 1000);
            window._backupCountdownInterval = interval;
        },
        willClose: function () {
            if (window._backupCountdownInterval) clearInterval(window._backupCountdownInterval);
        },
        preConfirm: function () {
            var time = document.getElementById("backupTime").value;
            var blockUsers = document.getElementById("blockUsers")?.checked || false;
            if (!time) {
                Swal.showValidationMessage(T('users.backup.time_required', 'Veuillez sélectionner une heure'));
                return false;
            }
            return { time: time, blockUsers: blockUsers };
        }
    });

    if (!result.isConfirmed) return;
    var selectedTime = result.value.time;
    var blockUsers   = result.value.blockUsers;

    showSpinner();
    try {
        await fetch(apiUrl(API_USERS.backup + "?action=prepare&time=" +
            encodeURIComponent(selectedTime) + "&block=" + blockUsers));

        await notifyAllUsers(
            T('users.backup.notify_msg', '⚠️ MAINTENANCE PROGRAMMÉE - Sauvegarde à {time}', { time: selectedTime }),
            selectedTime
        );

        await Swal.fire({
            title: T('users.backup.scheduled_title', '✅ Sauvegarde programmée'),
            html:
                '<div style="text-align:center;">' +
                    '<p>' + T('users.backup.scheduled_text', 'La sauvegarde est programmée à <strong>{time}</strong>', { time: selectedTime }) + '</p>' +
                    '<p class="swal2-text" style="font-size:14px;color:#28a745;">' +
                        '<i class="fas fa-check-circle"></i> ' + T('users.backup.scheduled_hint', '...') +
                    '</p>' +
                    '<div style="margin:20px 0;background:#f8f9fa;padding:15px;border-radius:8px;">' +
                        '<div style="font-size:14px;color:#6c757d;">' + T('users.backup.remaining', '⏳ Temps restant avant la déconnexion') + '</div>' +
                        '<div style="font-size:48px;font-weight:bold;font-family:monospace;color:#dc3545;" id="adminCountdownDisplay">--:--</div>' +
                        '<div style="height:8px;background:#e9ecef;border-radius:4px;margin-top:10px;overflow:hidden;">' +
                            '<div id="adminProgressBar" style="width:0%;height:100%;background:#dc3545;transition:width 1s linear;"></div>' +
                        '</div>' +
                    '</div>' +
                    '<p style="font-size:12px;color:#6c757d;">' +
                        '<i class="fas fa-info-circle"></i> ' +
                        T('users.backup.scheduled_footer', 'Les utilisateurs seront déconnectés automatiquement à <strong>{time}</strong>', { time: selectedTime }) +
                    '</p>' +
                '</div>',
            icon: "info",
            showConfirmButton: false,
            allowOutsideClick: false,
            didOpen: function () { startAdminCountdown(selectedTime); }
        });
    } catch (err) {
        await Swal.fire({
            icon: "error",
            title: T('users.msg.error_title', 'Erreur'),
            text: err.message,
            confirmButtonText: T('users.msg.ok', 'OK')
        });
    } finally {
        hideSpinner();
        if (window._backupCountdownInterval) clearInterval(window._backupCountdownInterval);
    }
}

function startAdminCountdown(targetTime) {
    if (window.adminCountdownTimer) clearInterval(window.adminCountdownTimer);
    var target = new Date();
    var parts = targetTime.split(":");
    target.setHours(parseInt(parts[0]), parseInt(parts[1]), 0, 0);
    if (target < new Date()) target.setDate(target.getDate() + 1);
    var maxDuration = 24 * 60 * 60 * 1000;

    window.adminCountdownTimer = setInterval(function () {
        var now = new Date();
        var diff = target - now;
        if (diff <= 0) {
            clearInterval(window.adminCountdownTimer);
            executeScheduledBackup();
        } else {
            var hoursLeft   = Math.floor(diff / 3600000);
            var minutesLeft = Math.floor((diff % 3600000) / 60000);
            var secondsLeft = Math.floor((diff % 60000) / 1000);
            var totalSeconds = Math.floor(diff / 1000);
            var percent = Math.min(100, (1 - totalSeconds / maxDuration) * 100);
            var countdownEl = document.getElementById("adminCountdownDisplay");
            var progressEl  = document.getElementById("adminProgressBar");
            if (countdownEl) {
                countdownEl.textContent = String(hoursLeft).padStart(2, "0") + ":" +
                                          String(minutesLeft).padStart(2, "0") + ":" +
                                          String(secondsLeft).padStart(2, "0");
                if (diff < 300000) countdownEl.style.color = "#ff6b6b";
            }
            if (progressEl) progressEl.style.width = percent + "%";
        }
    }, 1000);
}

async function executeScheduledBackup() {
    console.log(T('users.backup.executing', "⏰ Heure programmée atteinte - Exécution de la sauvegarde..."));
    var spinner = document.getElementById("spinnerOverlay");
    if (spinner) spinner.style.display = "flex";

    try {
        var response = await fetch(apiUrl(API_USERS.backup + "?action=execute"));
        if (response.ok) {
            var contentType = response.headers.get("content-type");
            if (contentType && contentType.indexOf("application/octet-stream") !== -1) {
                var filename = "backup_" + new Date().toISOString().slice(0, 19).replace(/:/g, "-") + ".bak";
                var blob = await response.blob();
                var fileSize = (blob.size / 1024 / 1024).toFixed(2);
                var url = window.URL.createObjectURL(blob);
                var a = document.createElement("a");
                a.href = url; a.download = filename;
                document.body.appendChild(a); a.click();
                document.body.removeChild(a); window.URL.revokeObjectURL(url);

                await Swal.fire({
                    icon: "success",
                    title: T('users.backup.done_title', '✅ Sauvegarde terminée'),
                    html:
                        '<div style="text-align:left;">' +
                            '<p><strong>' + T('users.backup.done_intro', '...') + '</strong></p>' +
                            '<hr style="margin:15px 0;">' +
                            '<p><i class="fas fa-database"></i> <strong>' + T('users.backup.done_file', 'Fichier :') + '</strong> ' + filename + '</p>' +
                            '<p><i class="fas fa-hdd"></i> <strong>' + T('users.backup.done_size', 'Taille :') + '</strong> ' + fileSize + ' Mo</p>' +
                            '<p><i class="fas fa-folder-open"></i> <strong>' + T('users.backup.done_location', 'Emplacement :') + '</strong> App_Data/Backups/</p>' +
                        '</div>',
                    confirmButtonText: T('users.msg.ok', 'OK'),
                    confirmButtonColor: "#28a745"
                });

                await fetch(apiUrl(API_USERS.backup + "?action=check"));
                location.reload();
            } else {
                var error = await response.json();
                await Swal.fire({
                    icon: "error", title: T('users.msg.error_title', 'Erreur'),
                    text: error.message || T('users.backup.error_default', 'Erreur lors de la sauvegarde'),
                    confirmButtonText: T('users.msg.ok', 'OK')
                });
            }
        } else {
            var error2 = await response.json();
            await Swal.fire({
                icon: "error", title: T('users.msg.error_title', 'Erreur'),
                text: error2.message || T('users.backup.error_server', 'Erreur serveur'),
                confirmButtonText: T('users.msg.ok', 'OK')
            });
        }
    } catch (err) {
        await Swal.fire({
            icon: "error", title: T('users.msg.error_title', 'Erreur'),
            text: err.message, confirmButtonText: T('users.msg.ok', 'OK')
        });
    } finally {
        if (spinner) spinner.style.display = "none";
        if (window.backupCountdownTimer) clearInterval(window.backupCountdownTimer);
    }
}

// ============================================================================
// RESTAURATION
// ============================================================================
async function openRestoreModal() {
    var userRole = document.getElementById("hfUserRole")?.value;
    if (userRole !== "0") {
        Swal.fire({
            icon: "error",
            title: T('users.restore.access_denied', 'Accès refusé'),
            text:  T('users.restore.access_denied_text', 'Seul un Super Admin peut restaurer la base de données.'),
            confirmButtonColor: "#dc3545"
        });
        return;
    }

    document.getElementById("restoreFilePath").value = "";
    document.getElementById("restoreFileInput").value = "";
    document.getElementById("restoreProgressContainer").style.display = "none";
    document.getElementById("restoreLogs").style.display = "none";
    document.getElementById("restoreStep2").style.display = "none";
    document.getElementById("btnRestoreExecute").disabled = true;
    selectedRestoreFile = null;
    selectedRestoreSource = null;
    restoreLogs = [];

    document.getElementById("restoreLogContent").innerHTML =
        '<div style="color:#4ec9b0;">' + T('users.restore.init_log', '[INFO] Initialisation de la restauration...') + '</div>';

    window._restoreDbName = null;
    try {
        var r = await fetch(apiUrl(API_USERS.restore + "?action=dbname"));
        var d = await r.json();
        if (d && d.success && d.database) {
            window._restoreDbName = d.database;
            console.log("🗄️ Base de données détectée :", d.database);
        }
    } catch (e) { /* ignore */ }

    loadBackupList();

    if (typeof window.openModal === "function") window.openModal("restoreModal");
    else {
        var modal = document.getElementById("restoreModal");
        if (modal) { modal.style.display = "flex"; document.body.style.overflow = "hidden"; }
    }
}

function selectRestoreSource(source) {
    selectedRestoreSource = source;
    document.getElementById("btnSourceLocal").className  = source === "local"  ? "btn btn-primary" : "btn btn-secondary";
    document.getElementById("btnSourceBackup").className = source === "backup" ? "btn btn-primary" : "btn btn-secondary";
    document.getElementById("restoreSourceLocal").style.display  = source === "local"  ? "block" : "none";
    document.getElementById("restoreSourceBackup").style.display = source === "backup" ? "block" : "none";
    document.getElementById("restoreStep2").style.display = "none";
    document.getElementById("btnRestoreExecute").disabled = true;
    selectedRestoreFile = null;
}

function loadBackupList() {
    var container = document.getElementById("backupList");
    container.innerHTML = '<p style="text-align:center;color:#6c757d;">' +
        T('users.restore.loading_backups', 'Chargement des sauvegardes...') + '</p>';

    fetch(apiUrl(API_USERS.getBackupList))
        .then(function (r) { return r.json(); })
        .then(function (data) {
            if (data.success && data.backups && data.backups.length > 0) {
                var html = "";
                data.backups.forEach(function (backup) {
                    var isSelected = selectedRestoreFile && selectedRestoreFile.path === backup.path ? "selected" : "";
                    var sizeMB = (backup.size / 1024 / 1024).toFixed(2);
                    html +=
                        '<div class="backup-item" onclick="selectBackupFile(\'' + escapeHtml(backup.path) + '\', \'' +
                        escapeHtml(backup.name) + '\', ' + backup.size + ', \'' + escapeHtml(backup.date) + '\')" ' +
                             'style="padding:10px;border-bottom:1px solid #dee2e6;cursor:pointer;transition:background 0.2s;' +
                             (isSelected ? 'background:#e8f4fd;' : '') + '">' +
                            '<div style="display:flex;justify-content:space-between;align-items:center;">' +
                                '<div>' +
                                    '<strong>' + escapeHtml(backup.name) + '</strong>' +
                                    '<div style="font-size:11px;color:#6c757d;">' + escapeHtml(backup.date) + ' - ' + sizeMB + ' Mo</div>' +
                                '</div>' +
                                '<div>' +
                                    '<span class="badge bg-success" style="background:#28a745;color:white;padding:3px 10px;border-radius:12px;font-size:11px;">' +
                                        escapeHtml(backup.status || T('users.restore.available_badge', 'Disponible')) +
                                    '</span>' +
                                '</div>' +
                            '</div>' +
                        '</div>';
                });
                container.innerHTML = html;

                var countInfo = document.createElement("div");
                countInfo.style.cssText = "padding:8px 10px;font-size:12px;color:#6c757d;border-top:1px solid #dee2e6;margin-top:5px;";
                countInfo.innerHTML = '<i class="fas fa-database"></i> ' +
                    T('users.restore.count_label', '{n} sauvegarde(s) disponible(s)', { n: data.backups.length });
                container.appendChild(countInfo);
            } else {
                container.innerHTML =
                    '<div style="text-align:center;padding:30px 20px;color:#6c757d;">' +
                        '<i class="fas fa-folder-open" style="font-size:48px;color:#dee2e6;display:block;margin-bottom:15px;"></i>' +
                        '<p>' + T('users.restore.no_backup_available', 'Aucune sauvegarde disponible') + '</p>' +
                        '<p style="font-size:12px;">' + T('users.restore.no_backup_hint', '...') + '</p>' +
                        '<p style="font-size:12px;color:#adb5bd;">' + (data.message || "") + '</p>' +
                    '</div>';
            }
        })
        .catch(function (err) {
            container.innerHTML =
                '<div style="text-align:center;padding:30px 20px;color:#dc3545;">' +
                    '<i class="fas fa-exclamation-triangle" style="font-size:48px;display:block;margin-bottom:15px;"></i>' +
                    '<p>' + T('users.restore.load_error', 'Erreur de chargement') + '</p>' +
                    '<p style="font-size:12px;">' + err.message + '</p>' +
                '</div>';
        });
}

function selectBackupFile(path, name, size, date) {
    selectedRestoreFile = { path: path, name: name, size: size, date: date };
    selectedRestoreSource = "backup";
    document.querySelectorAll(".backup-item").forEach(function (el) {
        el.style.background = el.textContent.indexOf(name) !== -1 ? "#e8f4fd" : "";
    });
    showRestoreInfo(name, size, date);
    document.getElementById("btnRestoreExecute").disabled = false;
}

function handleRestoreFileSelect(event) {
    var file = event.target.files[0];
    if (!file) return;

    if (!file.name.toLowerCase().endsWith(".bak")) {
        Swal.fire({
            icon: "error",
            title: T('users.restore.file_invalid', 'Fichier invalide'),
            text:  T('users.restore.file_invalid_text', 'Veuillez sélectionner un fichier .bak'),
            confirmButtonColor: "#dc3545"
        });
        document.getElementById("restoreFileInput").value = "";
        return;
    }

    var maxSize = 100 * 1024 * 1024;
    if (file.size > maxSize) {
        Swal.fire({
            icon: "error",
            title: T('users.restore.file_too_big', 'Fichier trop volumineux'),
            text:  T('users.restore.file_too_big_text', 'La taille maximale est de 100 Mo'),
            confirmButtonColor: "#dc3545"
        });
        document.getElementById("restoreFileInput").value = "";
        return;
    }

    selectedRestoreFile = {
        path: null, name: file.name, size: file.size,
        date: new Date().toLocaleString(), file: file, source: "local"
    };
    selectedRestoreSource = "local";

    document.getElementById("restoreFilePath").value = file.name;
    showRestoreInfo(file.name, file.size, new Date().toLocaleString());
    document.getElementById("btnRestoreExecute").disabled = false;
}

function showRestoreInfo(name, size, date) {
    document.getElementById("restoreStep2").style.display = "block";
    document.getElementById("restoreFileInfo").textContent = name;
    document.getElementById("restoreSizeInfo").textContent = (size / 1024 / 1024).toFixed(2) + " Mo";
    document.getElementById("restoreDateInfo").textContent = date || new Date().toLocaleString();
}

function addLog(message, type) {
    type = type || "info";
    var colors = { info: "#4ec9b0", warning: "#dcdcaa", error: "#f44747", success: "#4ec9b0" };
    var icons  = { info: "ℹ️", warning: "⚠️", error: "❌", success: "✅" };
    restoreLogs.push({ message: message, type: type, time: new Date().toLocaleTimeString() });

    var logContainer = document.getElementById("restoreLogContent");
    var logEntry = document.createElement("div");
    logEntry.style.color = colors[type] || "#d4d4d4";
    logEntry.textContent = "[" + new Date().toLocaleTimeString() + "] " + (icons[type] || "•") + " " + message;
    logContainer.appendChild(logEntry);
    logContainer.scrollTop = logContainer.scrollHeight;
}

async function executeRestore() {
    if (!selectedRestoreFile) {
        Swal.fire({
            icon: "warning",
            title: T('users.restore.missing_file', 'Fichier manquant'),
            text:  T('users.restore.missing_file_text', 'Veuillez sélectionner un fichier .bak'),
            confirmButtonColor: "#ffc107"
        });
        return;
    }

    var dbNameRow = window._restoreDbName
        ? "<li>" + T('users.restore.confirm_db', 'Base de données :') + " <strong>" +
              escapeHtml(window._restoreDbName) + "</strong></li>"
        : "";

    var result = await Swal.fire({
        title: T('users.restore.confirm_title', '⚠️ Confirmation'),
        html:
            '<div style="text-align:left;">' +
                '<p><strong>' + T('users.restore.confirm_intro', 'Cette action va remplacer la base de données actuelle.') + '</strong></p>' +
                '<ul style="color:#6c757d;">' +
                    '<li>' + T('users.restore.confirm_file', 'Fichier :') + ' <strong>' +
                        escapeHtml(selectedRestoreFile.name) + '</strong></li>' +
                    dbNameRow +
                    '<li>' + T('users.restore.confirm_size', 'Taille :') + ' <strong>' +
                        (selectedRestoreFile.size / 1024 / 1024).toFixed(2) + ' Mo</strong></li>' +
                '</ul>' +
                '<p style="color:#dc3545;font-weight:bold;padding:10px;background:#fff3cd;border-radius:5px;">' +
                    '<i class="fas fa-exclamation-triangle"></i> ' +
                    T('users.restore.confirm_warning', 'Tous les utilisateurs seront déconnectés et la base sera remplacée.') +
                '</p>' +
            '</div>',
        icon: "warning",
        showCancelButton: true,
        confirmButtonText: T('users.restore.confirm_yes', 'Oui, restaurer'),
        cancelButtonText:  T('users.restore.cancel_btn',  'Annuler'),
        confirmButtonColor: "#dc3545",
        cancelButtonColor:  "#6c757d",
        allowOutsideClick: false,
        allowEscapeKey: false
    });

    if (!result.isConfirmed) return;

    document.getElementById("restoreProgressContainer").style.display = "block";
    document.getElementById("restoreLogs").style.display = "block";
    document.getElementById("restoreProgressBar").style.width = "0%";
    document.getElementById("restoreProgressPercent").textContent = "0%";
    document.getElementById("restoreStatusMessage").textContent =
        T('users.restore.progress_init', 'Initialisation de la restauration...');
    document.getElementById("btnRestoreExecute").disabled = true;

    showSpinner();
    addLog(T('users.restore.log_start', 'Début de la restauration'), "info");
    addLog(T('users.restore.log_file_selected', 'Fichier sélectionné: {name}', { name: selectedRestoreFile.name }), "info");

    try {
        var filePath = null;

        if (selectedRestoreSource === "local" && selectedRestoreFile.file) {
            addLog(T('users.restore.log_uploading', 'Upload du fichier en cours...'), "info");
            document.getElementById("restoreStatusMessage").textContent = T('users.restore.progress_upload', 'Upload du fichier...');
            document.getElementById("restoreProgressBar").style.width = "20%";
            document.getElementById("restoreProgressPercent").textContent = "20%";

            var formData = new FormData();
            formData.append("backupFile", selectedRestoreFile.file);

            var uploadResponse = await fetch(apiUrl(API_USERS.restoreUpload), { method: "POST", body: formData });
            var uploadData = await uploadResponse.json();
            if (!uploadData.success) {
                addLog(T('users.restore.log_upload_error', 'Erreur upload: {message}', { message: uploadData.message }), "error");
                throw new Error(uploadData.message);
            }
            filePath = uploadData.filePath;
            addLog(T('users.restore.log_upload_ok', 'Fichier uploadé avec succès: {path}', { path: filePath }), "success");
            document.getElementById("restoreProgressBar").style.width = "40%";
            document.getElementById("restoreProgressPercent").textContent = "40%";
        } else if (selectedRestoreSource === "backup") {
            filePath = selectedRestoreFile.path.replace(/\\/g, "/");
            addLog(T('users.restore.log_using_backup', 'Utilisation de la sauvegarde: {path}', { path: filePath }), "info");
        }

        if (filePath) filePath = filePath.replace(/\\/g, "/");
        if (!filePath) {
            addLog(T('users.restore.log_no_path', 'Erreur: Aucun chemin de fichier disponible'), "error");
            throw new Error(T('users.restore.no_file_path', 'Aucun fichier disponible pour la restauration'));
        }

        var checkResponse = await fetch(apiUrl(API_USERS.checkFile + "?path=" + encodeURIComponent(filePath)));
        var checkData = await checkResponse.json();
        if (!checkData.exists) {
            addLog(T('users.restore.log_file_missing', 'Erreur: Le fichier n\'existe pas: {path}', { path: filePath }), "error");
            throw new Error(T('users.restore.file_not_exists', 'Le fichier de sauvegarde n\'existe pas'));
        }
        addLog(T('users.restore.log_file_checked', 'Fichier vérifié avec succès'), "success");

        addLog(T('users.restore.log_logout', 'Déconnexion des utilisateurs...'), "warning");
        document.getElementById("restoreStatusMessage").textContent = T('users.restore.progress_logout', 'Déconnexion des utilisateurs...');
        document.getElementById("restoreProgressBar").style.width = "50%";
        document.getElementById("restoreProgressPercent").textContent = "50%";

        var requestBody = {
            fileName: selectedRestoreFile.name,
            filePath: filePath,
            source: selectedRestoreSource
        };
        addLog(T('users.restore.log_path', 'Chemin du fichier: {path}', { path: filePath }), "info");

        var restoreResponse = await fetch(apiUrl(API_USERS.restore), {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(requestBody)
        });
        var responseText = await restoreResponse.text();
        addLog(T('users.restore.log_response', 'Réponse brute: {text}', { text: responseText.substring(0, 200) }), "info");

        var restoreData;
        try { restoreData = JSON.parse(responseText); }
        catch (parseError) {
            addLog(T('users.restore.log_parse_error', 'Erreur de parsing JSON: {message}', { message: parseError.message }), "error");
            throw new Error(T('users.restore.bad_response', 'Réponse invalide du serveur: {text}', { text: responseText.substring(0, 100) }));
        }

        addLog(T('users.restore.log_running', 'Restauration en cours...'), "info");
        document.getElementById("restoreStatusMessage").textContent = T('users.restore.progress_running', 'Restauration en cours...');
        document.getElementById("restoreProgressBar").style.width = "70%";
        document.getElementById("restoreProgressPercent").textContent = "70%";

        if (restoreData.success) {
            addLog(T('users.restore.log_done', 'Restauration terminée avec succès !'), "success");
            document.getElementById("restoreProgressBar").style.width = "100%";
            document.getElementById("restoreProgressPercent").textContent = "100%";
            document.getElementById("restoreStatusMessage").textContent = T('users.restore.progress_done', '✅ Restauration réussie !');

            if (selectedRestoreSource === "local" && filePath) {
                try { await fetch(apiUrl(API_USERS.deleteFile + "?path=" + encodeURIComponent(filePath))); }
                catch (e) { /* ignore */ }
            }

            await Swal.fire({
                icon: "success",
                title: T('users.restore.ok_title', 'Restauration effectuée avec succès.'),
                confirmButtonText: T('users.msg.ok', 'OK'),
                confirmButtonColor: "#28a745",
                allowOutsideClick: false,
                allowEscapeKey: false
            });

            window.location.href = "../../../auth/Login.aspx?msg=restore";
            return;
        }

        addLog(T('users.restore.log_error', 'Erreur: {message}', { message: restoreData.message || 'Erreur inconnue' }), "error");
        document.getElementById("restoreStatusMessage").textContent = T('users.restore.progress_error', '❌ Erreur de restauration');
        document.getElementById("btnRestoreExecute").disabled = false;

        await Swal.fire({
            icon: "error",
            title: T('users.restore.fail_title', 'Échec de la restauration.'),
            text:  T('users.restore.fail_text', "Veuillez consulter les détails de l'erreur."),
            confirmButtonText: T('users.msg.ok', 'OK'),
            confirmButtonColor: "#dc3545",
            allowOutsideClick: false
        });
        return;
    } catch (error) {
        addLog(T('users.restore.log_error', 'Erreur: {message}', { message: error.message }), "error");
        document.getElementById("restoreStatusMessage").textContent = T('users.restore.progress_critical', '❌ Erreur critique');
        document.getElementById("btnRestoreExecute").disabled = false;

        await Swal.fire({
            icon: "error",
            title: T('users.restore.fail_title', 'Échec de la restauration.'),
            text:  T('users.restore.fail_text', "Veuillez consulter les détails de l'erreur."),
            confirmButtonText: T('users.msg.ok', 'OK'),
            confirmButtonColor: "#dc3545",
            allowOutsideClick: false
        });
    } finally {
        hideSpinner();
        document.getElementById("restoreFileInput").value = "";
    }
}

// ============================================================================
// NOTIFICATIONS
// ============================================================================
async function notifyAllUsers(message, maintenanceTime) {
    try {
        var response = await fetch(apiUrl(API_USERS.notifyMaintenance), {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                message: message || T('users.notify.default_message', '⚠️ Maintenance programmée - Déconnexion imminente'),
                maintenanceTime: maintenanceTime || new Date().toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })
            })
        });
        return await response.json();
    } catch (e) {
        return { success: false, message: e.message };
    }
}

// ============================================================================
// MISES À JOUR
// ============================================================================
async function checkForUpdates() {
    if (updateCheckInProgress) {
        Swal.fire({
            icon: "info",
            title: T('users.updates.in_progress', 'Vérification en cours'),
            text:  T('users.updates.in_progress_text', 'Une vérification des mises à jour est déjà en cours...'),
            timer: 2000, showConfirmButton: false
        });
        return;
    }
    var userRole = document.getElementById("hfUserRole")?.value;
    if (userRole !== "0") {
        Swal.fire({
            icon: "warning",
            title: T('users.updates.access_denied', 'Accès limité'),
            text:  T('users.updates.access_denied_text', 'Seul un Super Admin peut vérifier les mises à jour.'),
            confirmButtonColor: "#ffc107"
        });
        return;
    }

    updateCheckInProgress = true;
    var btn = document.getElementById("btnCheckUpdates");
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> ' + T('users.updates.checking', 'Vérification en cours...');
        btn.style.opacity = "0.7";
    }

    try {
        var response = await fetch(apiUrl(
            API_USERS.checkUpdates + "?action=check&version=" + encodeURIComponent(CURRENT_VERSION)
        ));
        var data = await response.json();
        if (data.success) {
            if (data.hasUpdate) showUpdateAvailableModal(data);
            else showNoUpdateModal(data);
        } else {
            Swal.fire({
                icon: "error",
                title: T('users.updates.error_title', 'Erreur de vérification'),
                text:  data.message || T('users.updates.error_text', 'Impossible de vérifier les mises à jour'),
                confirmButtonColor: "#dc3545"
            });
        }
    } catch (error) {
        simulateUpdateCheck();
    } finally {
        updateCheckInProgress = false;
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-sync-alt"></i> ' + T('users.updates.check_btn', 'Vérifier les MAJ');
            btn.style.opacity = "1";
        }
    }
}

function showUpdateAvailableModal(data) {
    var version = data.latestVersion || "2.2.0";
    var releaseDate = data.releaseDate || new Date().toLocaleDateString("fr-FR");
    var changelog = data.changelog || [];
    var updateSize = data.updateSize || "15.2 Mo";

    Swal.fire({
        title: T('users.updates.available_title', '🆕 Mise à jour disponible !'),
        html:
            '<div style="text-align:left;max-height:400px;overflow-y:auto;font-size:12px;">' +
                '<div style="background:#e8f4fd;padding:12px;border-radius:8px;margin-bottom:15px;">' +
                    '<p style="margin:0;">' +
                        '<strong>' + T('users.updates.current_version', 'Version actuelle :') + '</strong> ' +
                        '<span class="badge bg-secondary">v' + CURRENT_VERSION + '</span><br>' +
                        '<strong>' + T('users.updates.new_version', 'Nouvelle version :') + '</strong> ' +
                        '<span class="badge bg-success" style="font-size:14px;">v' + version + '</span>' +
                    '</p>' +
                    '<p style="margin:5px 0 0 0;font-size:12px;color:#6c757d;">' +
                        '<i class="fas fa-calendar-alt"></i> ' +
                        T('users.updates.published_on', 'Publiée le {date}', { date: releaseDate }) +
                        '<span style="margin-left:15px;"><i class="fas fa-hdd"></i> ' +
                        T('users.updates.size_label', 'Taille : {size}', { size: updateSize }) + '</span>' +
                    '</p>' +
                '</div>' +
                '<div style="margin-bottom:15px;">' +
                    '<p style="font-weight:bold;margin-bottom:8px;">' + T('users.updates.changelog_title', '📝 Journal des modifications :') + '</p>' +
                    '<ul style="padding-left:20px;margin:0;">' +
                        changelog.map(function (item) { return '<li style="margin-bottom:4px;">' + item + '</li>'; }).join("") +
                    '</ul>' +
                '</div>' +
                '<div style="background:#fff3cd;padding:10px;border-radius:6px;border-left:4px solid #ffc107;">' +
                    '<p style="margin:0;font-size:13px;">' +
                        '<i class="fas fa-info-circle" style="color:#ffc107;"></i> ' +
                        '<strong>' + T('users.updates.important', 'Important :') + '</strong> ' +
                        T('users.updates.important_text', 'Nous vous recommandons de faire une <strong>sauvegarde</strong> avant la mise à jour.') +
                    '</p>' +
                '</div>' +
            '</div>',
        icon: "info",
        showCloseButton: true,
        showConfirmButton: false,
        showCancelButton: false,
        showDenyButton: true,
        denyButtonText: T('users.updates.see_details', '📋 Voir les détails'),
        denyButtonColor: "#17a2b8"
    }).then(function (result) {
        if (result.isDenied) showFullChangelog(data);
    });
}

function showNoUpdateModal(data) {
    var lastCheck = data.lastCheck || new Date().toLocaleString("fr-FR");
    Swal.fire({
        title: T('users.updates.up_to_date_title', '✅ Application à jour'),
        html:
            '<div style="text-align:center;">' +
                '<i class="fas fa-check-circle" style="font-size:48px;color:#28a745;margin-bottom:15px;"></i>' +
                '<p style="font-size:16px;">' +
                    T('users.updates.up_to_date_text', 'Vous utilisez la version <strong>v{version}</strong>', { version: CURRENT_VERSION }) +
                '</p>' +
                '<p style="color:#6c757d;font-size:13px;">' +
                    '<i class="fas fa-clock"></i> ' +
                    T('users.updates.last_check', 'Dernière vérification : {date}', { date: lastCheck }) +
                '</p>' +
                '<p style="color:#6c757d;font-size:13px;">' +
                    T('users.updates.no_update', 'Aucune mise à jour disponible pour le moment.') +
                '</p>' +
            '</div>',
        icon: "success",
        confirmButtonText: T('users.msg.ok', 'OK'),
        confirmButtonColor: "#28a745"
    });
}

function showFullChangelog(data) {
    var version = data.latestVersion || "2.2.0";
    var changelog = data.changelog || [];
    Swal.fire({
        title: T('users.updates.full_changelog_title', '📋 Journal des modifications v{version}', { version: version }),
        html:
            '<div style="text-align:left;max-height:400px;overflow-y:auto;">' +
                (changelog.length > 0
                    ? changelog.map(function (item) {
                        return '<div style="padding:8px 12px;border-bottom:1px solid #f0f0f0;display:flex;align-items:start;gap:10px;">' +
                            '<span style="color:#28a745;">•</span><span>' + item + '</span></div>';
                      }).join("")
                    : '<p style="color:#6c757d;">' + T('users.updates.no_details', 'Aucun détail disponible') + '</p>') +
            '</div>',
        icon: "info",
        confirmButtonText: T('users.updates.close', 'Fermer'),
        confirmButtonColor: "#17a2b8",
        width: 600
    });
}

function simulateUpdateCheck() {
    var hasUpdate = Math.random() > 0.7;
    if (hasUpdate) {
        showUpdateAvailableModal({
            latestVersion: "2.2.0",
            releaseDate: new Date().toLocaleDateString("fr-FR"),
            changelog: [
                "✨ Nouvelle interface pour la gestion des utilisateurs",
                "🐛 Correction du bug de sauvegarde automatique",
                "⚡ Optimisation des requêtes SQL",
                "🔒 Renforcement de la sécurité des sessions",
                "📱 Amélioration de l'affichage mobile"
            ],
            downloadUrl: "#",
            updateSize: "15.2 Mo"
        });
    } else {
        showNoUpdateModal({ lastCheck: new Date().toLocaleString("fr-FR") });
    }
}

function autoCheckForUpdates() {
    var userRole = document.getElementById("hfUserRole")?.value;
    if (userRole !== "0") return;
    if (sessionStorage.getItem("autoUpdateChecked") === "true") return;
    setTimeout(function () {
        sessionStorage.setItem("autoUpdateChecked", "true");
        checkForUpdates();
    }, 5000);
}

window.applyDefaultPermissionsByRole   = applyDefaultPermissionsByRole;
window.setPermissionsCheckboxes        = setPermissionsCheckboxes;
window.getSelectedPermissions          = getSelectedPermissions;
window.setPermissionsCheckboxesEnabled = setPermissionsCheckboxesEnabled;
window.openAddUserModal                = openAddUserModal;
window.openEditUserModal               = openEditUserModal;
window.resetModalForm                  = resetModalForm;
window.createUserFromModal             = createUserFromModal;
window.updateUserFromModal             = updateUserFromModal;
window.saveUser                        = saveUser;
window.supprimerContact                = supprimerContact;
window.backupDatabase                  = backupDatabase;
window.openRestoreModal                = openRestoreModal;
window.selectRestoreSource             = selectRestoreSource;
window.loadBackupList                  = loadBackupList;
window.selectBackupFile                = selectBackupFile;
window.handleRestoreFileSelect         = handleRestoreFileSelect;
window.showRestoreInfo                 = showRestoreInfo;
