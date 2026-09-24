/**
 * import.js — Importation Excel des ARTICLES (wizard dans un modal)
 * Reprend la logique d'utilitaire.js (IMPORT ELEVE) adaptée à MARTICLE.
 * Le STOCK INITIAL, SEUIL_MIN et SEUIL_MAX ne sont plus gérés ici :
 *  - le stock est alimenté uniquement par les mouvements entrée/sortie ;
 *  - seuls les seuils min/max restent éditables via la modale Article.
 *
 * RÈGLE STRICTE :
 *  - impossible de passer à l'étape 4 tant qu'il reste AU MOINS UNE anomalie ;
 *  - cohérence obligatoire EST_PERISSABLE ↔ DATE_PEREMPTION.
 *  - Toutes les chaînes passent par _t() → multilingue FR/EN/MG.
 *  - DATE_PEREMPTION : affichage et saisie Excel en jj/mm/aaaa.
 */
'use strict';

// ═══════════════════════════════════════════════════════════════
// HELPERS i18n
// ═══════════════════════════════════════════════════════════════
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

function _resolveServerMessage(obj, fallbackKey) {
    if (!obj) return fallbackKey ? _t(fallbackKey) : '';
    if (obj.messageKey && typeof window.t === 'function') {
        return window.t(obj.messageKey, obj.messageParams || undefined);
    }
    if (obj.message) return obj.message;
    return fallbackKey ? _t(fallbackKey) : '';
}

function _resolveErr(e) {
    if (!e) return '';
    if (e.messageKey && typeof window.t === 'function') {
        return window.t(e.messageKey);
    }
    return e.message || '';
}

function _resolveDup(d) {
    if (!d) return '';
    if (d.raisonKey && typeof window.t === 'function') {
        return window.t(d.raisonKey);
    }
    return d.raison || _t('articles.import.duplicate_in_file');
}

// ═══════════════════════════════════════════════════════════════
// HELPERS DATE (jj/mm/aaaa)
// ═══════════════════════════════════════════════════════════════

// Parse une valeur de date depuis plusieurs sources et retourne un Date JS valide,
// ou null si le format est invalide.
// Accepte :
//   - Objet Date (SheetJS avec cellDates:true)
//   - Nombre (numéro de série Excel)
//   - Chaîne "jj/mm/aaaa" ou "jj-mm-aaaa" ou "jj.mm.aaaa"  ← PRIORITAIRE
//   - Chaîne "aaaa-mm-jj" (ISO, rétrocompatibilité)
function aiParseDate(v) {
    if (v === undefined || v === null || v === '') return null;

    if (v instanceof Date) {
        return isNaN(v.getTime()) ? null : v;
    }

    if (typeof v === 'number') {
        // Numéro de série Excel : base 1899-12-30
        var d0 = new Date(Math.round((v - 25569) * 86400 * 1000));
        return isNaN(d0.getTime()) ? null : d0;
    }

    var s = String(v).trim();
    if (!s) return null;

    // Format jj/mm/aaaa (ou -, .) — PRIORITAIRE
    var m = s.match(/^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})$/);
    if (m) {
        var day = parseInt(m[1], 10);
        var month = parseInt(m[2], 10);
        var year = parseInt(m[3], 10);
        if (year < 100) year += (year < 70 ? 2000 : 1900);
        var d1 = new Date(year, month - 1, day);
        if (d1.getFullYear() === year &&
            d1.getMonth() === month - 1 &&
            d1.getDate() === day) {
            return d1;
        }
        return null;
    }

    // Format aaaa-mm-jj (ISO)
    m = s.match(/^(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})$/);
    if (m) {
        var year2 = parseInt(m[1], 10);
        var month2 = parseInt(m[2], 10);
        var day2 = parseInt(m[3], 10);
        var d2 = new Date(year2, month2 - 1, day2);
        if (d2.getFullYear() === year2 &&
            d2.getMonth() === month2 - 1 &&
            d2.getDate() === day2) {
            return d2;
        }
        return null;
    }

    // Dernier recours : Date.parse natif (accepte ISO complet)
    var d3 = new Date(s);
    return isNaN(d3.getTime()) ? null : d3;
}

// Formate un Date en "jj/mm/aaaa"
function aiFormatDateFr(d) {
    if (!d || isNaN(d.getTime())) return '';
    return String(d.getDate()).padStart(2, '0') + '/' +
           String(d.getMonth() + 1).padStart(2, '0') + '/' +
           d.getFullYear();
}

// Formate un Date en "aaaa-mm-jj" (pour envoi serveur)
function aiFormatDateIso(d) {
    if (!d || isNaN(d.getTime())) return '';
    return d.getFullYear() + '-' +
           String(d.getMonth() + 1).padStart(2, '0') + '-' +
           String(d.getDate()).padStart(2, '0');
}

// ═══════════════════════════════════════════════════════════════
// ÉTAT
// ═══════════════════════════════════════════════════════════════
var AI = {
    step: 0,
    workbook: null,
    sheetData: [],
    headers: [],
    mapping: {},
    validRows: [],
    errorRows: [],
    fileName: '',
    totalRows: 0,
    skipFirst: true,
    lookup: { cat: {}, unite: {}, four: {}, empl: {} }
};

