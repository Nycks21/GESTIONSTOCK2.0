// crud.js - Module Articles avec génération automatique du CODE + i18n

// ─── Helper i18n défensif ───
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// OUVERTURE / FERMETURE MODAL ARTICLE
// ============================================================
function openAddArticleModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-box"></i> ' + _t('articles.modal.add_title');
    document.getElementById('editingId').value = '';

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('articleCode');
    codeEl.value = '';
    codeEl.placeholder = _t('articles.modal.code_auto_placeholder');
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('articleNom').value = '';
    document.getElementById('articleDescription').value = '';
    document.getElementById('articleCategorie').value = '';
    document.getElementById('articleFournisseur').value = '';
    document.getElementById('articleUnite').value = '';
    document.getElementById('articleEmplacement').value = '';
    document.getElementById('articleSeuilAlerte').value = '0';
    document.getElementById('articleActif').value = '1';
    document.getElementById('articleEstService').value = '0';

    clearFieldErrors(['articleCode', 'articleNom', 'articleUnite', 'articleEmplacement']);
    document.getElementById('articleModal').style.display = 'flex';
}

function editArticle(id) {
    AppState.editingId = id;
    const article = AppState.articles.find(a => a.ID === id);
    if (!article) {
        showToast(_t('message.error'), _t('articles.msg.not_found'), 'error');
        return;
    }
    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('articles.modal.edit_title');
    document.getElementById('editingId').value = id;

    // 🔒 Le CODE est immuable → readonly
    var codeEl = document.getElementById('articleCode');
    codeEl.value = article.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('articleNom').value = article.NOM || '';
    document.getElementById('articleDescription').value = article.DESCRIPTION || '';
    document.getElementById('articleCategorie').value = article.CATEGORIE_ID || '';
    document.getElementById('articleFournisseur').value = article.FOURNISSEUR_PREFERE_ID || '';
    document.getElementById('articleUnite').value = article.UNITE_MESURE_ID || '';
    document.getElementById('articleEmplacement').value = article.EMPLACEMENT_ID || '';
    document.getElementById('articleSeuilAlerte').value = article.SEUIL_ALERTE || 0;
    document.getElementById('articleActif').value = article.ACTIVE ? '1' : '0';
    document.getElementById('articleEstService').value = article.EST_SERVICE ? '1' : '0';

    clearFieldErrors(['articleCode', 'articleNom', 'articleUnite', 'articleEmplacement']);
    document.getElementById('articleModal').style.display = 'flex';
}

function closeArticleModal() {
    document.getElementById('articleModal').style.display = 'none';
    AppState.editingId = null;

    var codeEl = document.getElementById('articleCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = _t('articles.modal.code_auto_placeholder');
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    }
}

