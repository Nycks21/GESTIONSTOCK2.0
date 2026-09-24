// crud.js - Module Articles avec génération automatique du CODE + i18n

// ─── Helper i18n défensif ───
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ─── Résolution d'un message serveur (priorité messageKey → message → fallback) ───
function _resolveServerMessage(result, fallbackKey) {
    if (!result) return fallbackKey ? _t(fallbackKey) : '';
    if (result.messageKey && typeof window.t === 'function') {
        return window.t(result.messageKey, result.messageParams || undefined);
    }
    if (result.message) return result.message;
    return fallbackKey ? _t(fallbackKey) : '';
}

// ─── Conversion robuste booléen (accepte bool, 1/0, "1"/"0", "true"/"false") ───
function _toBool(v, defaultVal) {
    if (v === undefined || v === null || v === '') return !!defaultVal;
    if (typeof v === 'boolean') return v;
    if (typeof v === 'number') return v !== 0;
    var s = String(v).trim().toLowerCase();
    if (['true', '1', 'oui', 'o', 'yes', 'y', 'vrai', 'eny', 'e', 'actif'].indexOf(s) !== -1) return true;
    if (['false', '0', 'non', 'n', 'no', 'faux', 'tsia', 't', 'inactif'].indexOf(s) !== -1) return false;
    return !!defaultVal;
}

// ============================================================
// GESTION CONDITIONNELLE : PÉRISSABLE → DATE DE PÉREMPTION
// ============================================================
function toggleDatePeremption() {
    var sel = document.getElementById('articleEstPerissable');
    var group = document.getElementById('articleDatePeremptionGroup');
    var dateInput = document.getElementById('articleDatePeremption');
    if (!sel || !group) return;

    var isPerissable = (sel.value === '1');
    if (isPerissable) {
        group.style.display = '';
    } else {
        group.style.display = 'none';
        // NON périssable → on efface la date (sera forcée NULL en base)
        if (dateInput) dateInput.value = '';
        clearFieldErrors(['articleDatePeremption']);
    }
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
    document.getElementById('articleSeuilAlerte').value = '';
    document.getElementById('articleActif').value = '1';
    document.getElementById('articleEstService').value = '0';

    // ═══ NOUVEL ARTICLE : PÉRISSABLE = NON par défaut, date masquée ═══
    var perissableEl = document.getElementById('articleEstPerissable');
    var dateEl = document.getElementById('articleDatePeremption');
    if (perissableEl) perissableEl.value = '0';
    if (dateEl) dateEl.value = '';
    var grp = document.getElementById('articleDatePeremptionGroup');
    if (grp) grp.style.display = 'none';

    clearFieldErrors([
        'articleCode', 'articleNom', 'articleCategorie', 'articleFournisseur',
        'articleUnite', 'articleEmplacement', 'articleSeuilAlerte', 'articleDatePeremption'
    ]);
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
    document.getElementById('articleSeuilAlerte').value =
        (article.SEUIL_ALERTE !== undefined && article.SEUIL_ALERTE !== null)
            ? article.SEUIL_ALERTE : '';
    document.getElementById('articleActif').value = _toBool(article.ACTIVE, true) ? '1' : '0';
    document.getElementById('articleEstService').value = _toBool(article.EST_SERVICE, false) ? '1' : '0';

    // ═══════════════════════════════════════════════════════════════
    // CORRECTION BUG : PÉRISSABLE doit refléter la valeur EXACTE en base
    // - accepte true/false, 1/0, "1"/"0", "true"/"false"
    // ═══════════════════════════════════════════════════════════════
    var isPerissable = _toBool(article.EST_PERISSABLE, false);

    var perissableEl = document.getElementById('articleEstPerissable');
    if (perissableEl) perissableEl.value = isPerissable ? '1' : '0';

    var dateEl = document.getElementById('articleDatePeremption');
    var grp = document.getElementById('articleDatePeremptionGroup');

    if (isPerissable) {
        if (grp) grp.style.display = '';
        if (dateEl) {
            // Le serveur renvoie "/Date(...)/" ou null → converti en yyyy-MM-dd
            dateEl.value = _toDateInputValue(article.DATE_PEREMPTION);
        }
    } else {
        if (grp) grp.style.display = 'none';
        if (dateEl) dateEl.value = '';
    }

    clearFieldErrors([
        'articleCode', 'articleNom', 'articleCategorie', 'articleFournisseur',
        'articleUnite', 'articleEmplacement', 'articleSeuilAlerte', 'articleDatePeremption'
    ]);
    document.getElementById('articleModal').style.display = 'flex';
}

