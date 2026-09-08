// crud.js

// ---- OUVERTURE / FERMETURE MODAL ARTICLE ----
function openAddArticleModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;
    document.getElementById('modalTitle').textContent = 'Ajouter un article';
    document.getElementById('editingId').value = '';
    document.getElementById('articleCode').value = '';
    document.getElementById('articleNom').value = '';
    document.getElementById('articleDescription').value = '';
    document.getElementById('articleCategorie').value = '';
    document.getElementById('articleFournisseur').value = '';
    document.getElementById('articleUnite').value = '';
    document.getElementById('articleEmplacement').value = '';
    document.getElementById('articleSeuilAlerte').value = '0';
    document.getElementById('articleSeuilMin').value = '0';
    document.getElementById('articleActif').value = '1';
    document.getElementById('articleEstService').value = '0';
    clearFieldErrors(['articleCode','articleNom','articleUnite','articleEmplacement']);
    document.getElementById('articleModal').style.display = 'flex';
}

function editArticle(id) {
    AppState.editingId = id;
    const article = AppState.articles.find(a => a.ID === id);
    if (!article) {
        showToast('Erreur', 'Article introuvable', 'error');
        return;
    }
    document.getElementById('modalTitle').textContent = 'Modifier l\'article';
    document.getElementById('editingId').value = id;
    document.getElementById('articleCode').value = article.CODE || '';
    document.getElementById('articleNom').value = article.NOM || '';
    document.getElementById('articleDescription').value = article.DESCRIPTION || '';
    document.getElementById('articleCategorie').value = article.CATEGORIE_ID || '';
    document.getElementById('articleFournisseur').value = article.FOURNISSEUR_PREFERE_ID || '';
    document.getElementById('articleUnite').value = article.UNITE_MESURE_ID || '';
    document.getElementById('articleEmplacement').value = article.EMPLACEMENT_ID || '';
    document.getElementById('articleSeuilAlerte').value = article.SEUIL_ALERTE || 0;
    document.getElementById('articleSeuilMin').value = article.SEUIL_MIN || 0;
    document.getElementById('articleActif').value = article.ACTIVE ? '1' : '0';
    document.getElementById('articleEstService').value = article.EST_SERVICE ? '1' : '0';
    clearFieldErrors(['articleCode','articleNom','articleUnite','articleEmplacement']);
    document.getElementById('articleModal').style.display = 'flex';
}

function closeArticleModal() {
    document.getElementById('articleModal').style.display = 'none';
    AppState.editingId = null;
}

async function saveArticle(e) {
    e.preventDefault();
    const editingId = document.getElementById('editingId').value;
    const data = {
        id: editingId || null,
        code: document.getElementById('articleCode').value.trim(),
        nom: document.getElementById('articleNom').value.trim(),
        description: document.getElementById('articleDescription').value.trim(),
        categorieId: document.getElementById('articleCategorie').value || null,
        fournisseurId: document.getElementById('articleFournisseur').value || null,
        uniteId: document.getElementById('articleUnite').value || null,
        emplacementId: document.getElementById('articleEmplacement').value || null,
        seuilAlerte: parseFloat(document.getElementById('articleSeuilAlerte').value) || 0,
        seuilMin: parseFloat(document.getElementById('articleSeuilMin').value) || 0,
        actif: document.getElementById('articleActif').value === '1',
        estService: document.getElementById('articleEstService').value === '1'
    };

    let valid = true;
    clearFieldErrors(['articleCode','articleNom','articleUnite','articleEmplacement']);
    if (!data.code) { showFieldError('articleCode', 'Le code est requis'); valid = false; }
    if (!data.nom) { showFieldError('articleNom', 'Le nom est requis'); valid = false; }
    if (!data.uniteId) { showFieldError('articleUnite', 'L\'unité est requise'); valid = false; }
    if (!data.emplacementId) { showFieldError('articleEmplacement', 'L\'emplacement est requis'); valid = false; }
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
            showToast('Succès', result.message || (isEdit ? 'Modifié' : 'Ajouté') + ' avec succès', 'success');
            closeArticleModal();
            loadArticles();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Opération échouée', 'error');
        }
    } catch (err) {
        showToast('Erreur', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

async function deleteArticle(id) {
    const confirm = await Swal.fire({
        title: 'Supprimer ?',
        text: 'Cette action est irréversible (suppression logique).',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
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
            showToast('Succès', 'Article supprimé', 'success');
            loadArticles();
            loadStats();
        } else {
            showToast('Attention', result.message || 'Échec de la suppression', 'error');
        }
    } catch (err) {
        showToast('Attention', err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ---- AJUSTEMENT ----
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
    if (!data.articleId) { showToast('Erreur', 'Article non spécifié', 'error'); valid = false; }
    if (!data.emplacementId) { showToast('Erreur', 'Emplacement non spécifié', 'error'); valid = false; }
    if (data.quantite <= 0) { showFieldError('adjustQuantite', 'Quantité > 0 requise'); valid = false; }
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
            showToast('Succès', result.message || 'Ajustement effectué', 'success');
            closeAdjustModal();
            loadArticles();
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

function closeAdjustModal() {
    document.getElementById('adjustModal').style.display = 'none';
}

// ---- HISTORIQUE ----
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
            showToast('Erreur', data.message || 'Impossible de charger l\'historique', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

function renderHistoryTable(mouvements) {
    const tbody = document.getElementById('historyTableBody');
    if (!mouvements || !mouvements.length) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;">Aucun mouvement trouvé</td></tr>';
        return;
    }
    let html = '';
    mouvements.forEach(m => {
        const typeLabel = m.TYPE === 'ENTREE' ? '✅ Entrée' : '📤 Sortie';
        html += `<tr>
            <td>${m.CREATED_AT || ''}</td>
            <td>${typeLabel}</td>
            <td>${m.QUANTITE}</td>
            <td>${m.QUANTITE_AVANT}</td>
            <td>${m.QUANTITE_APRES}</td>
            <td>${m.MOTIF || ''}</td>
            <td>${m.REFERENCE_TYPE || ''} ${m.REFERENCE_NUMERO || ''}</td>
        </tr>`;
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
        html += `<button type="button" style="padding:5px 12px;border:1px solid #dee2e6;border-radius:4px;cursor:pointer;${active}" onclick="historyPage=${i};loadHistory();">${i}</button>`;
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

// Utilitaires
function showFieldError(fieldId, msg) {
    const err = document.getElementById('err-' + fieldId);
    if (err) { err.textContent = msg; err.style.display = 'block'; }
}
function clearFieldErrors(ids) {
    (ids || []).forEach(id => {
        const err = document.getElementById('err-' + id);
        if (err) { err.textContent = ''; err.style.display = 'none'; }
    });
}

// Expositions globales
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
