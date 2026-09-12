// ============================================================
// CRUD - ACCUSE (visualisation + accusés de réception)
// ============================================================

// ✅ Ensemble des IDs en cours de traitement (anti double-clic)
var __accuseInProgress = {};

// ============================================================
// VISUALISATION
// ============================================================
function viewAccuse(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!sortie) return;

    document.getElementById('accuseNumero').value = sortie.NUMERO || '';
    var dateStr = '';
    if (sortie.DATE_SORTIE) {
        try {
            var dateValue = String(sortie.DATE_SORTIE);
            var dotNetDate = dateValue.match(/^\/Date\((-?\d+)\)\/$/);
            var d = dotNetDate ? new Date(Number(dotNetDate[1])) : new Date(dateValue);
            if (!isNaN(d.getTime())) {
                var pad = function (value) { return String(value).padStart(2, '0'); };
                dateStr = d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
                    'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
            }
        } catch (e) { /* ignore */ }
    }
    document.getElementById('accuseDate').value = dateStr;
    document.getElementById('accuseDestination').value = sortie.DESTINATION || '';
    document.getElementById('accuseNom').value = sortie.NOM || '';
    document.getElementById('accuseFonction').value = sortie.FONCTION || '';
    document.getElementById('accuseNotes').value = sortie.NOTES || '';

    var tbody = document.getElementById('accuseLignesBody');
    tbody.innerHTML = '';
    var lignes = sortie.Lignes || [];
    if (lignes.length) {
        lignes.forEach(function (l, index) {
            var tr = document.createElement('tr');
            tr.innerHTML = `
                <td style="text-align:center;width: 5%;">${index + 1}</td>
                <td style="text-align:left;width: 30%;">${l.ARTICLE_CODE ? l.ARTICLE_CODE + ' - ' : ''}${l.ARTICLE_NOM || ''}</td>
                <td style="text-align:right;width: 15%;">${formatNumber(l.QUANTITE_D, 2)}</td>
                <td style="text-align:right;width: 15%;">${formatNumber(l.QUANTITE_R, 2)}</td>
                <td style="text-align:left;width: 30%;">${l.OBSERVATIONS || ''}</td>
            `;
            tbody.appendChild(tr);
        });
    } else {
        tbody.innerHTML = '<tr><td colspan="5" class="text-center">Aucune ligne</td></tr>';
    }

    showModal('accuseModal');
}

function closeAccuseModal() {
    closeModal('accuseModal');
}

// ============================================================
// ✅ ACCUSÉ DE RÉCEPTION AVEC DATE OBLIGATOIRE
// ============================================================

/**
 * Marque un bon de sortie comme TERMINE (articles reçus par le demandeur).
 * 1. Modal avec champ Date de réception (pré-rempli à aujourd'hui)
 * 2. Validation client (obligatoire, non future)
 * 3. Appel serveur sécurisé
 * 4. Rafraîchissement de la liste
 */