// Champs mappables (clés i18n)
var AI_CHAMPS = [
    { key: 'CODE',            labelKey: 'articles.import.field.code',            hintKey: 'articles.import.field.code_hint',            required: false },
    { key: 'NOM',             labelKey: 'articles.import.field.nom',             hintKey: 'articles.import.field.nom_hint',             required: true  },
    { key: 'CODE_BARRE',      labelKey: 'articles.import.field.code_barre',      hintKey: null,                                         required: false },
    { key: 'DESCRIPTION',     labelKey: 'articles.import.field.description',     hintKey: null,                                         required: false },
    { key: 'CATEGORIE',       labelKey: 'articles.import.field.categorie',       hintKey: 'articles.import.field.categorie_hint',       required: false },
    { key: 'UNITE',           labelKey: 'articles.import.field.unite',           hintKey: 'articles.import.field.unite_hint',           required: true  },
    { key: 'FOURNISSEUR',     labelKey: 'articles.import.field.fournisseur',     hintKey: 'articles.import.field.fournisseur_hint',     required: false },
    { key: 'EMPLACEMENT',     labelKey: 'articles.import.field.emplacement',     hintKey: 'articles.import.field.emplacement_hint',     required: false },
    { key: 'SEUIL_ALERTE',    labelKey: 'articles.import.field.seuil_alerte',    hintKey: 'articles.import.field.seuil_alerte_hint',    required: false },
    { key: 'POIDS',           labelKey: 'articles.import.field.poids',           hintKey: null,                                         required: false },
    { key: 'VOLUME',          labelKey: 'articles.import.field.volume',          hintKey: null,                                         required: false },
    { key: 'ACTIVE',          labelKey: 'articles.import.field.active',          hintKey: 'articles.import.field.active_hint',          required: false },
    { key: 'EST_SERVICE',     labelKey: 'articles.import.field.service',         hintKey: 'articles.import.field.service_hint',         required: false },
    { key: 'EST_PERISSABLE',  labelKey: 'articles.import.field.perissable',      hintKey: 'articles.import.field.perissable_hint',      required: false },
    { key: 'DATE_PEREMPTION', labelKey: 'articles.import.field.date_peremption', hintKey: 'articles.import.field.date_peremption_hint', required: false }
];

var AI_ALIASES = {
    'CODE':            ['code', 'code article', 'reference', 'ref', 'sku'],
    'NOM':             ['nom', 'designation', 'libelle', 'name', 'article', 'produit'],
    'CODE_BARRE':      ['code barre', 'codebarre', 'ean', 'barcode', 'code barres'],
    'DESCRIPTION':     ['description', 'desc', 'commentaire'],
    'CATEGORIE':       ['categorie', 'category', 'famille', 'type'],
    'UNITE':           ['unite', 'unite mesure', 'unite de mesure', 'unit', 'um', 'uom'],
    'FOURNISSEUR':     ['fournisseur', 'supplier', 'vendor', 'prestataire'],
    'EMPLACEMENT':     ['emplacement', 'location', 'entrepot', 'depot', 'magasin'],
    'SEUIL_ALERTE':    ['seuil alerte', 'seuil', 'alerte', 'seuil alert', 'seuil d alerte'],
    'POIDS':           ['poids', 'weight', 'masse'],
    'VOLUME':          ['volume', 'vol'],
    'ACTIVE':          ['actif', 'active', 'en service', 'statut'],
    'EST_SERVICE':     ['est service', 'service'],
    'EST_PERISSABLE':  ['est perissable', 'perissable', 'perishable', 'fragile'],
    'DATE_PEREMPTION': ['date peremption', 'peremption', 'expiration', 'date expiration', 'expiry']
};

function _aiLabel(c) { return _t(c.labelKey); }
function _aiHint(c)  { return c.hintKey ? _t(c.hintKey) : ''; }

// ═══════════════════════════════════════════════════════════════
// OUVERTURE / FERMETURE
// ═══════════════════════════════════════════════════════════════
function openImportModal(e) {
    if (e) { e.preventDefault(); e.stopPropagation(); }
    resetImportState();
    buildLookupsFromState();
    aiGoStep(1);
    document.getElementById('modalImport').style.display = 'flex';
}

function closeImportModal() {
    document.getElementById('modalImport').style.display = 'none';
}

function resetImportState() {
    AI.step = 0;
    AI.workbook = null;
    AI.sheetData = [];
    AI.headers = [];
    AI.mapping = {};
    AI.validRows = [];
    AI.errorRows = [];
    AI.fileName = '';
    AI.totalRows = 0;

    var input = document.getElementById('ai-file-input');
    if (input) input.value = '';

    var nameEl = document.getElementById('ai-file-name');
    if (nameEl) nameEl.textContent = _t('articles.import.file.none');

    var stEl = document.getElementById('ai-file-status');
    if (stEl) { stEl.textContent = ''; stEl.style.color = ''; }

    var colsEl = document.getElementById('ai-columns-preview');
    if (colsEl) { colsEl.innerHTML = ''; colsEl.style.display = 'none'; }

    ['ai-mapping-body', 'ai-preview-stats', 'ai-preview-table', 'ai-result-body'].forEach(function (id) {
        var el = document.getElementById(id);
        if (el) el.innerHTML = '';
    });
}

// ═══════════════════════════════════════════════════════════════
// LOOKUPS
// ═══════════════════════════════════════════════════════════════
function aiNormalize(v) {
    return String(v == null ? '' : v)
        .toLowerCase()
        .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();
}

function buildLookupsFromState() {
    AI.lookup = { cat: {}, unite: {}, four: {}, empl: {} };
    if (typeof AppState === 'undefined') return;

    (AppState.categories || []).forEach(function (c) {
        if (!c || !c.ID) return;
        if (c.NOM) AI.lookup.cat[aiNormalize(c.NOM)] = c.ID;
        if (c.CODE) AI.lookup.cat[aiNormalize(c.CODE)] = c.ID;
    });
    (AppState.unites || []).forEach(function (u) {
        if (!u || !u.ID) return;
        if (u.NOM) AI.lookup.unite[aiNormalize(u.NOM)] = u.ID;
        if (u.CODE) AI.lookup.unite[aiNormalize(u.CODE)] = u.ID;
    });
    (AppState.fournisseurs || []).forEach(function (f) {
        if (!f || !f.ID) return;
        if (f.NOM) AI.lookup.four[aiNormalize(f.NOM)] = f.ID;
        if (f.CODE) AI.lookup.four[aiNormalize(f.CODE)] = f.ID;
    });
    (AppState.emplacements || []).forEach(function (e) {
        if (!e || !e.ID) return;
        if (e.NOM) AI.lookup.empl[aiNormalize(e.NOM)] = e.ID;
        if (e.CODE) AI.lookup.empl[aiNormalize(e.CODE)] = e.ID;
    });
}

