'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// LOADERS — Module Bulletins
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// CONTEXTE UTILISATEUR
// ─────────────────────────────────────────────────────────────────────────────

function getUserContext() {
    currentUser.role = document.getElementById('hfUserRole') ? document.getElementById('hfUserRole').value || '' : '';
    currentUser.userName = document.getElementById('hfUserName') ? document.getElementById('hfUserName').value || '' : '';
    currentUser.professeurId = document.getElementById('hfProfesseurId') ? document.getElementById('hfProfesseurId').value || '' : '';

    var classesStr = document.getElementById('hfClassesAutorisees') ? document.getElementById('hfClassesAutorisees').value || '[]' : '[]';
    var matieresStr = document.getElementById('hfMatieresAutorisees') ? document.getElementById('hfMatieresAutorisees').value || '[]' : '[]';

    try {
        currentUser.classesAutorisees = JSON.parse(classesStr);
        currentUser.matieresAutorisees = JSON.parse(matieresStr);
    } catch (e) {
        currentUser.classesAutorisees = [];
        currentUser.matieresAutorisees = [];
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHARGEMENT DES MATIÈRES
// ─────────────────────────────────────────────────────────────────────────────

async function chargerMatieres() {
    try {
        showLoading('Chargement des matières...');
        var response = await fetch(API_BULLETINS.getMatieres);

        if (!response.ok) {
            throw new Error('Erreur HTTP ' + response.status + ': ' + response.statusText);
        }

        var data = await response.json();
        var select = document.getElementById('ddlMatiere');
        if (!select) { hideLoading(); return; }

        select.innerHTML = '<option value="">-- Sélectionner une matière --</option>';
        allMatieres = data.matieres || data.data || [];

        var matieresToShow = [];
        var isSuperAdmin = currentUser.role === '0';

        if (isSuperAdmin) {
            matieresToShow = allMatieres;
        } else if (currentUser.matieresAutorisees.length > 0) {
            var ids = currentUser.matieresAutorisees.map(function(m) { return String(m.ID || m.id || m); });
            matieresToShow = allMatieres.filter(function(m) {
                return ids.indexOf(String(m.ID || m.id)) !== -1;
            });
        }

        if (matieresToShow.length === 0) {
            select.innerHTML = '<option value="">-- Aucune matière disponible --</option>';
            hideLoading();
            return;
        }

        matieresToShow.sort(function(a, b) {
            return (a.NOM || a.nom || '').localeCompare(b.NOM || b.nom || '');
        });

        for (var i = 0; i < matieresToShow.length; i++) {
            var m = matieresToShow[i];
            var opt = document.createElement('option');
            opt.value = m.ID || m.id;
            var text = m.NOM || m.nom || 'Sans nom';
            if (m.CLASSE_NOM) text += ' (' + m.CLASSE_NOM + ')';
            opt.textContent = text;
            opt.setAttribute('data-classe-id', m.CLASSE_ID || m.classe_id || m.CLASSEID || m.classeId);
            opt.setAttribute('data-classe-nom', m.CLASSE_NOM || m.classe_nom || '');
            select.appendChild(opt);
        }

        if (matieresToShow.length === 1) {
            select.value = matieresToShow[0].ID || matieresToShow[0].id;
            onMatiereChange();
        }
        hideLoading();
    } catch (e) {
        console.error('Erreur matières:', e);
        hideLoading();
        showToast('Erreur lors du chargement des matières: ' + e.message, 'error');
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// AFFICHAGE DE LA LISTE DES BULLETINS
// ─────────────────────────────────────────────────────────────────────────────

async function afficherListe() {
    if (isLoading) return;

    var matiereId = document.getElementById('ddlMatiere').value;
    var classeId = document.getElementById('ddlClasse').value;
    var periode = document.getElementById('ddlPeriode').value;

    if (!matiereId || !classeId || !periode) {
        showToast('Veuillez sélectionner une matière, une classe et une période', 'warning');
        return;
    }

    if (hasUnsavedChanges) {
        var confirmed = await showConfirmDialog(
            'Modifications non sauvegardées',
            'Vous avez des modifications non sauvegardées.\nSi vous continuez, elles seront perdues.\n\nVoulez-vous continuer ?',
            'Continuer', 'Annuler', false
        );
        if (!confirmed) return;
    }

    currentMatiereId = matiereId;
    currentClasseId = classeId;
    currentPeriode = periode;
    setUnsavedChanges(false);

    showLoading('Chargement des bulletins...');
    isLoading = true;

    try {
        var data = await fetchWithErrorHandling(API_BULLETINS.getBulletins, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ classeId: classeId, matiereId: matiereId, periodeId: periode })
        });

        if (!data.success) {
            throw new Error(data.message || 'Erreur de chargement');
        }

        currentEleves = data.eleves || [];

        if (data.coefficients) {
            currentCoefficients = {
                coeff1: parseFloat(data.coefficients.coeff1) || 1,
                coeff2: parseFloat(data.coefficients.coeff2) || 2,
                coeffProjet: parseFloat(data.coefficients.coeffProjet) || 1
            };

            var coeffIds = ['globalCoeff1', 'globalCoeff2', 'globalCoeffProjet'];
            var coeffValues = [currentCoefficients.coeff1, currentCoefficients.coeff2, currentCoefficients.coeffProjet];
            for (var i = 0; i < coeffIds.length; i++) {
                var el = document.getElementById(coeffIds[i]);
                if (el) el.value = coeffValues[i];
            }
        }

        if (currentEleves.length === 0) {
            showToast('Aucun élève trouvé', 'warning');
            resetDisplay();
            hideLoading();
            return;
        }

        var matiere = document.getElementById('ddlMatiere');
        var nomMatiere = matiere && matiere.options[matiere.selectedIndex] ? matiere.options[matiere.selectedIndex].textContent || '' : '';
        var periodeSelect = document.getElementById('ddlPeriode');
        var nomPeriode = periodeSelect && periodeSelect.options[periodeSelect.selectedIndex] ? periodeSelect.options[periodeSelect.selectedIndex].text || '' : '';

        var info = document.getElementById('tableInfoLabel');
        if (info) info.innerHTML = '<i class="fas fa-graduation-cap"></i> ' + escapeHtml(nomMatiere) + ' — ' + escapeHtml(nomPeriode);

        var badge = document.getElementById('countBadge');
        if (badge) badge.textContent = currentEleves.length + ' élève(s)';

        renderTable();
        document.getElementById('coeffGlobalPanel').style.display = 'block';
        document.getElementById('emptyState').style.display = 'none';
        document.getElementById('tableWrapper').style.display = 'block';
        showActionButtons(true);

        var msg = document.getElementById('coeffMessage');
        if (msg) {
            msg.innerHTML = 'Coefficients actuels : Note1 (×' + currentCoefficients.coeff1 + ') | Note2 (×' + currentCoefficients.coeff2 + ') | Examen (×' + currentCoefficients.coeffProjet + ')';
        }

        updateButtonsState();
        hideLoading();

    } catch (e) {
        console.error('Erreur:', e);
        hideLoading();
        showToast('Erreur: ' + e.message, 'error');
        resetDisplay();
    } finally {
        isLoading = false;
    }
}

function resetDisplay() {
    currentEleves = [];
    var coeffPanel = document.getElementById('coeffGlobalPanel');
    if (coeffPanel) coeffPanel.style.display = 'none';
    var tableWrapper = document.getElementById('tableWrapper');
    if (tableWrapper) tableWrapper.style.display = 'none';
    var emptyState = document.getElementById('emptyState');
    if (emptyState) emptyState.style.display = 'block';
    var badge = document.getElementById('countBadge');
    if (badge) badge.textContent = '0 élève(s)';
    showActionButtons(false);
    resetButtons();
}

// Exposer les fonctions globalement
window.getUserContext = getUserContext;
window.chargerMatieres = chargerMatieres;
window.afficherListe = afficherListe;
window.resetDisplay = resetDisplay;