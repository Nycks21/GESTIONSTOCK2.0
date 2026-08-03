'use strict';
var Emploi = Emploi || {};
Emploi.events = {
    // --- OUVERTURE DU MODAL ---
    openEdit: function(event, td) {
        if (!window.canManageEmploi()) {
            Emploi.utils.showToast('Vous n’avez pas les droits pour modifier l’emploi du temps.', 'warning');
            return;
        }

        var classeId = document.getElementById('editClasse').value || Emploi.state.currentClasse;
        var elClasse = document.getElementById('editClasse');
        var elJour = document.getElementById('editJour');

        if (!td) {
            // Mode ajout
            if (elClasse) elClasse.disabled = false;
            if (elJour) elJour.disabled = false;
            elClasse.value = classeId || '';
            elJour.value = '1';
            document.getElementById('editHeureDebut').value = '08:00';
            document.getElementById('editHeureFin').value = '09:00';
            document.getElementById('editMatiere').value = '';
            document.getElementById('editEnseignant').value = '';
            document.getElementById('editEnseignant').disabled = true;
            document.getElementById('editSalle').value = '';
            document.getElementById('editCouleur').value = '#007bff';
            document.getElementById('editType').value = 'cours';
            document.getElementById('editUrl').value = '';
            document.getElementById('editDescription').value = '';
            Emploi.state.editKey = null;
            document.getElementById('btnDeleteEmploi').style.display = 'none';
            document.getElementById('editModalTitle').textContent = 'Ajouter un cours';

            if (classeId) {
                Emploi.loaders.loadMatieresForClasse(classeId);
            }
            Emploi.utils.openModal('editModal');
            return;
        }

        // Mode édition
        if (elClasse) elClasse.disabled = true;
        if (elJour) elJour.disabled = true;

        var day = td.dataset.day;
        var time = td.dataset.time;
        var key = day + '_' + time;
        var cell = Emploi.state.emploiData[key] || {};

        elClasse.value = classeId;
        elJour.value = day;
        document.getElementById('editHeureDebut').value = time;
        document.getElementById('editHeureFin').value = cell.heureFin || time;
        document.getElementById('editMatiere').value = cell.matiere || '';
        document.getElementById('editEnseignant').value = cell.prof || '';
        document.getElementById('editEnseignant').disabled = true;
        document.getElementById('editSalle').value = cell.salle || '';
        document.getElementById('editCouleur').value = cell.couleur || '#007bff';
        document.getElementById('editType').value = cell.type || 'cours';
        document.getElementById('editUrl').value = cell.url || '';
        document.getElementById('editDescription').value = cell.description || '';
        Emploi.state.editKey = key;
        document.getElementById('btnDeleteEmploi').style.display = 'block';
        document.getElementById('editModalTitle').textContent = 'Modifier le cours';

        // Charger les matières et restaurer la sélection
        if (classeId) {
            Emploi.loaders.loadMatieresForClasse(classeId).then(function() {
                var sel = document.getElementById('editMatiere');
                if (sel && cell.matiere) {
                    var found = false;
                    for (var i = 0; i < sel.options.length; i++) {
                        if (sel.options[i].value == cell.matiere) {
                            found = true;
                            break;
                        }
                    }
                    if (found) {
                        sel.value = cell.matiere;
                        Emploi.events.setEnseignantFromMatiere(cell.matiere);
                    } else {
                        sel.value = '';
                        document.getElementById('editEnseignant').value = '';
                    }
                }
            });
        }

        Emploi.utils.openModal('editModal');
    },

    // --- Mise à jour de l'enseignant depuis la matière sélectionnée ---
    setEnseignantFromMatiere: function(matiereId) {
        var enseignantInput = document.getElementById('editEnseignant');
        if (!enseignantInput) return;
        var matieresDict = Emploi.state.matieresDict || {};
        var matiere = matieresDict[matiereId];
        if (matiere && matiere.ENSEIGNANT_NOM) {
            enseignantInput.value = matiere.ENSEIGNANT_NOM;
            enseignantInput.disabled = true;
        } else {
            enseignantInput.value = '';
            enseignantInput.disabled = true;
        }
    },

    // --- DRAG & DROP ---
    onDragStart: function(e) {
        var td = e.target.closest('td[data-day]');
        if (!td) return;
        var day = td.dataset.day;
        var hour = td.dataset.time;
        var classe = Emploi.state.currentClasse;
        if (!classe) {
            e.preventDefault();
            Emploi.utils.showToast('Veuillez sélectionner une classe.', 'warning');
            return;
        }
        var cell = Emploi.state.emploiData[day + '_' + hour];
        if (!cell || !cell.matiere) {
            e.preventDefault();
            return;
        }
        Emploi.state.dragSource = { day: day, hour: hour, classe: classe };
        e.dataTransfer.setData('text/plain', day + '|' + hour + '|' + classe);
        td.style.opacity = '0.5';
        Emploi.state.isDragging = true;
    },

    onDragOver: function(e) {
        e.preventDefault();
        var td = e.target.closest('td[data-day]');
        if (td) td.style.backgroundColor = '#cfe2ff';
    },

    onDrop: function(e) {
        e.preventDefault();
        var td = e.target.closest('td[data-day]');
        if (!td) return;
        var targetDay = td.dataset.day;
        var targetHour = td.dataset.time;
        var source = Emploi.state.dragSource;
        if (!source) return;

        var sourceDay = source.day;
        var sourceHour = source.hour;
        var classe = source.classe;

        if (sourceDay === targetDay && sourceHour === targetHour) {
            Emploi.events.resetDragStyles();
            return;
        }

        var targetCell = Emploi.state.emploiData[targetDay + '_' + targetHour];
        if (targetCell && targetCell.matiere) {
            Swal.fire({
                title: 'Case occupée',
                text: 'Voulez-vous échanger les deux cours ou déplacer celui-ci (écraser) ?',
                icon: 'question',
                showCancelButton: true,
                confirmButtonText: 'Échanger',
                cancelButtonText: 'Déplacer (écraser)'
            }).then(function(result) {
                if (result.isConfirmed) {
                    Emploi.crud.moveCourse(classe, sourceDay, sourceHour, targetDay, targetHour, true);
                } else if (result.dismiss === Swal.DismissReason.cancel) {
                    Emploi.crud.moveCourse(classe, sourceDay, sourceHour, targetDay, targetHour, false);
                }
                Emploi.events.resetDragStyles();
            });
        } else {
            Emploi.crud.moveCourse(classe, sourceDay, sourceHour, targetDay, targetHour, false);
            Emploi.events.resetDragStyles();
        }
    },

    onDragEnd: function(e) {
        Emploi.events.resetDragStyles();
    },

    resetDragStyles: function() {
        document.querySelectorAll('#emploiBody td[data-day]').forEach(function(td) {
            td.style.opacity = '1';
            td.style.backgroundColor = '';
        });
        Emploi.state.dragSource = null;
        Emploi.state.isDragging = false;
    },

    print: function() {
        window.print();
    }
};

// Écouteur global pour le changement de matière (remplit l'enseignant)
document.addEventListener('DOMContentLoaded', function() {
    var matiereSelect = document.getElementById('editMatiere');
    if (matiereSelect) {
        matiereSelect.addEventListener('change', function() {
            Emploi.events.setEnseignantFromMatiere(this.value);
        });
    }
});