// ═══════════════════════════════════════════════════════════════
// NAVIGATION WIZARD
// ═══════════════════════════════════════════════════════════════
function aiGoStep(n) {
    AI.step = n;
    for (var i = 1; i <= 4; i++) {
        var stepEl  = document.getElementById('ai-step-' + i);
        var panelEl = document.getElementById('ai-panel-' + i);
        if (stepEl) {
            stepEl.className = 'ai-step' + (i < n ? ' done' : i === n ? ' active' : '');
        }
        if (panelEl) panelEl.style.display = (i === n) ? 'block' : 'none';
    }

    var prev = document.getElementById('ai-btn-prev');
    var next = document.getElementById('ai-btn-next');
    var launch = document.getElementById('ai-btn-launch');
    if (prev)   prev.style.display   = (n > 1 && n < 4) ? 'inline-block' : 'none';
    if (next)   next.style.display   = (n < 4) ? 'inline-block' : 'none';
    if (launch) launch.style.display = (n === 4 && AI.validRows.length > 0) ? 'inline-block' : 'none';

    if (n === 2) aiRenderMapping();
    if (n === 3) aiRenderPreview();
    if (n === 4) aiRenderConfirmation();

    aiUpdateNextButtonState();
}

function aiUpdateNextButtonState() {
    var next = document.getElementById('ai-btn-next');
    if (!next) return;

    var isValidationStep = (AI.step === 3);
    var hasErrors        = (AI.errorRows.length > 0);
    var hasValidRows     = (AI.validRows.length > 0);

    if (isValidationStep) {
        next.innerHTML = _t('articles.import.btn.validate') + ' <i class="fas fa-check"></i>';
        if (hasErrors || !hasValidRows) {
            next.disabled = true;
            next.setAttribute('aria-disabled', 'true');
            next.title = hasErrors
                ? _t('articles.import.error.blocked_text', { n: AI.errorRows.length })
                : _t('articles.import.error.no_valid');
            next.style.opacity = '0.45';
            next.style.cursor = 'not-allowed';
            next.style.pointerEvents = 'auto';
        } else {
            next.disabled = false;
            next.removeAttribute('aria-disabled');
            next.title = _t('articles.import.all_valid.hint');
            next.style.opacity = '1';
            next.style.cursor = 'pointer';
        }
    } else {
        next.innerHTML = _t('articles.import.btn.next') + ' <i class="fas fa-arrow-right"></i>';
        next.disabled = false;
        next.removeAttribute('aria-disabled');
        next.title = '';
        next.style.opacity = '1';
        next.style.cursor = 'pointer';
    }
}

function aiNextStep() {
    if (AI.step === 1 && !AI.workbook) {
        Swal.fire(_t('message.warning'), _t('articles.import.error.no_file'), 'warning');
        return;
    }
    if (AI.step === 2 && !aiValidateMapping()) return;

    if (AI.step === 3) {
        if (AI.errorRows.length > 0) {
            Swal.fire({
                icon: 'error',
                title: _t('articles.import.error.blocked_title'),
                html: '<div style="text-align:left;">' +
                        '<p style="margin:0 0 10px;"><strong>' +
                            _t('articles.import.error.blocked_text', { n: AI.errorRows.length }) +
                        '</strong></p>' +
                        '<p style="margin:0;">' +
                            _t('articles.import.error.blocked_hint') +
                        '</p>' +
                      '</div>',
                confirmButtonText: _t('articles.import.understand')
            });
            return;
        }

        if (AI.validRows.length === 0) {
            Swal.fire(
                _t('articles.import.error.no_valid'),
                _t('articles.import.error.empty'),
                'error');
            return;
        }

        var totalRows = AI.validRows.length + AI.errorRows.length;
        if (totalRows === 0 || AI.validRows.length !== totalRows) {
            Swal.fire(
                _t('articles.import.error.blocked_title'),
                _t('articles.import.all_valid.hint'),
                'error');
            return;
        }
    }

    if (AI.step < 4) aiGoStep(AI.step + 1);
}

function aiPrevStep() {
    if (AI.step > 1) aiGoStep(AI.step - 1);
}

// ═══════════════════════════════════════════════════════════════
// ÉTAPE 1 — DROP / LECTURE
// ═══════════════════════════════════════════════════════════════
function initAiDragDrop() {
    var zone = document.getElementById('ai-dropzone');
    var input = document.getElementById('ai-file-input');
    if (!zone || !input) return;

    zone.addEventListener('dragover', function (e) { e.preventDefault(); zone.classList.add('drag-over'); });
    zone.addEventListener('dragleave', function () { zone.classList.remove('drag-over'); });
    zone.addEventListener('drop', function (e) {
        e.preventDefault();
        zone.classList.remove('drag-over');
        if (e.dataTransfer.files[0]) aiProcessFile(e.dataTransfer.files[0]);
    });
    input.addEventListener('change', function () {
        if (this.files[0]) aiProcessFile(this.files[0]);
    });
}

