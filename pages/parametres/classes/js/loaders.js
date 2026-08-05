'use strict';

// Chargement des données

async function loadClasses() {
    showSpinner();
    try {
        // Charger les classes
        var dataClasses = await fetchJson(API_CLASSES.getClasses);
        if (!dataClasses.success) {
            throw new Error(dataClasses.message || 'Erreur lors du chargement des classes.');
        }
        STATE.classesData = dataClasses.Classes || [];
        STATE.filteredClasses = [...STATE.classesData];
        STATE.currentPage = 1;
        renderStats();
        renderTable();
        renderPagination();

        // Charger les listes déroulantes
        await Promise.all([
            loadNiveaux(),
            loadSalles(),
            loadUsers()
        ]);
    } catch (err) {
        console.error('loadClasses:', err);
        showErrorToast('Erreur de chargement', err.message);
    } finally {
        hideSpinner();
    }
}

async function loadNiveaux() {
    var data = await fetchJson(API_CLASSES.getNiveaux);
    if (data.success) {
        var select = document.getElementById('ClasseNiveau');
        if (!select) return;
        select.innerHTML = '<option value="">-- Sélectionner un niveau --</option>';
        (data.niveaux || []).forEach(function(niv) {
            var opt = document.createElement('option');
            opt.value = niv.ID;
            opt.textContent = niv.NOM;
            select.appendChild(opt);
        });
    } else {
        console.warn('Erreur chargement niveaux:', data.message);
    }
}

async function loadSalles() {
    var data = await fetchJson(API_CLASSES.getSalles);
    if (data.success) {
        var select = document.getElementById('ClasseSalle');
        if (!select) return;
        select.innerHTML = '<option value="">-- Sélectionner une salle --</option>';
        (data.salles || data.Salles || []).forEach(function(s) {
            var opt = document.createElement('option');
            opt.value = s.ID;
            opt.textContent = s.NUMERO;
            select.appendChild(opt);
        });
    } else {
        console.warn('Erreur chargement salles:', data.message);
    }
}

async function loadUsers() {
    var data = await fetchJson(API_CLASSES.getUsers);
    if (data.success) {
        var select = document.getElementById('ClasseUser');
        if (!select) return;
        select.innerHTML = '<option value="">-- Sélectionner un utilisateur --</option>';
        (data.users || data.Users || []).forEach(function(u) {
            var opt = document.createElement('option');
            opt.value = u.IDUSER || u.ID;
            opt.textContent = u.NOM;
            select.appendChild(opt);
        });
    } else {
        console.warn('Erreur chargement utilisateurs:', data.message);
    }
}

// Expositions
window.loadClasses = loadClasses;
window.loadNiveaux = loadNiveaux;
window.loadSalles = loadSalles;
window.loadUsers = loadUsers;