async function accuseReceipt(id) {
    if (!id) return;

    // ✅ Anti double-clic
    if (__accuseInProgress[id]) return;
    __accuseInProgress[id] = true;

    // ✅ Préparer la date du jour au format yyyy-MM-dd
    var today = new Date();
    var pad = function (v) { return String(v).padStart(2, '0'); };
    var todayStr = today.getFullYear() + '-' + pad(today.getMonth() + 1) + '-' + pad(today.getDate());

    // ============================================================
    // MODAL DE CONFIRMATION AVEC CHAMP DATE
    // ============================================================
    var confirmation = await Swal.fire({
        icon: 'question',
        title: 'Confirmer la réception ?',
        html:
            '<div style="text-align:left;padding:0 8px;">' +
                '<p style="margin-bottom:14px;color:#495057;font-size:14px;line-height:1.5;">' +
                    'Confirmez-vous que <b>vous avez reçu tous les articles</b> ?' +
                    '<br><small style="color:#6c757d;">' +
                        '<i>Le bon passera au statut <b>TERMINE</b>.</i>' +
                    '</small>' +
                '</p>' +
                '<label for="swalDateReception" ' +
                       'style="font-weight:600;font-size:13px;display:block;margin-bottom:6px;color:#212529;">' +
                    'Date de réception <span style="color:#dc3545;">*</span>' +
                '</label>' +
                '<input type="date" id="swalDateReception" ' +
                       'value="' + todayStr + '" ' +
                       'style="width:100%;padding:10px 12px;font-size:14px;' +
                              'border:1px solid #ced4da;border-radius:6px;' +
                              'box-sizing:border-box;outline:none;" />' +
                '<div id="swalDateError" ' +
                     'style="color:#dc3545;font-size:12px;margin-top:6px;display:none;"></div>' +
            '</div>',
        showCancelButton: true,
        confirmButtonText: '<i class="fas fa-check-double"></i> Oui, confirmer',
        cancelButtonText: 'Annuler',
        confirmButtonColor: '#28a745',
        cancelButtonColor: '#6c757d',
        reverseButtons: true,
        focusConfirm: false,
        didOpen: function () {
            // Focus sur le champ date à l'ouverture
            var input = document.getElementById('swalDateReception');
            if (input) {
                input.focus();
                // Sélection visuelle après ouverture
                setTimeout(function () {
                    try { input.select(); } catch (e) { /* ignore */ }
                }, 100);
            }
        },
        preConfirm: function () {
            var input = document.getElementById('swalDateReception');
            var errEl = document.getElementById('swalDateError');
            var value = input ? input.value : '';

            // ✅ Validation : champ obligatoire
            if (!value) {
                if (errEl) {
                    errEl.textContent = 'La date de réception est obligatoire.';
                    errEl.style.display = 'block';
                }
                return false; // bloque la fermeture du modal
            }

            // ✅ Validation : date valide
            var dateObj = new Date(value);
            if (isNaN(dateObj.getTime())) {
                if (errEl) {
                    errEl.textContent = 'Date invalide.';
                    errEl.style.display = 'block';
                }
                return false;
            }

            // ✅ Validation : pas de date dans le futur
            var today = new Date();
            today.setHours(0, 0, 0, 0);
            dateObj.setHours(0, 0, 0, 0);
            if (dateObj > today) {
                if (errEl) {
                    errEl.textContent = 'La date de réception ne peut pas être dans le futur.';
                    errEl.style.display = 'block';
                }
                return false;
            }

            if (errEl) errEl.style.display = 'none';
            return { dateReception: value };
        }
    });

    if (!confirmation.isConfirmed || !confirmation.value) {
        delete __accuseInProgress[id];
        return;
    }

    // ✅ Désactivation visuelle du bouton pour éviter un double-clic
    var clickedBtn = null;
    document.querySelectorAll('button[onclick*="' + id + '"]').forEach(function (btn) {
        if (btn.textContent.indexOf('Accus') !== -1 ||
            (btn.getAttribute('title') || '').indexOf('réception') !== -1) {
            clickedBtn = btn;
            btn.disabled = true;
            btn.dataset.originalHtml = btn.innerHTML;
            btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Traitement...';
        }
    });

    showSpinner();

    try {
        // ✅ Appel POST au handler serveur
        var url = API.BASE + API.HANDLERS_PATH + API.SET_ACCUSE;
        var body = new URLSearchParams();
        body.append('id', id);
        body.append('dateReception', confirmation.value.dateReception);

        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
            body: body.toString()
        });

        var data;
        try {
            data = await resp.json();
        } catch (parseErr) {
            throw new Error('Réponse serveur invalide');
        }

        if (data && data.success) {
            await Swal.fire({
                icon: 'success',
                title: 'Réception confirmée',
                html:
                    '<p style="margin:0;color:#495057;">' +
                        (data.message || 'Le bon a été marqué comme TERMINE.') +
                    '</p>',
                timer: 2200,
                showConfirmButton: false
            });
            // ✅ Recharger la liste pour refléter le nouveau statut
            loadAccuse({ silent: true });
        } else {
            Swal.fire({
                icon: 'error',
                title: 'Échec',
                text: (data && data.message) || 'Impossible de marquer le bon comme terminé.',
                confirmButtonColor: '#dc3545'
            });
            // Restaurer le bouton
            if (clickedBtn && clickedBtn.dataset.originalHtml) {
                clickedBtn.disabled = false;
                clickedBtn.innerHTML = clickedBtn.dataset.originalHtml;
            }
        }
    } catch (err) {
        console.error('accuseReceipt error:', err);
        Swal.fire({
            icon: 'error',
            title: 'Erreur',
            text: err.message || 'Erreur de communication avec le serveur.',
            confirmButtonColor: '#dc3545'
        });
        if (clickedBtn && clickedBtn.dataset.originalHtml) {
            clickedBtn.disabled = false;
            clickedBtn.innerHTML = clickedBtn.dataset.originalHtml;
        }
    } finally {
        hideSpinner();
        delete __accuseInProgress[id];
    }
}

window.viewAccuse = viewAccuse;
window.closeAccuseModal = closeAccuseModal;
window.accuseReceipt = accuseReceipt;
