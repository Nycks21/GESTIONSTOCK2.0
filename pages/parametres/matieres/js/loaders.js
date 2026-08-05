'use strict';

async function loadMatieres() {
    showSpinner();
    try {
        // Charger les matières
        var dataMatieres = await fetchJson(API_MATIERES.getMatieres);
        if (!dataMatieres.success) {
            throw new Error(dataMatieres.message || 'Erreur lors du chargement des matières.');
        }
        STATE.matieresData = dataMatieres.matieres || dataMatieres.data || [];
        STATE.filteredMatieres = [...STATE.matieresData];
        STATE.currentPage = 1;
        renderStats();
        renderTable();

        // Charger les listes déroulantes
        await Promise.all([
            loadClasses(),
            loadUsers()
        ]);
    } catch (err) {
        console.error('loadMatieres:', err);
        showErrorToast('Erreur de chargement', err.message);
    } finally {
        hideSpinner();
    }
}

async function loadClasses() {
    var data = await fetchJson(API_MATIERES.getClasses);
    if (data.success) {
        var select = document.getElementById('matiereClasse');
        if (!select) return;
        select.innerHTML = '<option value="">-- Sélectionner une classe --</option>';
        var classesList = data.Classes || data.data || [];
        classesList.forEach(function(cls) {
            var opt = document.createElement('option');
            opt.value = cls.ID || cls.id;
            opt.textContent = cls.NOM || cls.nom;
            select.appendChild(opt);
        });
    } else {
        console.warn('Erreur chargement classes:', data.message);
    }
}

async function loadUsers() {
    var data = await fetchJson(API_MATIERES.getUsers);
    if (data.success) {
        var select = document.getElementById('matiereEnseignant');
        if (!select) return;
        select.innerHTML = '<option value="">-- Sélectionner un enseignant --</option>';
        var usersList = data.users || data.Users || [];
        usersList.forEach(function(u) {
            var opt = document.createElement('option');
            opt.value = u.ID || u.id || u.IDUSER;
            opt.textContent = u.NOM || u.nom;
            select.appendChild(opt);
        });
    } else {
        console.warn('Erreur chargement utilisateurs:', data.message);
    }
}

// Expositions
window.loadMatieres = loadMatieres;
window.loadClasses = loadClasses;
window.loadUsers = loadUsers;