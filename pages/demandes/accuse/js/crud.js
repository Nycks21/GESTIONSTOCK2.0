// ============================================================
// CRUD - ACCUSE (visualisation uniquement)
// ============================================================

function viewAccuse(id) {
    var sortie = AppState.sorties.find(function (s) { return s.ID === id; });
    if (!sortie) return;

    // Remplir les champs du modal
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

    // Lignes
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

window.viewAccuse = viewAccuse;
window.closeAccuseModal = closeAccuseModal;
