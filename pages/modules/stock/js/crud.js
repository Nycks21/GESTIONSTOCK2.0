// crud.js - Gestion de l'historique du stock (suppression des ajustements)

// ============================================================
// HISTORIQUE
// ============================================================

var historyArticleId = null;
var historyEmplacementId = null;
var historyPage = 1;
var historyPageSize = 20;
var historyTotalPages = 0;

async function viewHistory(articleId, emplacementId) {
    if (!articleId || !emplacementId) {
        showToast('Erreur', 'Article ou emplacement manquant', 'error');
        return;
    }
    historyArticleId = articleId;
    historyEmplacementId = emplacementId;
    historyPage = 1;
    document.getElementById('historyModal').style.display = 'flex';
    await loadHistory();
}

async function loadHistory() {
    if (!historyArticleId || !historyEmplacementId) return;
    try {
        showSpinner();
        var params = new URLSearchParams({
            articleId: historyArticleId,
            emplacementId: historyEmplacementId,
            page: historyPage,
            pageSize: historyPageSize
        });
        var url = API.BASE + API.HANDLERS_PATH + API.MOUVEMENTS + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            renderHistoryTable(data.Mouvements || []);
            historyTotalPages = data.totalPages || 1;
            renderHistoryPagination(historyTotalPages);
        } else {
            showToast('Erreur', data.message || 'Impossible de charger l\'historique', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

function renderHistoryTable(mouvements) {
    var tbody = document.getElementById('historyTableBody');
    if (!tbody) return;
    if (!mouvements || !mouvements.length) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;padding:20px;">Aucun mouvement trouvé</td></tr>';
        return;
    }
    var html = '';
    mouvements.forEach(function(m) {
        var typeLabel = m.TYPE === 'ENTREE' ? '✅ Entrée' : '📤 Sortie';
        var date = m.CREATED_AT || '';
        html += '<tr>' +
            '<td>' + date + '</td>' +
            '<td>' + typeLabel + '</td>' +
            '<td>' + (m.QUANTITE || 0) + '</td>' +
            '<td>' + (m.QUANTITE_AVANT || 0) + '</td>' +
            '<td>' + (m.QUANTITE_APRES || 0) + '</td>' +
            '<td>' + (m.MOTIF || '') + '</td>' +
            '<td>' + (m.REFERENCE_TYPE || '') + ' ' + (m.REFERENCE_NUMERO || '') + '</td>' +
            '</tr>';
    });
    tbody.innerHTML = html;
}

function renderHistoryPagination(totalPages) {
    var wrapper = document.getElementById('historyPagination');
    if (!wrapper) return;
    if (totalPages <= 1) {
        wrapper.innerHTML = '';
        return;
    }
    var container = document.createElement('div');
    container.style.cssText = 'display:flex;justify-content:center;gap:5px;margin-top:10px;';
    for (var i = 1; i <= totalPages; i++) {
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.textContent = i;
        btn.style.cssText = 'padding:5px 12px;border:1px solid ' + (i === historyPage ? '#007bff' : '#dee2e6') + ';' +
            'background:' + (i === historyPage ? '#007bff' : 'white') + ';' +
            'color:' + (i === historyPage ? 'white' : '#333') + ';' +
            'cursor:pointer;border-radius:4px;';
        btn.addEventListener('click', function() {
            historyPage = i;
            loadHistory();
        });
        container.appendChild(btn);
    }
    wrapper.innerHTML = '';
    wrapper.appendChild(container);
}

function closeHistoryModal() {
    var modal = document.getElementById('historyModal');
    if (modal) modal.style.display = 'none';
    historyArticleId = null;
    historyEmplacementId = null;
    historyPage = 1;
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================

window.viewHistory = viewHistory;
window.loadHistory = loadHistory;
window.closeHistoryModal = closeHistoryModal;
window.renderHistoryTable = renderHistoryTable;
window.renderHistoryPagination = renderHistoryPagination;