// ─── Helper : convertit une valeur serveur en yyyy-MM-dd pour <input type="date"> ───
// Accepte : Objet Date, /Date(...)/, ISO yyyy-MM-dd, jj/mm/aaaa, null
function _toDateInputValue(value) {
    if (!value) return '';

    // 1) Objet Date natif
    if (value instanceof Date) {
        if (isNaN(value.getTime())) return '';
        return value.getFullYear() + '-' +
            String(value.getMonth() + 1).padStart(2, '0') + '-' +
            String(value.getDate()).padStart(2, '0');
    }

    if (typeof value === 'string') {
        var s = value.trim();
        if (!s) return '';

        // 2) Format Microsoft /Date(ms)/
        var m = s.match(/\/Date\((-?\d+)\)\//);
        if (m) {
            var d1 = new Date(parseInt(m[1], 10));
            if (isNaN(d1.getTime())) return '';
            return d1.getFullYear() + '-' +
                String(d1.getMonth() + 1).padStart(2, '0') + '-' +
                String(d1.getDate()).padStart(2, '0');
        }

        // 3) ISO yyyy-MM-dd
        if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.substring(0, 10);

        // 4) Format français jj/mm/aaaa (ou - ou .)
        var mfr = s.match(/^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})$/);
        if (mfr) {
            var day = parseInt(mfr[1], 10);
            var month = parseInt(mfr[2], 10);
            var year = parseInt(mfr[3], 10);
            if (year < 100) year += (year < 70 ? 2000 : 1900);
            var d2 = new Date(year, month - 1, day);
            if (d2.getFullYear() === year &&
                d2.getMonth() === month - 1 &&
                d2.getDate() === day) {
                return d2.getFullYear() + '-' +
                    String(d2.getMonth() + 1).padStart(2, '0') + '-' +
                    String(d2.getDate()).padStart(2, '0');
            }
            return '';
        }

        // 5) Parsing natif (ISO complet par ex.)
        var d3 = new Date(s);
        if (!isNaN(d3.getTime())) {
            return d3.getFullYear() + '-' +
                String(d3.getMonth() + 1).padStart(2, '0') + '-' +
                String(d3.getDate()).padStart(2, '0');
        }
    }
    return '';
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

    // Reset périssable/date
    var perissableEl = document.getElementById('articleEstPerissable');
    var dateEl = document.getElementById('articleDatePeremption');
    var grp = document.getElementById('articleDatePeremptionGroup');
    if (perissableEl) perissableEl.value = '0';
    if (dateEl) dateEl.value = '';
    if (grp) grp.style.display = 'none';
}

