'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// LOADERS — Module Utilisateurs
// ─────────────────────────────────────────────────────────────────────────────

async function checkLicenceLimit() {
    try {
        var response = await fetch(apiUrl(API_USERS.checkLicence));
        var data = await response.json();

        if (data.success) {
            maxUsersAllowed = data.maxUsers || 0;
            var currentUsers = data.currentUsers || 0;
            isLicenceLimitReached = currentUsers >= maxUsersAllowed;

            var maxUsersSpan = document.getElementById('maxUsersCount');
            if (maxUsersSpan) {
                maxUsersSpan.textContent = currentUsers + ' / ' + maxUsersAllowed;
                maxUsersSpan.style.color = isLicenceLimitReached ? '#ff6b6b' : '#adb5bd';
                maxUsersSpan.style.fontWeight = isLicenceLimitReached ? 'bold' : 'normal';
            }

            var userCountInfo = document.getElementById('userCountInfo');
            if (userCountInfo) {
                userCountInfo.textContent = currentUsers + ' / ' + maxUsersAllowed;
            }

            return { reached: isLicenceLimitReached, current: currentUsers, max: maxUsersAllowed };
        }
    } catch (err) {
        console.error('Erreur vérification licence:', err);
        return { reached: false, current: 0, max: 0 };
    }
    return { reached: false, current: 0, max: 0 };
}

async function canActivateUser() {
    var licenceInfo = await checkLicenceLimit();
    if (licenceInfo.reached) {
        showLicenceLimitAlert(licenceInfo.current, licenceInfo.max);
        return false;
    }
    return true;
}

function loadUsers() {
    showSpinner();
    showPreloader();
    fetch(apiUrl(API_USERS.list))
        .then(safeJson)
        .then(function(data) {
            if (!Array.isArray(data)) {
                console.error("Réponse invalide:", data);
                return;
            }
            usersData = data;
            filteredUsers = usersData.slice();
            createFilterControls();
            renderSimpleTable();
            hidePreloader();
            checkLicenceLimit();
        })
        .catch(function(err) {
            console.error(err);
            Swal.fire({ icon: 'error', title: 'Erreur', text: 'Impossible de charger les utilisateurs' });
            hidePreloader();
        })
        .finally(function() {
            hideSpinner();
        });
}

function renderSimpleTable() {
    var tbody = document.getElementById('usersTableBody');
    if (!tbody) return;

    var startIndex = (currentPage - 1) * rowsPerPage;
    var endIndex = startIndex + rowsPerPage;
    var pageUsers = filteredUsers.slice(startIndex, endIndex);
    var totalPages = Math.ceil(filteredUsers.length / rowsPerPage);

    tbody.innerHTML = '';
    if (!pageUsers.length) {
        tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:60px;"><i class="fas fa-search" style="font-size:48px;color:#ccc;"></i><br>Aucun utilisateur trouvé</td></tr>';
        updateCounter();
        createPaginationControls(totalPages);
        return;
    }

    pageUsers.forEach(function(user) {
        var row = tbody.insertRow();
        var nameBadge = user.USERNAME ? '<span class="badge-name">' + escapeHtml(user.USERNAME) + '</span>' : '';
        row.insertCell(0).innerHTML = nameBadge;
        row.insertCell(1).innerHTML = escapeHtml(user.NOM || '-');
        row.insertCell(2).innerHTML = escapeHtml(user.EMAIL || '-');
        row.insertCell(3).innerHTML = getUserRoleName(user.ROLEID);
        row.insertCell(4).innerHTML = escapeHtml(user.TELEPHONE || '-');
        row.insertCell(5).innerHTML = formatDate(user.CREATED_AT);
        row.insertCell(6).innerHTML = (user.ACTIVE === true || user.ACTIVE === 1 || user.ACTIVE === 'true')
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">✓ Actif</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">✗ Inactif</span>';

        // --- Modification ici ---
        var isAdmin = (user.ROLEID === 0); // true si ROLEID = 0

        // Bouton Modifier : désactivé et grisé si admin
        var editBtn = `<button type="button" class="btn btn-sm ${isAdmin ? 'btn-secondary' : 'btn-primary'}"
                                ${isAdmin ? 'disabled' : ''}
                                onclick="openEditUserModal(${user.IDUSER}, event)">
                            <i class="fas fa-edit"></i>
                        </button>`;

        // Bouton Supprimer : désactivé et grisé si admin
        var deleteBtn = `<button type="button" class="btn btn-sm ${isAdmin ? 'btn-secondary' : 'btn-danger'}"
                                  ${isAdmin ? 'disabled' : ''}
                                  onclick="supprimerContact(${user.IDUSER}, event)">
                              <i class="fas fa-trash"></i>
                          </button>`;

        row.insertCell(7).innerHTML = editBtn + ' ' + deleteBtn;
        // --- Fin modification ---
    });
    updateCounter();
    createPaginationControls(totalPages);
}

function sortData(column) {
    sortDirection *= -1;
    filteredUsers.sort(function(a, b) {
        var va = (a[column] || '').toString().toLowerCase();
        var vb = (b[column] || '').toString().toLowerCase();
        return va < vb ? -sortDirection : va > vb ? sortDirection : 0;
    });
    currentPage = 1;
    renderSimpleTable();
}

// Exposer globalement
window.checkLicenceLimit = checkLicenceLimit;
window.canActivateUser = canActivateUser;
window.loadUsers = loadUsers;
window.renderSimpleTable = renderSimpleTable;
window.sortData = sortData;
