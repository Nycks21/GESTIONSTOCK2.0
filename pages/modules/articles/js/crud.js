// ============================================================
// CRUD - Gestion des articles
// ============================================================

var currentArticleId = null; // ID de l'article en cours d'édition

function openAddArticleModal(e) {
    if (e) e.preventDefault();
    currentArticleId = null;
    document.getElementById('modalTitle').textContent = 'Ajouter un article';
    document.getElementById('articleForm').reset();
    clearErrors();
    document.getElementById('articleModal').style.display = 'flex';
}

function editArticle(id) {
    var article = AppState.articles.find(function (a) { return a.ID === id; });
    if (!article) return;
    currentArticleId = id;
    document.getElementById('modalTitle').textContent = 'Modifier un article';
    document.getElementById('articleCode').value = article.CODE || '';
    document.getElementById('articleNom').value = article.NOM || '';
    document.getElementById('articleDescription').value = article.DESCRIPTION || '';
    document.getElementById('articleCategorie').value = article.CATEGORIE_ID || '';
    document.getElementById('articleFournisseur').value = article.FOURNISSEUR_PREFERE_ID || '';
    document.getElementById('articlePoids').value = article.STOCK_DISPONIBLE || 0;
    // Remplissage robuste du select `articleUnite` : accepter plusieurs clés retournées par le serveur
    var uniteSelect = document.getElementById('articleUnite');
    if (uniteSelect) {
        var unitId = article.UNITE_MESURE_ID || article.UNITE_ID || article.UNITE_IDENTIFIANT || '';
        if (unitId) {
            uniteSelect.value = unitId;
        } else if (article.UNITE) {
            // essayer de faire correspondre par le texte de l'option (nom de l'unité)
            var match = Array.from(uniteSelect.options).find(function (opt) {
                return (opt.text || '').toString().trim() === (article.UNITE || '').toString().trim();
            });
            if (match) uniteSelect.value = match.value;
            else uniteSelect.value = '';
        } else {
            uniteSelect.value = '';
        }
    }
    document.getElementById('articleSeuilAlerte').value = article.SEUIL_ALERTE || 0;
    document.getElementById('articleSeuilMin').value = article.SEUIL_MIN || 0;
    document.getElementById('articleActif').value = article.ACTIVE ? '1' : '0';
    document.getElementById('articleEstService').value = article.EST_SERVICE ? '1' : '0';
    clearErrors();
    document.getElementById('articleModal').style.display = 'flex';
}

async function saveArticle(e) {
    e.preventDefault();
    var id = currentArticleId;
    var data = {
        code: document.getElementById('articleCode').value.trim(),
        nom: document.getElementById('articleNom').value.trim(),
        description: document.getElementById('articleDescription').value.trim(),
        categorieId: document.getElementById('articleCategorie').value,
        fournisseurId: document.getElementById('articleFournisseur').value,
        stock: parseFloat(document.getElementById('articlePoids').value) || 0,
        uniteId: document.getElementById('articleUnite').value,
        seuilAlerte: parseFloat(document.getElementById('articleSeuilAlerte').value) || 0,
        seuilMin: parseFloat(document.getElementById('articleSeuilMin').value) || 0,
        actif: parseInt(document.getElementById('articleActif').value) === 1,
        estService: parseInt(document.getElementById('articleEstService').value) === 1,
    };

    var valid = true;
    clearErrors();
    if (!data.code) { showError('articleCode', 'Le code est requis'); valid = false; }
    if (!data.nom) { showError('articleNom', 'Le nom est requis'); valid = false; }
    if (!data.fournisseurId) { showError('articleFournisseur', 'Le fournisseur est requis'); valid = false; }
    if (!data.uniteId) { showError('articleUnite', "L'unité est requise"); valid = false; }
    if (data.seuilMin < 0) { showError('articleSeuilMin', 'Le seuil minimum doit être ≥ 0'); valid = false; }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload = id ? Object.assign({}, data, { id: id }) : data;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + endpoint;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        var result = await resp.json();
        if (result.success) {
            showToast('Succès', result.message || (id ? 'Article modifié' : 'Article ajouté'), 'success');
            closeArticleModal();
            loadArticles();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Une erreur est survenue', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

async function deleteArticle(id) {
    var confirmResult = await Swal.fire({
        title: 'Confirmer la suppression',
        text: 'Voulez-vous vraiment supprimer cet article ?',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler'
    });
    if (!confirmResult.isConfirmed) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.DELETE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id }),
        });
        var result = await resp.json();
        if (result.success) {
            showToast('Succès', 'Article supprimé', 'success');
            loadArticles();
            loadStats();
        } else {
            showToast('Erreur', result.message || 'Échec de la suppression', 'error');
        }
    } catch (e) {
        showToast('Erreur', e.message, 'error');
    } finally {
        hideSpinner();
    }
}

function closeArticleModal() {
    document.getElementById('articleModal').style.display = 'none';
    currentArticleId = null;
    clearErrors();
}

function showError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
}

function clearErrors() {
    var errors = document.querySelectorAll('.field-error');
    for (var i = 0; i < errors.length; i++) {
        errors[i].textContent = '';
        errors[i].style.display = 'none';
    }
}

// Expositions globales pour les appels onclick
window.openAddArticleModal = openAddArticleModal;
window.editArticle = editArticle;
window.saveArticle = saveArticle;
window.deleteArticle = deleteArticle;
window.closeArticleModal = closeArticleModal;
window.clearErrors = clearErrors;