// ============================================================
// ENREGISTREMENT
// ============================================================
async function saveArticle(e) {
    e.preventDefault();
    const editingId = document.getElementById('editingId').value;

    // ─── Lecture brute du seuil d'alerte ───
    const seuilRaw = document.getElementById('articleSeuilAlerte').value;
    const seuilNum = (seuilRaw === '' || seuilRaw === null) ? NaN : parseFloat(seuilRaw);
    const seuilProvided = !isNaN(seuilNum);

    // ─── Lecture PÉRISSABLE + DATE ───
    const perissableEl = document.getElementById('articleEstPerissable');
    const dateEl = document.getElementById('articleDatePeremption');
    const estPerissable = !!(perissableEl && perissableEl.value === '1');
    let datePeremption = null;

    const data = {
        id: editingId || null,
        nom: (document.getElementById('articleNom').value || '').trim(),
        description: (document.getElementById('articleDescription').value || '').trim(),
        categorieId: document.getElementById('articleCategorie').value || null,
        fournisseurId: document.getElementById('articleFournisseur').value || null,
        uniteId: document.getElementById('articleUnite').value || null,
        emplacementId: document.getElementById('articleEmplacement').value || null,
        seuilAlerte: seuilProvided ? seuilNum : null,
        actif: document.getElementById('articleActif').value === '1',
        estService: document.getElementById('articleEstService').value === '1',
        estPerissable: estPerissable,
        datePeremption: null
    };

    // ─── Validation ───
    let valid = true;
    clearFieldErrors([
        'articleCode', 'articleNom', 'articleCategorie', 'articleFournisseur',
        'articleUnite', 'articleEmplacement', 'articleSeuilAlerte', 'articleDatePeremption'
    ]);

    const missing = [];

    if (!data.nom) {
        showFieldError('articleNom', _t('articles.msg.name_required'));
        missing.push(_t('articles.import.field.nom').toUpperCase());
        valid = false;
    }
    if (!data.categorieId) {
        showFieldError('articleCategorie', _t('articles.msg.categorie_required'));
        missing.push(_t('articles.import.field.categorie').toUpperCase());
        valid = false;
    }
    if (!data.fournisseurId) {
        showFieldError('articleFournisseur', _t('articles.msg.fournisseur_required'));
        missing.push(_t('articles.import.field.fournisseur').toUpperCase());
        valid = false;
    }
    if (!data.uniteId) {
        showFieldError('articleUnite', _t('articles.msg.unit_required'));
        missing.push(_t('articles.import.field.unite').toUpperCase());
        valid = false;
    }
    if (!data.emplacementId) {
        showFieldError('articleEmplacement', _t('articles.msg.location_required'));
        missing.push(_t('articles.import.field.emplacement').toUpperCase());
        valid = false;
    }
    if (!seuilProvided) {
        showFieldError('articleSeuilAlerte', _t('articles.msg.seuil_required'));
        missing.push(_t('articles.import.field.seuil_alerte').toUpperCase());
        valid = false;
    }

    // ─── Cohérence PÉRISSABLE / DATE DE PÉREMEPTION ───
    if (estPerissable) {
        const dateRaw = (dateEl && dateEl.value) ? dateEl.value.trim() : '';
        if (!dateRaw) {
            showFieldError('articleDatePeremption', _t('articles.msg.date_peremption_required'));
            missing.push(_t('articles.import.field.date_peremption').toUpperCase());
            valid = false;
        } else {
            // <input type="date"> renvoie toujours yyyy-MM-dd
            if (/^\d{4}-\d{2}-\d{2}$/.test(dateRaw)) {
                datePeremption = dateRaw;
            } else {
                const dt = new Date(dateRaw);
                if (isNaN(dt.getTime())) {
                    showFieldError('articleDatePeremption', _t('articles.msg.date_peremption_invalid'));
                    missing.push(_t('articles.import.field.date_peremption').toUpperCase());
                    valid = false;
                } else {
                    // Normalise en yyyy-MM-dd pour envoi serveur
                    datePeremption = dt.getFullYear() + '-' +
                        String(dt.getMonth() + 1).padStart(2, '0') + '-' +
                        String(dt.getDate()).padStart(2, '0');
                }
            }
        }
    } else {
        // NON périssable → forcer NULL
        datePeremption = null;
    }
    data.datePeremption = datePeremption;

    if (!valid) {
        if (missing.length > 1) {
            showToast(
                _t('articles.msg.required_fields_title'),
                _t('articles.msg.required_fields_text').replace('{fields}', missing.join(', ')),
                'error'
            );
        }
        return;
    }

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
            let msg;
            if (!isEdit && result.code) {
                msg = result.messageKey
                    ? _t(result.messageKey, { code: result.code })
                    : _t('articles.msg.added_with_code', { code: result.code });
            } else {
                msg = _resolveServerMessage(result,
                    isEdit ? 'articles.msg.updated' : 'articles.msg.added');
            }
            showToast(_t('message.success'), msg, 'success');
            closeArticleModal();
            loadArticles();
            loadStats();
        } else {
            const errMsg = _resolveServerMessage(result, 'articles.msg.operation_failed');
            showToast(_t('message.error'), errMsg, 'error');
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
            const errMsg = _resolveServerMessage(result, 'articles.msg.delete_failed');
            showToast(_t('message.warning'), errMsg, 'error');
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
            const msg = _resolveServerMessage(result, 'articles.msg.adjusted');
            showToast(_t('message.success'), msg, 'success');
            closeAdjustModal();
            loadArticles();
            loadStats();
        } else {
            const errMsg = _resolveServerMessage(result, 'articles.msg.adjust_failed');
            showToast(_t('message.error'), errMsg, 'error');
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
            const errMsg = _resolveServerMessage(data, 'articles.msg.history_load_error');
            showToast(_t('message.error'), errMsg, 'error');
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
window.toggleDatePeremption = toggleDatePeremption;
window._resolveServerMessage = _resolveServerMessage;