// ============================================================
// ENREGISTREMENT
// ============================================================
async function saveArticle(e) {
    e.preventDefault();
    const editingId = document.getElementById('editingId').value;

    const data = {
        id: editingId || null,
        nom: document.getElementById('articleNom').value.trim(),
        description: document.getElementById('articleDescription').value.trim(),
        categorieId: document.getElementById('articleCategorie').value || null,
        fournisseurId: document.getElementById('articleFournisseur').value || null,
        uniteId: document.getElementById('articleUnite').value || null,
        emplacementId: document.getElementById('articleEmplacement').value || null,
        seuilAlerte: parseFloat(document.getElementById('articleSeuilAlerte').value) || 0,
        actif: document.getElementById('articleActif').value === '1',
        estService: document.getElementById('articleEstService').value === '1'
    };

    let valid = true;
    clearFieldErrors(['articleCode', 'articleNom', 'articleUnite', 'articleEmplacement']);
    if (!data.nom) {
        showFieldError('articleNom', _t('articles.msg.name_required'));
        valid = false;
    }
    if (!data.uniteId) {
        showFieldError('articleUnite', _t('articles.msg.unit_required'));
        valid = false;
    }
    if (!data.emplacementId) {
        showFieldError('articleEmplacement', _t('articles.msg.location_required'));
        valid = false;
    }
    if (!valid) return;

    const isEdit = !!editingId;
    const url = API.BASE + API.HANDLERS_PATH + (isEdit ? API.EDIT : API.ADD);

    try {
        showSpinner();
        const resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await resp.json();

        if (result.success) {
            let msg = result.message || (isEdit ? _t('articles.msg.updated') : _t('articles.msg.added'));
            if (result.code && !isEdit) {
                msg = _t('articles.msg.added_with_code').replace('{code}', result.code);
            }
            showToast(_t('message.success'), msg, 'success');
            closeArticleModal();
            loadArticles();
            loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('articles.msg.operation_failed'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// SUPPRESSION
// ============================================================
async function deleteArticle(id) {
    const confirm = await Swal.fire({
        title: _t('articles.confirm.delete_title'),
        text: _t('articles.confirm.delete_text'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: _t('articles.confirm.delete_yes'),
        cancelButtonText: _t('button.cancel')
    });
    if (!confirm.isConfirmed) return;

    try {
        showSpinner();
        const resp = await fetch(API.BASE + API.HANDLERS_PATH + API.DELETE, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id })
        });
        const result = await resp.json();
        if (result.success) {
            showToast(_t('message.success'), _t('articles.msg.deleted'), 'success');
            loadArticles();
            loadStats();
        } else {
            showToast(_t('message.warning'), result.message || _t('articles.msg.delete_failed'), 'error');
        }
    } catch (err) {
        showToast(_t('message.warning'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// AJUSTEMENT DE STOCK
// ============================================================
function openAdjustModal(e) {
    if (e) e.preventDefault();
    document.getElementById('adjustArticle').value = '';
    document.getElementById('adjustEmplacement').value = '';
    document.getElementById('adjustType').value = 'ENTREE';
    document.getElementById('adjustQuantite').value = '';
    document.getElementById('adjustMotif').value = '';
    clearFieldErrors(['adjustQuantite']);
    document.getElementById('adjustModal').style.display = 'flex';
}

function openAdjustModalFromStock(e, articleId, emplacementId) {
    if (e) e.preventDefault();
    document.getElementById('adjustArticle').value = articleId;
    document.getElementById('adjustEmplacement').value = emplacementId;
    document.getElementById('adjustType').value = 'ENTREE';
    document.getElementById('adjustQuantite').value = '';
    document.getElementById('adjustMotif').value = '';
    clearFieldErrors(['adjustQuantite']);
    document.getElementById('adjustModal').style.display = 'flex';
}

async function saveAdjust(e) {
    e.preventDefault();
    const data = {
        articleId: document.getElementById('adjustArticle').value,
        emplacementId: document.getElementById('adjustEmplacement').value,
        type: document.getElementById('adjustType').value,
        quantite: parseFloat(document.getElementById('adjustQuantite').value) || 0,
        motif: document.getElementById('adjustMotif').value.trim()
    };

    let valid = true;
    clearFieldErrors(['adjustQuantite']);
    if (!data.articleId) {
        showToast(_t('message.error'), _t('articles.msg.article_unspecified'), 'error');
        valid = false;
    }
    if (!data.emplacementId) {
        showToast(_t('message.error'), _t('articles.msg.location_unspecified'), 'error');
        valid = false;
    }
    if (data.quantite <= 0) {
        showFieldError('adjustQuantite', _t('articles.msg.qty_positive'));
        valid = false;
    }
    if (!valid) return;

    try {
        showSpinner();
        const resp = await fetch(API.BASE + API.HANDLERS_PATH + API.ADJUST, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await resp.json();
        if (result.success) {
            showToast(_t('message.success'), result.message || _t('articles.msg.adjusted'), 'success');
            closeAdjustModal();
            loadArticles();
            loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('articles.msg.adjust_failed'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

function closeAdjustModal() {
    document.getElementById('adjustModal').style.display = 'none';
}

// ============================================================
// HISTORIQUE
// ============================================================
let historyArticleId = null;
let historyEmplacementId = null;
let historyPage = 1;
const historyPageSize = 20;
let historyTotalPages = 0;

async function viewHistory(articleId, emplacementId) {
    historyArticleId = articleId;
    historyEmplacementId = emplacementId || '';
    historyPage = 1;
    document.getElementById('historyModal').style.display = 'flex';
    await loadHistory();
}

async function loadHistory() {
    if (!historyArticleId) return;
    try {
        showSpinner();
        const params = new URLSearchParams({
            articleId: historyArticleId,
            emplacementId: historyEmplacementId,
            page: historyPage,
            pageSize: historyPageSize
        });
        const url = API.BASE + API.HANDLERS_PATH + API.MOUVEMENTS + '?' + params;
        const resp = await fetch(url);
        const data = await resp.json();
        if (data.success) {
            renderHistoryTable(data.Mouvements || []);
            historyTotalPages = data.totalPages || 1;
            renderHistoryPagination(historyTotalPages);
        } else {
            showToast(_t('message.error'), data.message || _t('articles.msg.history_load_error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

function renderHistoryTable(mouvements) {
    const tbody = document.getElementById('historyTableBody');
    if (!mouvements || !mouvements.length) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;">' + _t('articles.history.no_data') + '</td></tr>';
        return;
    }

    const labelEntry = _t('articles.history.entry');
    const labelExit = _t('articles.history.exit');

    let html = '';
    mouvements.forEach(m => {
        const typeLabel = m.TYPE === 'ENTREE' ? '✅ ' + labelEntry : '📤 ' + labelExit;
        html += '<tr>'
            + '<td>' + (m.CREATED_AT || '') + '</td>'
            + '<td>' + typeLabel + '</td>'
            + '<td>' + m.QUANTITE + '</td>'
            + '<td>' + m.QUANTITE_AVANT + '</td>'
            + '<td>' + m.QUANTITE_APRES + '</td>'
            + '<td>' + (m.MOTIF || '') + '</td>'
            + '<td>' + (m.REFERENCE_TYPE || '') + ' ' + (m.REFERENCE_NUMERO || '') + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
}

function renderHistoryPagination(totalPages) {
    const wrapper = document.getElementById('historyPagination');
    if (!wrapper) return;
    if (totalPages <= 1) { wrapper.innerHTML = ''; return; }
    let html = '<div style="display:flex;justify-content:center;gap:5px;margin-top:10px;">';
    for (let i = 1; i <= totalPages; i++) {
        const active = i === historyPage ? 'background:#007bff;color:white;' : '';
        html += '<button type="button" style="padding:5px 12px;border:1px solid #dee2e6;border-radius:4px;cursor:pointer;'
            + active + '" onclick="historyPage=' + i + ';loadHistory();">' + i + '</button>';
    }
    html += '</div>';
    wrapper.innerHTML = html;
}

function closeHistoryModal() {
    document.getElementById('historyModal').style.display = 'none';
    historyArticleId = null;
    historyEmplacementId = null;
    historyPage = 1;
}

// ============================================================
// GESTION DES ERREURS DE CHAMP
// ============================================================
function showFieldError(fieldId, msg) {
    const err = document.getElementById('err-' + fieldId);
    if (err) {
        err.textContent = msg;
        err.style.display = 'block';
    }
}

function clearFieldErrors(ids) {
    (ids || []).forEach(id => {
        const err = document.getElementById('err-' + id);
        if (err) {
            err.textContent = '';
            err.style.display = 'none';
        }
    });
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.openAddArticleModal = openAddArticleModal;
window.editArticle = editArticle;
window.closeArticleModal = closeArticleModal;
window.saveArticle = saveArticle;
window.deleteArticle = deleteArticle;
window.openAdjustModal = openAdjustModal;
window.openAdjustModalFromStock = openAdjustModalFromStock;
window.saveAdjust = saveAdjust;
window.closeAdjustModal = closeAdjustModal;
window.viewHistory = viewHistory;
window.loadHistory = loadHistory;
window.closeHistoryModal = closeHistoryModal;
window.showFieldError = showFieldError;
window.clearFieldErrors = clearFieldErrors;
