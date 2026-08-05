/**
 * salles.js — Gestion Scolaire
 * Table SQL Server : [MONAPPECOLE2].[dbo].[SALLES]
 * Colonnes : ID, NUMERO, CAPACITE, STATUT, CREATED_AT
 *
 * Architecture identique à matieres.js / niveaux.js :
 *   - Appels AJAX (fetch) vers des handlers .ashx
 *   - Source de vérité : SQL Server
 */

'use strict';

// ─────────────────────────────────────────────
// URLS DES HANDLERS
// ─────────────────────────────────────────────
var API = {
    liste: 'handlers/GetSalles.ashx',
    ajouter: 'handlers/AjouterSalle.ashx',
    modifier: 'handlers/ModifierSalle.ashx',
    supprimer: 'handlers/SupprimerSalle.ashx'
};

// ─────────────────────────────────────────────
// ÉTAT LOCAL
// ─────────────────────────────────────────────
var sallesData = [];
var editId = null;

// ─────────────────────────────────────────────
// INIT
// ─────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function () {
    forceHideSpinner();
    initUIControls();
    chargerSalles();
});

// ─────────────────────────────────────────────
// SPINNER
// ─────────────────────────────────────────────
function forceHideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none';
    s.style.visibility = 'hidden';
    s.style.opacity = '0';
    s.setAttribute('aria-hidden', 'true');
}
function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.opacity = '1';
    s.style.visibility = 'visible';
    s.style.display = 'flex';
    s.removeAttribute('aria-hidden');
}
function hideSpinner() { forceHideSpinner(); }

// ─────────────────────────────────────────────
// AJAX — helper générique
// ─────────────────────────────────────────────
function ajax(url, payload) {
    return fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify(payload)
    }).then(function (r) {
        if (!r.ok) throw new Error('Erreur HTTP ' + r.status);
        return r.json();
    });
}

// ─────────────────────────────────────────────
// CHARGER LA LISTE
// ─────────────────────────────────────────────
function chargerSalles() {
    showSpinner();
    fetch(API.liste)
        .then(function (r) {
            if (!r.ok) throw new Error('Erreur HTTP ' + r.status);
            return r.json();
        })
        .then(function (data) {
            if (!data.success) throw new Error(data.message || 'Erreur serveur');
            sallesData = data.salles || [];
            renderSallesStats();
            renderSallesTable();
        })
        .catch(function (err) {
            afficherErreurGlobale('Impossible de charger les salles : ' + err.message);
        })
        .finally(function () { hideSpinner(); });
}

// ─────────────────────────────────────────────
// STATISTIQUES
// ─────────────────────────────────────────────
function renderSallesStats() {
    var container = document.getElementById('sallesStatsContainer');
    if (!container) return;

    var total = sallesData.length;
    var disponibles = sallesData.filter(function (s) { return s.STATUT === true || s.STATUT === 1; }).length;
    var totalCapa = sallesData.reduce(function (sum, s) { return sum + (parseInt(s.CAPACITE, 10) || 0); }, 0);

    var stats = [
        { label: 'Total salles', value: total, icon: 'fas fa-door-open', color: '#007bff' },
        { label: 'Disponibles', value: disponibles, icon: 'fas fa-check-circle', color: '#28a745' },
        { label: 'Capacité totale', value: totalCapa + ' élèves', icon: 'fas fa-users', color: '#ffc107' }
    ];

    container.innerHTML = stats.map(function (s) {
        return '<div class="absence-stat-card" style="border-left:4px solid ' + s.color + ';">' +
            '  <div class="stat-icon" style="color:' + s.color + ';"><i class="' + s.icon + '"></i></div>' +
            '  <div class="stat-info">' +
            '    <span class="stat-value">' + s.value + '</span>' +
            '    <span class="stat-label">' + escHtml(s.label) + '</span>' +
            '  </div>' +
            '</div>';
    }).join('');
}