function aiProcessFile(file) {
    var ext = file.name.split('.').pop().toLowerCase();
    if (ext !== 'xlsx' && ext !== 'xls') {
        Swal.fire(_t('message.warning'), _t('articles.import.error.format'), 'error');
        return;
    }

    AI.fileName = file.name;
    AI.workbook = null;
    AI.sheetData = [];
    AI.headers = [];

    document.getElementById('ai-file-name').textContent = file.name;
    var stEl = document.getElementById('ai-file-status');
    stEl.innerHTML = '<i class="fas fa-spinner fa-spin"></i> ' + _t('articles.import.file.reading');
    stEl.style.color = '#007bff';

    var reader = new FileReader();
    reader.onload = function (e) {
        try {
            var data = new Uint8Array(e.target.result);
            // cellDates: true → SheetJS retourne des Date JS quand la cellule est au format date
            var wb = XLSX.read(data, { type: 'array', cellDates: true });
            AI.workbook = wb;
            var sheetName = wb.SheetNames[0];
            var ws = wb.Sheets[sheetName];
            var json = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '', raw: true });

            if (!json || json.length < 2) throw new Error(_t('articles.import.error.empty'));

            AI.headers = json[0].map(function (h) { return String(h || '').trim(); });
            AI.sheetData = json.slice(1);
            AI.totalRows = AI.sheetData.filter(function (r) {
                return r.some(function (c) {
                    if (c instanceof Date) return true;
                    return String(c == null ? '' : c).trim() !== '';
                });
            }).length;

            aiAutoMap();

            stEl.innerHTML = '<i class="fas fa-check-circle"></i> ' +
                _t('articles.import.file.lines', { n: AI.totalRows, sheet: sheetName });
            stEl.style.color = '#28a745';

            aiRenderColumnsPreview();
        } catch (err) {
            stEl.innerHTML = '<i class="fas fa-exclamation-triangle"></i> ' + err.message;
            stEl.style.color = '#dc3545';
            AI.workbook = null;
        }
    };
    reader.readAsArrayBuffer(file);
}

function aiAutoMap() {
    AI.mapping = {};
    AI.headers.forEach(function (h, idx) {
        var norm = aiNormalize(h);
        Object.keys(AI_ALIASES).forEach(function (key) {
            if (AI.mapping[key] !== undefined) return;
            var matched = AI_ALIASES[key].some(function (a) { return aiNormalize(a) === norm; });
            if (matched) AI.mapping[key] = idx;
        });
    });
}

function aiRenderColumnsPreview() {
    var el = document.getElementById('ai-columns-preview');
    if (!el || !AI.headers.length) return;
    el.innerHTML = AI.headers.map(function (h, i) {
        return '<span class="col-badge"><strong>' +
            String.fromCharCode(65 + (i % 26)) + '</strong> ' + aiEsc(h) + '</span>';
    }).join('');
    el.style.display = 'flex';
}

// ═══════════════════════════════════════════════════════════════
// ÉTAPE 2 — MAPPING
// ═══════════════════════════════════════════════════════════════
function aiRenderMapping() {
    var tbody = document.getElementById('ai-mapping-body');
    if (!tbody) return;
    var frag = document.createDocumentFragment();

    AI_CHAMPS.forEach(function (c) {
        var sel = AI.mapping[c.key];
        var selectedIdx = sel !== undefined ? sel : '';

        var tr = document.createElement('tr');

        var td1 = document.createElement('td');
        var hint = _aiHint(c);
        td1.innerHTML = '<span class="champ-label' + (c.required ? ' required' : '') + '">' +
            aiEsc(_aiLabel(c)) + '</span>' +
            (hint ? '<small class="champ-hint">' + aiEsc(hint) + '</small>' : '');

        var td2 = document.createElement('td');
        var s = document.createElement('select');
        s.className = 'form-control mapping-select';
        s.setAttribute('data-field', c.key);
        var optIgn = document.createElement('option');
        optIgn.value = ''; optIgn.textContent = _t('articles.import.mapping.ignore');
        s.appendChild(optIgn);
        AI.headers.forEach(function (h, i) {
            var o = document.createElement('option');
            o.value = i; o.textContent = String.fromCharCode(65 + (i % 26)) + ' — ' + h;
            if (String(selectedIdx) === String(i)) o.selected = true;
            s.appendChild(o);
        });
        s.addEventListener('change', function () { aiOnMappingChange(this); });
        td2.appendChild(s);

        var td3 = document.createElement('td');
        td3.className = 'preview-cell';
        td3.id = 'ai-preview-' + c.key;
        var pv = '';
        if (selectedIdx !== '' && AI.sheetData.length > 0) {
            var raw = AI.sheetData[0][selectedIdx];
            if (c.key === 'DATE_PEREMPTION') {
                var d = aiParseDate(raw);
                pv = d ? aiFormatDateFr(d) : String(raw == null ? '' : raw);
            } else if (raw instanceof Date) {
                pv = aiFormatDateFr(raw);
            } else {
                pv = String(raw == null ? '' : raw);
            }
        }
        td3.innerHTML = pv ? '<span class="preview-val">' + aiEsc(pv) + '</span>' : '';

        tr.appendChild(td1); tr.appendChild(td2); tr.appendChild(td3);
        frag.appendChild(tr);
    });

    tbody.innerHTML = '';
    tbody.appendChild(frag);
}

function aiOnMappingChange(sel) {
    var field = sel.getAttribute('data-field');
    var idx = sel.value !== '' ? parseInt(sel.value, 10) : undefined;
    AI.mapping[field] = idx;
    var cell = document.getElementById('ai-preview-' + field);
    if (!cell) return;

    var v = '';
    if (idx !== undefined && AI.sheetData.length) {
        var raw = AI.sheetData[0][idx];
        if (field === 'DATE_PEREMPTION') {
            var d = aiParseDate(raw);
            v = d ? aiFormatDateFr(d) : String(raw == null ? '' : raw);
        } else if (raw instanceof Date) {
            v = aiFormatDateFr(raw);
        } else {
            v = String(raw == null ? '' : raw);
        }
    }
    cell.innerHTML = v ? '<span class="preview-val">' + aiEsc(v) + '</span>' : '';
}

function aiValidateMapping() {
    var missing = AI_CHAMPS.filter(function (c) {
        return c.required && AI.mapping[c.key] === undefined;
    }).map(function (c) { return _aiLabel(c); });
    if (missing.length) {
        Swal.fire(
            _t('articles.import.error.blocked_title'),
            _t('articles.import.error.mapping', { fields: missing.join(', ') }),
            'warning');
        return false;
    }
    return true;
}

