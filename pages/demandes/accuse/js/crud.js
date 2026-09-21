// ============================================================
// CRUD - ACCUSE (visualisation + accusés de réception)
// ============================================================

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
    document.getElementById('accuseNom').value         = sortie.NOM         || '';
    document.getElementById('accuseFonction').value    = sortie.FONCTION    || '';
    document.getElementById('accuseNotes').value       = sortie.NOTES       || '';

    var tbody = document.getElementById('accuseLignesBody');
    tbody.innerHTML = '';
    var lignes = sortie.Lignes || [];
    if (lignes.length) {
        lignes.forEach(function (l, index) {
            var tr = document.createElement('tr');
            tr.innerHTML =
                '<td style="text-align:center;width:5%;">' + (index + 1) + '</td>' +
                '<td style="text-align:left;width:30%;">' +
                    (l.ARTICLE_CODE ? l.ARTICLE_CODE + ' - ' : '') + (l.ARTICLE_NOM || '') +
                '</td>' +
                '<td style="text-align:right;width:15%;">' + formatNumber(l.QUANTITE_D, 2) + '</td>' +
                '<td style="text-align:right;width:15%;">' + formatNumber(l.QUANTITE_R, 2) + '</td>' +
                '<td style="text-align:left;width:30%;">' + (l.OBSERVATIONS || '') + '</td>';
            tbody.appendChild(tr);
        });
    } else {
        tbody.innerHTML = '<tr><td colspan="5" class="text-center">' +
            T('accuses.modal.lignes_no_data', 'Aucune ligne') +
            '</td></tr>';
    }

    showModal('accuseModal');
}

function closeAccuseModal() {
    closeModal('accuseModal');
}

// ============================================================
// ACCUSÉ DE RÉCEPTION AVEC DATE OBLIGATOIRE
// ============================================================
async function accuseReceipt(id) {
    if (!id) return;

    if (__accuseInProgress[id]) return;
    __accuseInProgress[id] = true;

    var today = new Date();
    var pad = function (v) { return String(v).padStart(2, '0'); };
    var todayStr = today.getFullYear() + '-' + pad(today.getMonth() + 1) + '-' + pad(today.getDate());

    var confirmation = await Swal.fire({
        icon: 'question',
        title: T('accuses.confirm.title', 'Confirmer la réception ?'),
        html:
            '<div style="text-align:left;padding:0 8px;">' +
                '<p style="margin-bottom:14px;color:#495057;font-size:14px;line-height:1.5;">' +
                    T('accuses.confirm.question', 'Confirmez-vous que <b>vous avez reçu tous les articles</b> ?') +
                    '<br><small style="color:#6c757d;"><i>' +
                        T('accuses.confirm.hint', 'Le bon passera au statut <b>TERMINE</b>.') +
                    '</i></small>' +
                '</p>' +
                '<label for="swalDateReception" style="font-weight:600;font-size:13px;' +
                       'display:block;margin-bottom:6px;color:#212529;">' +
                    T('accuses.confirm.date_label', 'Date de réception') +
                    ' <span style="color:#dc3545;">*</span>' +
                '</label>' +
                '<input type="date" id="swalDateReception" value="' + todayStr + '" ' +
                       'style="width:100%;padding:10px 12px;font-size:14px;' +
                              'border:1px solid #ced4da;border-radius:6px;' +
                              'box-sizing:border-box;outline:none;" />' +
                '<div id="swalDateError" ' +
                     'style="color:#dc3545;font-size:12px;margin-top:6px;display:none;"></div>' +
            '</div>',
        showCancelButton: true,
        confirmButtonText: '<i class="fas fa-check-double"></i> ' + T('accuses.confirm.yes', 'Oui, confirmer'),
        cancelButtonText: T('accuses.confirm.cancel', 'Annuler'),
        confirmButtonColor: '#28a745',
        cancelButtonColor: '#6c757d',
        reverseButtons: true,
        focusConfirm: false,
        didOpen: function () {
            var input = document.getElementById('swalDateReception');
            if (input) {
                input.focus();
                setTimeout(function () {
                    try { input.select(); } catch (e) { /* ignore */ }
                }, 100);
            }
        },
        preConfirm: function () {
            var input = document.getElementById('swalDateReception');
            var errEl = document.getElementById('swalDateError');
            var value = input ? input.value : '';

            if (!value) {
                if (errEl) {
                    errEl.textContent = T('accuses.msg.date_required', 'La date de réception est obligatoire.');
                    errEl.style.display = 'block';
                }
                return false;
            }

            var dateObj = new Date(value);
            if (isNaN(dateObj.getTime())) {
                if (errEl) {
                    errEl.textContent = T('accuses.msg.date_invalid', 'Date invalide.');
                    errEl.style.display = 'block';
                }
                return false;
            }

            var todayObj = new Date();
            todayObj.setHours(0, 0, 0, 0);
            dateObj.setHours(0, 0, 0, 0);
            if (dateObj > todayObj) {
                if (errEl) {
                    errEl.textContent = T('accuses.msg.date_future', 'La date de réception ne peut pas être dans le futur.');
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

    var clickedBtn = null;
    document.querySelectorAll('button[onclick*="' + id + '"]').forEach(function (btn) {
        var title = btn.getAttribute('title') || '';
        var btnAccuse = T('accuses.btn.accuse', 'Confirmer la réception des articles');
        if (title === btnAccuse || (btn.textContent || '').indexOf('Accus') !== -1) {
            clickedBtn = btn;
            btn.disabled = true;
            btn.dataset.originalHtml = btn.innerHTML;
            btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> ' +
                            T('accuses.confirm.processing', 'Traitement...');
        }
    });

    showSpinner();

    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.SET_ACCUSE;
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
            throw new Error(T('accuses.msg.server_error', 'Réponse serveur invalide'));
        }

        if (data && data.success) {
            await Swal.fire({
                icon: 'success',
                title: T('accuses.confirm.ok_title', 'Réception confirmée'),
                html:
                    '<p style="margin:0;color:#495057;">' +
                        (data.message || T('accuses.confirm.ok_default', 'Le bon a été marqué comme TERMINE.')) +
                    '</p>',
                timer: 2200,
                showConfirmButton: false
            });
            loadAccuse({ silent: true });
        } else {
            Swal.fire({
                icon: 'error',
                title: T('accuses.confirm.fail_title', 'Échec'),
                text: (data && data.message) || T('accuses.confirm.fail_default', 'Impossible de marquer le bon comme terminé.'),
                confirmButtonColor: '#dc3545'
            });
            if (clickedBtn && clickedBtn.dataset.originalHtml) {
                clickedBtn.disabled = false;
                clickedBtn.innerHTML = clickedBtn.dataset.originalHtml;
            }
        }
    } catch (err) {
        console.error('accuseReceipt error:', err);
        Swal.fire({
            icon: 'error',
            title: T('message.error', 'Erreur'),
            text: err.message || T('accuses.msg.comm_error', 'Erreur de communication avec le serveur.'),
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

window.viewAccuse       = viewAccuse;
window.closeAccuseModal = closeAccuseModal;
window.accuseReceipt    = accuseReceipt;
