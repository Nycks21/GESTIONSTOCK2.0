// crud.js - Gestion du stock et historique

// ============================================================
// AJUSTEMENT
// ============================================================

function openAdjustModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    document.getElementById('modalTitle').textContent = 'Ajuster le stock';
    document.getElementById('adjustArticle').value = '';
    document.getElementById('adjustEmplacement').value = '';
    document.getElementById('adjustType').value = 'ENTREE';
    document.getElementById('adjustQuantite').value = '';
    document.getElementById('adjustMotif').value = '';
    clearFieldErrors(['adjustArticle', 'adjustEmplacement', 'adjustQuantite']);
    document.getElementById('adjustModal').style.display = 'flex';
}

function openAdjustModalFromStock(e, articleId, emplacementId) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    document.getElementById('modalTitle').textContent = 'Ajuster le stock';
    document.getElementById('adjustArticle').value = articleId || '';
    document.getElementById('adjustEmplacement').value = emplacementId || '';
    document.getElementById('adjustType').value = 'ENTREE';
    document.getElementById('adjustQuantite').value = '';
    document.getElementById('adjustMotif').value = '';
    clearFieldErrors(['adjustArticle', 'adjustEmplacement', 'adjustQuantite']);
    document.getElementById('adjustModal').style.display = 'flex';
}

async function saveAdjust(e) {
    e.preventDefault();
    var data = {
        articleId: document.getElementById('adjustArticle').value,
        emplacementId: document.getElementById('adjustEmplacement').value,
        type: document.getElementById('adjustType').value,
        quantite: parseFloat(document.getElementById('adjustQuantite').value) || 0,
        motif: document.getElementById('adjustMotif').value.trim()
    };

    var valid = true;
    clearFieldErrors(['adjustArticle', 'adjustEmplacement', 'adjustQuantite']);
    if (!data.articleId) { showFieldError('adjustArticle', 'L\'article est requis'); valid = false; }
    if (!data.emplacementId) { showFieldError('adjustEmplacement', 'L\'emplacement est requis'); valid = false; }
    if (data.quantite <= 0) { showFieldError('adjustQuantite', 'La quantité doit être > 0'); valid = false; }
    if (!valid) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.ADJUST;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        var result = await resp.json();
        if (result.success) {
            showToast('Succès', result.message || 'Ajustement effectué', 'success');
            closeAdjustModal();
            loadStock();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Échec de l\'ajustement', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

function showFieldError(fieldId, msg) {
    var err = document.getElementById('err-' + fieldId);
    if (err) { err.textContent = msg; err.style.display = 'block'; }
}

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

window.openAdjustModal = openAdjustModal;
window.openAdjustModalFromStock = openAdjustModalFromStock;
window.saveAdjust = saveAdjust;
window.viewHistory = viewHistory;
window.loadHistory = loadHistory;
window.closeHistoryModal = closeHistoryModal;
window.renderHistoryTable = renderHistoryTable;
window.renderHistoryPagination = renderHistoryPagination;