// ═══════════════════════════════════════════════════════════════
// ÉTAPE 3 — APERÇU / VALIDATION
// ═══════════════════════════════════════════════════════════════
function aiRenderPreview() {
    aiValidateAllRows();

    var stats = document.getElementById('ai-preview-stats');
    stats.innerHTML =
        '<div class="stat ok"><i class="fas fa-check-circle"></i> ' +
        '<strong>' + AI.validRows.length + '</strong> ' + _t('articles.import.stats.valid') + '</div>' +
        '<div class="stat err"><i class="fas fa-exclamation-triangle"></i> ' +
        '<strong>' + AI.errorRows.length + '</strong> ' + _t('articles.import.stats.errors') + '</div>' +
        '<div class="stat total"><i class="fas fa-table"></i> ' +
        '<strong>' + (AI.validRows.length + AI.errorRows.length) + '</strong> ' + _t('articles.import.stats.total') + '</div>';

    var panel = document.getElementById('ai-panel-3');
    var warnEl = document.getElementById('ai-preview-warning');
    if (!warnEl && panel) {
        warnEl = document.createElement('div');
        warnEl.id = 'ai-preview-warning';
        var statsEl = document.getElementById('ai-preview-stats');
        if (statsEl && statsEl.parentNode === panel) {
            panel.insertBefore(warnEl, statsEl.nextSibling);
        } else {
            panel.insertBefore(warnEl, panel.firstChild);
        }
    }

    if (warnEl) {
        if (AI.errorRows.length > 0) {
            warnEl.className = 'ai-alert-block';
            warnEl.innerHTML =
                '<i class="fas fa-exclamation-triangle"></i> ' +
                '<div><strong>' + aiEsc(_t('articles.import.alert.title')) + '</strong> — ' +
                aiEsc(_t('articles.import.alert.text', { n: AI.errorRows.length })) + '<br>' +
                '<span style="font-size:12.5px;opacity:.9;">' +
                aiEsc(_t('articles.import.alert.hint')) +
                '</span></div>';
            warnEl.style.display = 'flex';
        } else if (AI.validRows.length > 0) {
            warnEl.className = 'ai-success-msg';
            warnEl.innerHTML =
                '<i class="fas fa-check-circle"></i> ' +
                '<strong>' + aiEsc(_t('articles.import.all_valid.title')) + '</strong> ' +
                aiEsc(_t('articles.import.all_valid.hint'));
            warnEl.style.display = 'block';
        } else {
            warnEl.innerHTML = '';
            warnEl.style.display = 'none';
        }
    }

    aiRenderPreviewTable();
    aiUpdateNextButtonState();
}

function aiExtractRow(row) {
    var obj = {};
    AI_CHAMPS.forEach(function (c) {
        if (AI.mapping[c.key] === undefined) return;
        var val = row[AI.mapping[c.key]];
        if (val instanceof Date) {
            val = aiFormatDateIso(val);
        }
        obj[c.key] = String(val == null ? '' : val).trim();
    });
    return obj;
}

function aiParseBool(v) {
    if (v === undefined || v === null || v === '') return null;
    var s = String(v).trim().toLowerCase();
    if (['o', 'oui', 'y', 'yes', '1', 'true', 'vrai', 'actif', 'eny', 'e'].indexOf(s) !== -1) return true;
    if (['n', 'non', 'no', '0', 'false', 'faux', 'inactif', 'tsia', 't'].indexOf(s) !== -1) return false;
    return null;
}

function aiParseNumber(v) {
    if (v === undefined || v === null || v === '') return null;
    var n = parseFloat(String(v).replace(',', '.').replace(/\s/g, ''));
    return isNaN(n) ? null : n;
}

function aiValidateAllRows() {
    AI.validRows = [];
    AI.errorRows = [];
    var seenCodes = {};

    AI.sheetData.forEach(function (row, idx) {
        if (!row.some(function (c) {
            if (c instanceof Date) return true;
            return String(c == null ? '' : c).trim() !== '';
        })) return;

        var obj = aiExtractRow(row);
        var errors = [];

        AI_CHAMPS.forEach(function (c) {
            if (c.required && (!obj[c.key] || String(obj[c.key]).trim() === '')) {
                errors.push(_t('articles.import.error.field_missing', { field: _aiLabel(c) }));
            }
        });

        function resolveFK(labelKey, value, map) {
            if (!value) return null;
            var key = aiNormalize(value);
            if (!map[key]) {
                errors.push(_t('articles.import.error.field_not_found', {
                    field: _t(labelKey), value: value
                }));
                return null;
            }
            return map[key];
        }
        obj.CATEGORIE_ID          = resolveFK('articles.import.field.categorie',   obj.CATEGORIE,   AI.lookup.cat);
        obj.UNITE_MESURE_ID       = resolveFK('articles.import.field.unite',       obj.UNITE,       AI.lookup.unite);
        obj.FOURNISSEUR_PREFERE_ID= resolveFK('articles.import.field.fournisseur', obj.FOURNISSEUR, AI.lookup.four);
        obj.EMPLACEMENT_ID        = resolveFK('articles.import.field.emplacement', obj.EMPLACEMENT, AI.lookup.empl);

        ['SEUIL_ALERTE', 'POIDS', 'VOLUME'].forEach(function (k) {
            var n = aiParseNumber(obj[k]);
            if (obj[k] && n === null) {
                errors.push(_t('articles.import.error.number_invalid', { field: k, value: obj[k] }));
            }
            obj[k] = n === null ? 0 : n;
        });

        ['ACTIVE','EST_SERVICE','EST_PERISSABLE'].forEach(function (k) {
            if (obj[k] === undefined || obj[k] === '') {
                obj[k] = (k === 'ACTIVE');
            } else {
                var b = aiParseBool(obj[k]);
                if (b === null) {
                    errors.push(_t('articles.import.error.bool_invalid', { field: k, value: obj[k] }));
                }
                obj[k] = b === null ? (k === 'ACTIVE') : b;
            }
        });

        // ═══ Normalisation DATE_PEREMPTION (jj/mm/aaaa ou ISO) ═══
        obj._datePeremptionDisplay = '';
        if (obj.DATE_PEREMPTION) {
            var dPer = aiParseDate(obj.DATE_PEREMPTION);
            if (!dPer) {
                errors.push(_t('articles.msg.date_peremption_invalid') +
                    ' ("' + obj.DATE_PEREMPTION + '")');
                obj.DATE_PEREMPTION = null;
            } else {
                obj._datePeremptionDisplay = aiFormatDateFr(dPer);  // affichage jj/mm/aaaa
                obj.DATE_PEREMPTION = aiFormatDateIso(dPer);        // envoi serveur ISO
            }
        } else {
            obj.DATE_PEREMPTION = null;
        }

        // ═══ COHÉRENCE PÉRISSABLE ↔ DATE DE PÉREMEPTION ═══
        if (!obj.EST_PERISSABLE && obj.DATE_PEREMPTION) {
            errors.push(_t('articles.msg.date_peremption_forbidden'));
        }
        if (obj.EST_PERISSABLE && !obj.DATE_PEREMPTION) {
            errors.push(_t('articles.msg.date_peremption_required'));
        }

        // ─── Détection doublons de CODE dans le fichier ───
        if (obj.CODE) {
            var key = obj.CODE.toUpperCase();
            if (seenCodes[key]) {
                errors.push(_t('articles.import.error.duplicate_code', { code: obj.CODE }));
            }
            else seenCodes[key] = true;
        }

        obj._ligne = idx + 2;
        obj._errors = errors;

        (errors.length ? AI.errorRows : AI.validRows).push(obj);
    });
}