// ─────────────────────────────────────────────
// TABLEAU
// ─────────────────────────────────────────────
function renderSallesTable() {
    var tbody = document.getElementById('sallesTableBody');
    if (!tbody) return;

    if (sallesData.length === 0) {
        tbody.innerHTML =
            '<tr><td colspan="6" style="text-align:center;color:#888;padding:24px;">' +
            '<i class="fas fa-inbox" style="font-size:24px;display:block;margin-bottom:8px;"></i>' +
            'Aucune salle enregistrée.</td></tr>';
        return;
    }

    tbody.innerHTML = sallesData.map(function (s, idx) {
        var date = s.CREATED_AT ? new Date(s.CREATED_AT).toLocaleDateString('fr-FR') : '—';
        var dispo = s.STATUT === true || s.STATUT === 1 || s.STATUT === 'True';
        
        // Badge de disponibilité avec largeur fixe pour l'alignement
        var badge = dispo
            ? '<span style="background:#d4edda;color:#155724;padding:3px 12px;border-radius:15px;font-size:11px;font-weight:600;border:1px solid #c3e6cb;display:inline-block;min-width:90px;">Disponible</span>'
            : '<span style="background:#f8d7da;color:#721c24;padding:3px 12px;border-radius:15px;font-size:11px;font-weight:600;border:1px solid #f5c6cb;display:inline-block;min-width:90px;">Indisponible</span>';

        // Style commun pour le centrage
        var centerStyle = 'style="text-align:center;vertical-align:middle;"';
        var lightTextStyle = 'style="text-align:center;vertical-align:middle;color:#888;font-size:12px;"';

        return '<tr>' +
            // Index
            '<td ' + lightTextStyle + '>' + (idx + 1) + '</td>' +
            
            // Numéro de salle (Badge bleu)
            '<td ' + centerStyle + '>' +
            '  <span style="background:#e8f4fd;color:#0c5460;padding:3px 12px;border-radius:15px;font-size:12px;font-weight:600;border:1px solid #bee5eb;display:inline-block;min-width:80px;">' +
            '    <i class="fas fa-door-open" style="margin-right:5px;"></i>' + escHtml(s.NUMERO) +
            '  </span>' +
            '</td>' +
            
            // Capacité
            '<td ' + centerStyle + '><span class="badge-coeff" style="font-weight:700;">' + escHtml(String(s.CAPACITE)) + '</span></td>' +
            
            // Statut
            '<td ' + centerStyle + '>' + badge + '</td>' +
            
            // Date de création
            '<td ' + lightTextStyle + '>' + date + '</td>' +
            
            // Actions
            '<td ' + centerStyle + ' style="white-space:nowrap; vertical-align:middle; text-align:center;">' +
            '  <button type="button" class="btn btn-sm btn-primary" style="margin:0 2px;" ' +
            '    onclick="editSalle(\'' + s.ID + '\')" title="Modifier">' +
            '    <i class="fas fa-edit"></i>' +
            '  </button>' +
            '  <button type="button" class="btn btn-sm btn-danger" style="margin:0 2px;" ' +
            '    onclick="deleteSalle(\'' + s.ID + '\',\'' + escHtml(s.NUMERO).replace(/'/g, "\\'") + '\')" title="Supprimer">' +
            '    <i class="fas fa-trash"></i>' +
            '  </button>' +
            '</td>' +
            '</tr>';
    }).join('');
}
// ─────────────────────────────────────────────
// MODAL — OUVRIR / FERMER
// ─────────────────────────────────────────────
function openAddSalleModal() {
    editId = null;
    resetSalleForm();
    document.getElementById('salleModalTitle').innerHTML =
        '<i class="fas fa-door-open"></i> Ajouter une salle';
    document.getElementById('addSalleModal').classList.add('open');
    document.getElementById('salleNumero').focus();
}

function closeAddSalleModal() {
    document.getElementById('addSalleModal').classList.remove('open');
    resetSalleForm();
    clearFormErrors();
}

function resetSalleForm() {
    document.getElementById('salleEditId').value = '';
    document.getElementById('salleNumero').value = '';
    document.getElementById('salleCapacite').value = '30';
    document.getElementById('salleStatut').value = '1';
    clearFormErrors();
}

// ─────────────────────────────────────────────
// ÉDITER
// ─────────────────────────────────────────────
function editSalle(id) {
    // 1. Recherche de la salle avec une comparaison insensible à la casse (pour GUID)
    var s = sallesData.find(function (item) {
        return String(item.ID).toLowerCase() === String(id).toLowerCase();
    });

    if (!s) {
        console.error("Salle introuvable :", id);
        return;
    }

    // 2. Mise à jour de l'identifiant global pour le mode édition
    editId = s.ID;

    // 3. Remplissage des champs du formulaire
    var inputId = document.getElementById('salleEditId');
    if (inputId) {
        inputId.value = s.ID;
        // On verrouille l'ID en mode édition pour ne pas modifier la clé primaire
        inputId.readOnly = true;
    }

    document.getElementById('salleNumero').value = s.NUMERO;
    document.getElementById('salleCapacite').value = s.CAPACITE;

    // Normalisation du statut en '1' ou '0'
    var statusVal = (s.STATUT === true || s.STATUT === 1 || s.STATUT === "1") ? '1' : '0';
    document.getElementById('salleStatut').value = statusVal;

    // 4. Mise à jour de l'interface du Modal
    document.getElementById('salleModalTitle').innerHTML =
        '<i class="fas fa-edit"></i> Modifier la salle';

    // 5. Affichage du Modal
    var modal = document.getElementById('addSalleModal');
    if (modal) {
        modal.classList.add('open');
        document.getElementById('salleNumero').focus();
    }
}

// ─────────────────────────────────────────────
// SAUVEGARDER (Ajouter ou Modifier)
// ─────────────────────────────────────────────
function saveSalle() {
    if (!validateSalleForm()) return;

    var payload = {
        numero: document.getElementById('salleNumero').value.trim(),
        capacite: parseInt(document.getElementById('salleCapacite').value, 10) || 30,
        statut: document.getElementById('salleStatut').value === '1'
    };

    var isEdit = editId !== null;
    var url = isEdit ? API.modifier : API.ajouter;
    if (isEdit) payload.id = editId;

    showSpinner();
    ajax(url, payload)
        .then(function (data) {
            if (!data.success) throw new Error(data.message || 'Erreur serveur');
            closeAddSalleModal();
            Swal.fire({
                title: isEdit ? 'Salle modifiée !' : 'Salle ajoutée !',
                text: isEdit
                    ? 'La salle a été modifiée avec succès.'
                    : 'La salle a été ajoutée avec succès.',
                icon: 'success',
                timer: 2000,
                showConfirmButton: false
            });
            chargerSalles();
        })
        .catch(function (err) {
            Swal.fire({ title: 'Erreur', text: err.message, icon: 'error' });
            hideSpinner();
        });
}

// ─────────────────────────────────────────────
// SUPPRIMER
// ─────────────────────────────────────────────
function deleteSalle(id, numero) {
    Swal.fire({
        title: 'Supprimer cette salle ?',
        html: 'La salle <strong>' + escHtml(numero) + '</strong> sera supprimée définitivement.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#dc3545',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    }).then(function (result) {
        if (!result.isConfirmed) return;
        showSpinner();
        ajax(API.supprimer, { id: id })
            .then(function (data) {
                if (!data.success) throw new Error(data.message || 'Erreur serveur');
                Swal.fire({
                    title: 'Supprimée !',
                    text: 'La salle a été supprimée avec succès.',
                    icon: 'success',
                    timer: 2000,
                    showConfirmButton: false
                });
                chargerSalles();
            })
            .catch(function (err) {
                Swal.fire({ title: 'Erreur', text: 'Erreur lors de la suppression : ' + err.message, icon: 'error' });
                hideSpinner();
            });
    });
}

// ─────────────────────────────────────────────
// EXPORT CSV
// ─────────────────────────────────────────────
function exportSalles() {
    if (sallesData.length === 0) { alert('Aucune donnée à exporter.'); return; }
    showSpinner();
    setTimeout(function () {
        try {
            var header = ['ID', 'Numéro de salle', 'Capacité', 'Statut', 'Créé le'];
            var rows = sallesData.map(function (s) {
                var date = s.CREATED_AT ? new Date(s.CREATED_AT).toLocaleDateString('fr-FR') : '';
                var statut = (s.STATUT === true || s.STATUT === 1) ? 'Disponible' : 'Indisponible';
                return [s.ID, s.NUMERO, s.CAPACITE, statut, date]
                    .map(function (v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; })
                    .join(',');
            });
            var csv = [header.join(',')].concat(rows).join('\r\n');
            var blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url; a.download = 'salles_export_' + dateDuJour() + '.csv';
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            URL.revokeObjectURL(url);
        } catch (err) { alert('Erreur export : ' + err.message); }
        finally { hideSpinner(); }
    }, 400);
}

// ─────────────────────────────────────────────
// VALIDATION
// ─────────────────────────────────────────────
function validateSalleForm() {
    clearFormErrors();
    var ok = true;
    var numero = document.getElementById('salleNumero').value.trim();
    if (!numero) {
        showFieldError('salleNumero', 'Le numéro de salle est obligatoire.');
        ok = false;
    } else if (numero.length > 50) {
        showFieldError('salleNumero', 'Maximum 50 caractères.');
        ok = false;
    }
    var capa = parseInt(document.getElementById('salleCapacite').value, 10);
    if (isNaN(capa) || capa < 1 || capa > 200) {
        showFieldError('salleCapacite', 'La capacité doit être comprise entre 1 et 200.');
        ok = false;
    }
    return ok;
}

function showFieldError(fieldId, msg) {
    var field = document.getElementById(fieldId);
    if (!field) return;
    field.classList.add('is-invalid');
    var err = document.createElement('div');
    err.className = 'field-error';
    err.textContent = msg;
    field.parentNode.appendChild(err);
}

function clearFormErrors() {
    var invalids = document.querySelectorAll('#addSalleModal .is-invalid');
    for (var i = 0; i < invalids.length; i++) invalids[i].classList.remove('is-invalid');
    var errors = document.querySelectorAll('#addSalleModal .field-error');
    for (var j = 0; j < errors.length; j++) errors[j].parentNode.removeChild(errors[j]);
}

// ─────────────────────────────────────────────
// ERREUR GLOBALE
// ─────────────────────────────────────────────
function afficherErreurGlobale(msg) {
    var existing = document.getElementById('alertErreurGlobal');
    if (existing) existing.parentNode.removeChild(existing);
    var div = document.createElement('div');
    div.id = 'alertErreurGlobal';
    div.className = 'alert-erreur';
    div.innerHTML = '<i class="fas fa-exclamation-triangle"></i> ' + escHtml(msg) +
        '<button onclick="this.parentNode.remove()" style="float:right;background:none;border:none;cursor:pointer;font-size:16px;color:inherit;">&times;</button>';
    var section = document.getElementById('section-salles');
    if (section) section.insertBefore(div, section.firstChild);
}

// ─────────────────────────────────────────────
// CONTRÔLES UI
// ─────────────────────────────────────────────
function initUIControls() {
    var menuToggle = document.getElementById('menuToggle');
    var sidebar = document.getElementById('sidebar');
    var wrapper = document.getElementById('contentWrapper');
    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', function () {
            sidebar.classList.toggle('sidebar-collapsed');
            if (wrapper) wrapper.classList.toggle('sidebar-collapsed');
        });
    }

    var notifToggle = document.getElementById('notifToggle');
    var notifDropdown = document.getElementById('notifDropdown');
    if (notifToggle && notifDropdown) {
        notifToggle.addEventListener('click', function (e) {
            e.stopPropagation();
            var isOpen = notifDropdown.classList.toggle('show');
            notifToggle.setAttribute('aria-expanded', String(isOpen));
        });
    }
    document.addEventListener('click', function (e) {
        if (!notifDropdown || !notifToggle) return;
        if (!notifDropdown.contains(e.target) && !notifToggle.contains(e.target)) {
            notifDropdown.classList.remove('show');
            notifToggle.setAttribute('aria-expanded', 'false');
        }
    });

    var fsToggle = document.getElementById('fullscreenToggle');
    if (fsToggle) {
        fsToggle.addEventListener('click', function () {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen &&
                    document.documentElement.requestFullscreen().catch(function () { });
            } else {
                document.exitFullscreen && document.exitFullscreen().catch(function () { });
            }
        });
    }

    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') closeAddSalleModal();
    });

    var modal = document.getElementById('addSalleModal');
    if (modal) {
        modal.addEventListener('click', function (e) {
            if (e.target === modal) closeAddSalleModal();
        });
    }
}

// ─────────────────────────────────────────────
// UTILITAIRES
// ─────────────────────────────────────────────
function escHtml(str) {
    return String(str == null ? '' : str)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}
function dateDuJour() {
    var d = new Date();
    return d.getFullYear() + '-' +
        String(d.getMonth() + 1).padStart(2, '0') + '-' +
        String(d.getDate()).padStart(2, '0');
}

// ============================================================
// ✅ ✅ ✅ EXPOSITION GLOBALE (OBLIGATOIRE)
// ============================================================
window.openAddSalleModal = openAddSalleModal;
window.closeAddSalleModal = closeAddSalleModal;
window.saveSalle = saveSalle;
window.editSalle = editSalle;
window.deleteSalle = deleteSalle;
window.exportSalles = exportSalles;