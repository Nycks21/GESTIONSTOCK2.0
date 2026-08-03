'use strict';
var Emploi = Emploi || {};
Emploi.crud = {
    saveCell: function() {
        if (!window.canManageEmploi()) {
            Emploi.utils.showToast('Vous n’avez pas les droits pour modifier l’emploi du temps.', 'warning');
            return;
        }

        var classe = document.getElementById('editClasse').value;
        var jour = document.getElementById('editJour').value;
        var heureDebutRaw = document.getElementById('editHeureDebut').value;
        var heureFinRaw = document.getElementById('editHeureFin').value || heureDebutRaw;
        var matiere = document.getElementById('editMatiere').value;
        var prof = document.getElementById('editEnseignant').value.trim();
        var salle = document.getElementById('editSalle').value.trim();
        var couleur = document.getElementById('editCouleur').value;
        var type = document.getElementById('editType').value;
        var url = document.getElementById('editUrl').value.trim();
        var description = document.getElementById('editDescription').value.trim();

        var heureDebut = Emploi.utils.normalizeTime(heureDebutRaw);
        var heureFin = Emploi.utils.normalizeTime(heureFinRaw);

        if (!classe || !jour || !heureDebut || !matiere) {
            Emploi.utils.showToast('Tous les champs obligatoires doivent être remplis.', 'warning');
            return;
        }

        if (heureFin <= heureDebut) {
            Emploi.utils.showToast('L\'heure de fin doit être postérieure à l\'heure de début.', 'warning');
            return;
        }

        var payload = {
            classe: classe,
            jour: jour,
            heureDebut: heureDebut,
            heureFin: heureFin,
            matiere: matiere,
            prof: prof,
            salle: salle,
            couleur: couleur,
            type: type,
            url: url,
            description: description
        };

        Emploi.utils.showSpinner();
        fetch(API_EMPLOI.saveEmploi, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
            credentials: 'include'
        })
        .then(function(res) { return res.json(); })
        .then(function(data) {
            if (data.success) {
                Emploi.utils.closeModal('editModal');
                Emploi.utils.showToast('Créneau enregistré.', 'success');
                Emploi.loaders.loadEmploi();
            } else {
                Emploi.utils.showToast(data.message || 'Échec de l\'enregistrement.', 'danger');
            }
        })
        .catch(function(err) {
            console.error('saveCell', err);
            Emploi.utils.showToast('Impossible de sauvegarder.', 'danger');
        })
        .finally(function() {
            Emploi.utils.hideSpinner();
        });
    },

    deleteCell: function() {
        if (!window.canManageEmploi()) {
            Emploi.utils.showToast('Vous n’avez pas les droits pour supprimer un créneau.', 'warning');
            return;
        }

        if (!Emploi.state.editKey) {
            Emploi.utils.showToast('Aucune cellule sélectionnée.', 'info');
            return;
        }

        Swal.fire({
            title: 'Supprimer ?',
            text: 'Voulez-vous supprimer ce créneau ?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Oui, supprimer',
            cancelButtonText: 'Annuler'
        }).then(function(result) {
            if (!result.isConfirmed) return;

            var parts = Emploi.state.editKey.split('_');
            var classeForDelete = document.getElementById('editClasse').value
                || Emploi.state.currentClasse
                || document.getElementById('classeFilter').value;
            var payload = {
                classe: classeForDelete,
                jour: parts[0],
                heureDebut: parts[1]
            };

            Emploi.utils.showSpinner();
            fetch(API_EMPLOI.deleteEmploi, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
                credentials: 'include'
            })
            .then(function(res) { return res.json(); })
            .then(function(data) {
                if (data.success) {
                    Emploi.utils.closeModal('editModal');
                    Emploi.utils.showToast('Créneau supprimé.', 'success');
                    Emploi.loaders.loadEmploi();
                } else {
                    Emploi.utils.showToast(data.message || 'Échec de la suppression.', 'danger');
                }
            })
            .catch(function(err) {
                console.error('deleteCell', err);
                Emploi.utils.showToast('Impossible de supprimer.', 'danger');
            })
            .finally(function() {
                Emploi.utils.hideSpinner();
            });
        });
    },

    moveCourse: function(classe, sourceDay, sourceHour, targetDay, targetHour, swap) {
        if (!window.canManageEmploi()) {
            Emploi.utils.showToast('Vous n’avez pas les droits pour déplacer un créneau.', 'warning');
            return;
        }

        Emploi.utils.showSpinner();
        var url = API_EMPLOI.moveEmploi
            + '?classe=' + encodeURIComponent(classe)
            + '&sourceDay=' + encodeURIComponent(sourceDay)
            + '&sourceHour=' + encodeURIComponent(sourceHour)
            + '&targetDay=' + encodeURIComponent(targetDay)
            + '&targetHour=' + encodeURIComponent(targetHour)
            + '&swap=' + (swap ? 'true' : 'false');

        fetch(url, { credentials: 'include' })
            .then(function(res) { return res.json(); })
            .then(function(data) {
                if (data.success) {
                    Emploi.utils.showToast(swap ? 'Cours échangés.' : 'Cours déplacé.', 'success');
                    Emploi.loaders.loadEmploi();
                } else {
                    Emploi.utils.showToast(data.message || 'Erreur lors du déplacement.', 'danger');
                }
            })
            .catch(function(err) {
                console.error('moveCourse', err);
                Emploi.utils.showToast('Erreur réseau.', 'danger');
            })
            .finally(function() {
                Emploi.utils.hideSpinner();
            });
    }
};