function aiRenderPreviewTable() {
    var container = document.getElementById('ai-preview-table');
    if (!container) return;
    var allRows = AI.validRows.concat(AI.errorRows).sort(function (a, b) { return a._ligne - b._ligne; });
    if (!allRows.length) {
        container.innerHTML = '<p style="text-align:center;color:#888;padding:20px;">' +
            _t('message.no_data') + '</p>';
        return;
    }

    var visible = AI_CHAMPS.filter(function (c) {
        return c.key === 'CODE' || c.key === 'NOM' || c.key === 'CATEGORIE' ||
               c.key === 'UNITE' || c.key === 'FOURNISSEUR' || c.key === 'EMPLACEMENT' ||
               c.key === 'SEUIL_ALERTE' || c.key === 'EST_PERISSABLE' || c.key === 'DATE_PEREMPTION';
    });

    var table = document.createElement('table');
    table.className = 'ai-table';
    var thead = document.createElement('thead');
    var trH = document.createElement('tr');
    var thL = document.createElement('th'); thL.textContent = '#'; trH.appendChild(thL);
    visible.forEach(function (c) {
        var th = document.createElement('th');
        th.textContent = _aiLabel(c);
        trH.appendChild(th);
    });
    var thS = document.createElement('th');
    thS.textContent = _t('articles.import.col.check');
    trH.appendChild(thS);
    thead.appendChild(trH); table.appendChild(thead);

    var tbody = document.createElement('tbody');
    allRows.forEach(function (row) {
        var isValid = row._errors.length === 0;
        var tr = document.createElement('tr');
        tr.className = isValid ? 'row-valid' : 'row-error';

        var tdL = document.createElement('td'); tdL.textContent = row._ligne; tr.appendChild(tdL);
        visible.forEach(function (c) {
            var td = document.createElement('td');
            var val;
            if (c.key === 'EST_PERISSABLE') {
                val = row[c.key]
                    ? _t('articles.modal.perissable_yes')
                    : _t('articles.modal.perissable_no');
            } else if (c.key === 'DATE_PEREMPTION') {
                // Affiche en jj/mm/aaaa
                val = row._datePeremptionDisplay || '—';
            } else {
                val = row[c.key];
                if (val === null || val === undefined || val === '') val = '—';
            }
            td.textContent = val;
            tr.appendChild(td);
        });

        var tdS = document.createElement('td');
        if (isValid) {
            tdS.innerHTML = '<span class="badge-ok"><i class="fas fa-check"></i> ' +
                _t('articles.import.badge.ok') + '</span>';
        } else {
            var lst = row._errors.map(function (e) {
                return '<li style="margin:2px 0;font-size:0.85em;">' +
                    '<i class="fas fa-exclamation-circle" style="color:#dc3545;margin-right:4px;"></i>' +
                    aiEsc(e) + '</li>';
            }).join('');
            tdS.innerHTML = '<span class="badge-err"><strong>' +
                _t('articles.import.badge.errors', { n: row._errors.length }) + '</strong>' +
                '<ul style="margin:4px 0 0 8px;padding:0;list-style:none;">' + lst + '</ul></span>';
        }
        tr.appendChild(tdS);
        tbody.appendChild(tr);
    });
    table.appendChild(tbody);

    var wrapper = document.createElement('div');
    wrapper.className = 'ai-preview-wrapper';
    wrapper.appendChild(table);

    container.innerHTML = '';
    container.appendChild(wrapper);
}

