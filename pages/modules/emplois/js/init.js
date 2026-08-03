'use strict';
(function() {
    // Références aux boutons
    var btnAdd = document.getElementById('btnAddEmploi');
    var btnRefresh = document.getElementById('btnRefresh');
    var btnPrint = document.getElementById('btnPrint');

    window.canManageEmploi = function() {
        var role = document.getElementById('hfUserRole');
        var roleValue = role ? parseInt(role.value, 10) : -1;
        return roleValue === 0 || roleValue === 1 || roleValue === 4;
    };

    // Fonction pour mettre à jour l'état des boutons (exposée globalement)
    window.updateButtons = function() {
        var filter = document.getElementById('classeFilter');
        var hasClass = filter && filter.value && filter.value !== '';
        if (btnAdd) btnAdd.disabled = !hasClass || !window.canManageEmploi();
        if (btnRefresh) btnRefresh.disabled = !hasClass;
        if (btnPrint) btnPrint.disabled = !hasClass;
    };

    // Charger les classes (le callback dans loaders.js appellera updateButtons)
    Emploi.loaders.loadClasses();
    Emploi.loaders.loadProfesseurs();

    var displayMode = document.getElementById('displayMode');
    var professeurFilterGroup = document.getElementById('professeurFilterGroup');
    var professeurFilter = document.getElementById('professeurFilter');
    var isProfessor = parseInt(document.getElementById('hfUserRole').value, 10) === 3;

    function setDisplayModeOptions() {
        if (!displayMode) return;
        displayMode.innerHTML = '';
        if (isProfessor) {
            displayMode.innerHTML += '<option value="my_all">Voir l\'ensemble de mes emplois du temps, toutes classes confondues</option>';
            displayMode.innerHTML += '<option value="my_in_class">Voir uniquement mes emplois du temps</option>';
        }
        displayMode.innerHTML += '<option value="class_all">Voir tous les emplois du temps de la classe sélectionnée</option>';
        displayMode.innerHTML += '<option value="specific_prof">Voir l\'ensemble des emplois du temps d\'un professeur spécifique</option>';
        displayMode.value = isProfessor ? 'my_all' : 'class_all';
        updateProfessorFilterVisibility();
    }

    function updateProfessorFilterVisibility() {
        if (!displayMode || !professeurFilterGroup) return;
        professeurFilterGroup.style.display = (displayMode.value === 'specific_prof') ? 'block' : 'none';
    }

    if (displayMode) {
        setDisplayModeOptions();
        displayMode.addEventListener('change', function() {
            updateProfessorFilterVisibility();
            if (displayMode.value === 'specific_prof') {
                Emploi.loaders.loadProfesseurs();
            }
            Emploi.loaders.loadEmploi();
        });
    }

    if (professeurFilter) {
        professeurFilter.addEventListener('change', function() {
            Emploi.loaders.loadEmploi();
        });
    }

    // Exposer les fonctions globales pour les onclick
    window.loadEmploi = function() { Emploi.loaders.loadEmploi(); };
    window.openEditModal = function() { Emploi.events.openEdit(null, null); };
    window.saveCell = function() { Emploi.crud.saveCell(); };
    window.deleteCell = function() { Emploi.crud.deleteCell(); };
    window.printEmploi = function() { Emploi.events.print(); };
    window.closeEditModal = function() { Emploi.utils.closeModal('editModal'); };

    // Écouteur pour le changement de matière (remplit l'enseignant)
    var matiereSelect = document.getElementById('editMatiere');
    if (matiereSelect) {
        matiereSelect.addEventListener('change', function() {
            Emploi.events.setEnseignantFromMatiere(this.value);
        });
    }

    // Bouton Rafraîchir
    if (btnRefresh) {
        btnRefresh.addEventListener('click', function() {
            Emploi.loaders.loadEmploi();
        });
    }

    // Bouton Paramétrer
    if (btnAdd) {
        btnAdd.addEventListener('click', function() {
            if (!window.canManageEmploi()) {
                Emploi.utils.showToast('Vous n’avez pas les droits pour modifier l’emploi du temps.', 'warning');
                return;
            }
            Emploi.events.openEdit(null, null);
        });
    }

    // Filtre classe
    var filter = document.getElementById('classeFilter');
    if (filter) {
        filter.addEventListener('change', function() {
            window.updateButtons();
            if (this.value) {
                Emploi.loaders.loadEmploi();
            } else {
                var tbody = document.getElementById('emploiBody');
                if (tbody) {
                    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;padding:40px;color:#6c757d;font-size:16px;">Veuillez sélectionner une classe</td></tr>';
                }
                Emploi.state.emploiData = {};
            }
        });
        // Initialisation : l'état des boutons sera mis à jour par le callback de loadClasses
        // Mais on le fait aussi ici pour le cas où le filtre a déjà une valeur
        if (filter.value) {
            Emploi.loaders.loadEmploi();
        } else {
            var tbody = document.getElementById('emploiBody');
            if (tbody) {
                tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;padding:40px;color:#6c757d;font-size:16px;">Veuillez sélectionner une classe</td></tr>';
            }
        }
    }
})();