// ═══════════════════════════════════════════════════════════════
// ÉTAPE 4 — CONFIRMATION + RÉSULTAT
// ═══════════════════════════════════════════════════════════════
function aiRenderConfirmation() {
    var c = document.getElementById('ai-result-body');
    if (!c) return;

    var html = '<div class="ai-result-summary">' +
        '<div class="res-stat ok"><i class="fas fa-check-circle"></i>' +
        '<strong>' + AI.validRows.length + '</strong><span>' +
        _t('articles.import.confirm.ready') + '</span></div>' +
        '<div class="res-stat warn"><i class="fas fa-exclamation-triangle"></i>' +
        '<strong>' + AI.errorRows.length + '</strong><span>' +
        _t('articles.import.confirm.ignored') + '</span></div>' +
        '</div>';

    if (AI.errorRows.length > 0) {
        html += '<div class="ai-section">' +
            '<h5><i class="fas fa-exclamation-circle" style="color:#dc3545;"></i> ' +
            _t('articles.import.alert.text', { n: AI.errorRows.length }) + '</h5>' +
            '<div style="overflow:auto;max-height:200px;"><table class="ai-table"><thead><tr>' +
            '<th>#</th><th>' + _t('articles.import.field.code') + '</th>' +
            '<th>' + _t('articles.import.field.nom') + '</th>' +
            '<th>' + _t('articles.import.col.check') + '</th>' +
            '</tr></thead><tbody>' +
            AI.errorRows.map(function (r) {
                return '<tr class="row-error"><td>' + r._ligne + '</td>' +
                    '<td>' + aiEsc(r.CODE || '—') + '</td>' +
                    '<td>' + aiEsc(r.NOM || '—') + '</td>' +
                    '<td style="font-size:0.85em;color:#dc3545;">' +
                    r._errors.map(function (e) { return aiEsc(e); }).join('<br>') +
                    '</td></tr>';
            }).join('') +
            '</tbody></table></div></div>';
    }

    if (!AI.validRows.length) {
        html += '<div style="text-align:center;padding:20px;color:#dc3545;">' +
            '<i class="fas fa-times-circle fa-2x"></i><br><br>' +
            '<strong>' + _t('articles.import.error.no_valid') + '</strong></div>';
    } else {
        html += '<div class="ai-success-msg">' +
            '<i class="fas fa-info-circle"></i> ' +
            _t('articles.import.confirm.info', { n: AI.validRows.length }) +
            '</div>';
    }

    html += '<div class="ai-progress" id="ai-progress" style="display:none;">' +
        '<div class="ai-progress-bar" id="ai-progress-bar"></div></div>';

    c.innerHTML = html;
}

function aiLaunchImport() {
    if (!AI.validRows.length) return;

    if (AI.errorRows.length > 0) {
        Swal.fire({
            icon: 'error',
            title: _t('articles.import.error.launch_blocked'),
            html: '<div style="text-align:left;">' +
                  '<strong>' +
                    _t('articles.import.error.launch_blocked_text', { n: AI.errorRows.length }) +
                  '</strong>' +
                  '</div>'
        });
        return;
    }

    var btn = document.getElementById('ai-btn-launch');
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> ' + _t('articles.import.progress');
    }

    var prog = document.getElementById('ai-progress');
    if (prog) prog.style.display = 'block';
    var pct = 0;
    var bar = document.getElementById('ai-progress-bar');
    var timer = setInterval(function () {
        pct = Math.min(90, pct + Math.random() * 8);
        if (bar) bar.style.width = pct + '%';
    }, 200);

    var payload = {
        articles: AI.validRows.map(function (r) {
            return {
                CODE: r.CODE || '',
                NOM: r.NOM || '',
                DESCRIPTION: r.DESCRIPTION || '',
                CODE_BARRE: r.CODE_BARRE || '',
                CATEGORIE_ID: r.CATEGORIE_ID || null,
                UNITE_MESURE_ID: r.UNITE_MESURE_ID || null,
                FOURNISSEUR_PREFERE_ID: r.FOURNISSEUR_PREFERE_ID || null,
                EMPLACEMENT_ID: r.EMPLACEMENT_ID || null,
                SEUIL_ALERTE: r.SEUIL_ALERTE || 0,
                POIDS: r.POIDS || 0,
                VOLUME: r.VOLUME || 0,
                ACTIVE: !!r.ACTIVE,
                EST_SERVICE: !!r.EST_SERVICE,
                EST_PERISSABLE: !!r.EST_PERISSABLE,
                DATE_PEREMPTION: r.DATE_PEREMPTION || null   // ← ISO yyyy-MM-dd
            };
        })
    };

    var url = API.BASE + API.HANDLERS_PATH + 'ArticlesImport.ashx';

    fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    })
    .then(function (r) {
        return r.text().then(function (txt) {
            if (!txt) throw new Error(_t('message.error'));
            try {
                var data = JSON.parse(txt);
                if (!r.ok && data.message) throw new Error(data.message);
                return data;
            } catch (e) { throw new Error(txt); }
        });
    })
    .then(function (data) {
        clearInterval(timer);
        if (bar) bar.style.width = '100%';

        var btn = document.getElementById('ai-btn-launch');
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-database"></i> ' + _t('articles.import.btn.relaunch');
        }
        aiRenderResult(data);

        if (data.success && (data.inserted + data.updated) > 0) {
            try { loadArticles(); loadStats(); } catch (e) { /* ignore */ }
        }
    })
    .catch(function (err) {
        clearInterval(timer);
        if (bar) bar.style.width = '0%';
        var btn = document.getElementById('ai-btn-launch');
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-database"></i> ' + _t('articles.import.btn.launch');
        }
        Swal.fire({
            title: _t('articles.import.result.fail'),
            html: '<div style="text-align:left;">' +
                aiEsc(err && err.message ? err.message : _t('message.error')) +
                '</div>',
            icon: 'error'
        });
    });
}

function aiRenderResult(data) {
    var c = document.getElementById('ai-result-body');
    if (!c) return;

    var inserts = data.inserted || 0;
    var updated = data.updated || 0;
    var skipped = data.skipped || 0;
    var dups = data.duplicates || [];
    var errs = data.errors || [];

    var html = '';
    if (!data.success) {
        html += '<div class="ai-section" style="border-left:4px solid #dc3545;">' +
            '<h5><i class="fas fa-exclamation-circle" style="color:#dc3545;"></i> ' +
            _t('articles.import.result.fail') + '</h5>' +
            '<div style="color:#dc3545;">' +
                aiEsc(_resolveServerMessage(data, 'message.error')) +
            '</div></div>';
    }

    html += '<div class="ai-result-summary">' +
        '<div class="res-stat ok"><i class="fas fa-check-circle"></i><strong>' + inserts + '</strong><span>' +
        _t('articles.import.result.added') + '</span></div>' +
        '<div class="res-stat warn"><i class="fas fa-sync-alt"></i><strong>' + updated + '</strong><span>' +
        _t('articles.import.result.updated') + '</span></div>' +
        '<div class="res-stat err"><i class="fas fa-exclamation-triangle"></i><strong>' + skipped + '</strong><span>' +
        _t('articles.import.result.skipped') + '</span></div>' +
        '</div>';

    if (dups.length) {
        html += '<div class="ai-section"><h5><i class="fas fa-copy"></i> ' +
            _t('articles.import.result.duplicates') + ' (' + dups.length + ')</h5>' +
            '<div style="overflow:auto;max-height:180px;"><table class="ai-table"><thead><tr>' +
            '<th>' + _t('articles.import.field.code') + '</th>' +
            '<th>' + _t('articles.import.field.nom') + '</th>' +
            '<th>' + _t('articles.import.col.check') + '</th>' +
            '</tr></thead><tbody>' +
            dups.map(function (d) {
                return '<tr class="row-error"><td>' + aiEsc(d.CODE || '') + '</td>' +
                    '<td>' + aiEsc(d.NOM || '') + '</td>' +
                    '<td>' + aiEsc(_resolveDup(d)) + '</td></tr>';
            }).join('') + '</tbody></table></div></div>';
    }

    if (errs.length) {
        html += '<div class="ai-section"><h5><i class="fas fa-times-circle"></i> ' +
            _t('articles.import.result.errors') + ' (' + errs.length + ')</h5>' +
            '<div style="overflow:auto;max-height:180px;"><table class="ai-table"><thead><tr>' +
            '<th>' + _t('articles.import.field.code') + '</th>' +
            '<th>' + _t('articles.import.col.check') + '</th>' +
            '</tr></thead><tbody>' +
            errs.map(function (e) {
                return '<tr class="row-error"><td>' + aiEsc(e.CODE || '?') + '</td>' +
                    '<td>' + aiEsc(_resolveErr(e)) + '</td></tr>';
            }).join('') + '</tbody></table></div></div>';
    }

    if (data.success && inserts + updated > 0 && !dups.length && !errs.length) {
        html += '<div class="ai-success-msg"><i class="fas fa-check-circle"></i> ' +
            _t('articles.import.result.success', { n: inserts + updated }) +
            '</div>';
    }

    c.innerHTML = html;

    var btn = document.getElementById('ai-btn-launch');
    if (btn) btn.style.display = 'none';
}

// ═══════════════════════════════════════════════════════════════
// MODÈLE EXCEL (SANS stock initial, seuil min, seuil max)
// ═══════════════════════════════════════════════════════════════
function downloadArticlesTemplate() {
    var headers = AI_CHAMPS.map(function (c) {
        return _aiLabel(c) + (c.required ? ' *' : '');
    });

    // Exemple avec un article PÉRISSABLE → date au format jj/mm/aaaa
    var sample = [
        '',                               // CODE (auto)
        'Ciment CPJ 35',                  // NOM
        '3251523000012',                  // CODE_BARRE
        'Sac de ciment 50 kg',            // DESCRIPTION
        'Matériaux',                      // CATEGORIE
        'Sac',                            // UNITE
        'Lafarge',                        // FOURNISSEUR
        'Dépôt A',                        // EMPLACEMENT
        '50',                             // SEUIL_ALERTE
        '50',                             // POIDS
        '0.05',                           // VOLUME
        'O',                              // ACTIVE
        'N',                              // EST_SERVICE
        'O',                              // EST_PERISSABLE
        '31/12/2027'                      // DATE_PEREMPTION (jj/mm/aaaa)
    ];

    var ws = XLSX.utils.aoa_to_sheet([headers, sample]);
    ws['!cols'] = headers.map(function () { return { wch: 22 }; });

    // Force le format date FR sur la colonne DATE_PEREMPTION (dernière)
    var dateColIdx = AI_CHAMPS.findIndex(function (c) { return c.key === 'DATE_PEREMPTION'; });
    if (dateColIdx >= 0) {
        var colLetter = XLSX.utils.encode_col(dateColIdx);
        var cellRef = colLetter + '2'; // ligne 1 = header, ligne 2 = exemple
        if (ws[cellRef]) {
            ws[cellRef].z = 'DD/MM/YYYY';
        }
    }

    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Articles');
    XLSX.writeFile(wb, 'Modele_Import_Articles.xlsx');
}

// ═══════════════════════════════════════════════════════════════
// UTILITAIRES
// ═══════════════════════════════════════════════════════════════
function aiEsc(s) {
    return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// ═══════════════════════════════════════════════════════════════
// INIT AU CHARGEMENT DE LA PAGE
// ═══════════════════════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', function () {
    initAiDragDrop();
});

// ═══════════════════════════════════════════════════════════════
// EXPOSITIONS GLOBALES
// ═══════════════════════════════════════════════════════════════
window.openImportModal          = openImportModal;
window.closeImportModal         = closeImportModal;
window.aiNextStep               = aiNextStep;
window.aiPrevStep               = aiPrevStep;
window.aiLaunchImport           = aiLaunchImport;
window.downloadArticlesTemplate = downloadArticlesTemplate;
window.aiUpdateNextButtonState  = aiUpdateNextButtonState;
window.aiParseDate              = aiParseDate;
window.aiFormatDateFr           = aiFormatDateFr;
window.aiFormatDateIso          = aiFormatDateIso;
