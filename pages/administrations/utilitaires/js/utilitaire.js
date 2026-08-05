/**
 * utilitaire.js — Importation Excel des élèves
 * ─────────────────────────────────────────────
 * Étape 1 : Dépôt du fichier Excel (drag & drop ou parcourir)
 * Étape 2 : Mappage colonnes Excel ↔ champs SQL
 * Étape 3 : Validation + aperçu des données
 * Étape 4 : Modal résultat (anomalies / intégration définitive)
 *
 * Dépendances : SheetJS (XLSX), SweetAlert2, FontAwesome
 *
 * CORRECTIONS v2 :
 *  - CLASSE_ID envoyé en INT (plus de nom texte dans le payload)
 *  - ID élève = GUID généré côté serveur (NEWID()), non envoyé depuis le JS
 *  - STATUT dans le payload = valeur texte propre ('actif') et non du HTML
 *  - Affichage complet et détaillé de TOUTES les erreurs dans le tableau
 *  - Correction bug alias 'STATUS' → 'STATUS' (clé manquant un S corrigée)
 *  - Performance : DocumentFragment pour le rendu des tableaux
 *  - Validation CLASSE : comparaison insensible à la casse + fallback sur ID/Id/id
 *  - Format réponse serveur aligné avec renderResultModal (inserted/skipped/duplicates/errors)
 */

'use strict';

// ═══════════════════════════════════════════════════════════════
// ÉTAT GLOBAL
// ═══════════════════════════════════════════════════════════════
var IMP = {
    step: 0,
    workbook: null,
    sheetData: [],     // toutes les lignes brutes
    headers: [],     // en-têtes détectées
    mapping: {},     // { champSQL: indexColonne (0-based) }
    validRows: [],
    errorRows: [],
    classesList: [],
    fileName: '',
    totalRows: 0,
    skipFirst: true
};

// Champs SQL avec règles de validation
var CHAMPS = [
    { key: 'MATRICULE', label: 'Matricule', required: true, type: 'text', hint: 'Ex: 2024001' },
    { key: 'ANNEE_SCO', label: 'Année Scolaire', required: true, type: 'text', hint: 'Ex: 1' },
    { key: 'NOM', label: 'Nom complet', required: true, type: 'text', hint: 'Ex: RAKOTO Jean' },
    { key: 'CLASSE', label: 'Classe', required: true, type: 'int', hint: 'Ex: 1' },
    { key: 'EMAIL', label: 'Email', required: false, type: 'email', hint: 'Ex: nom@mail.com' },
    { key: 'TELEPHONE', label: 'Téléphone', required: false, type: 'text', hint: 'Ex: 034 12 345 67' },
    { key: 'DATE_NAISS', label: 'Date de naissance', required: false, type: 'date', hint: 'Ex: 2010-05-15' },
    { key: 'GENRE', label: 'Genre (M/F)', required: false, type: 'genre', hint: 'M ou F' },
    { key: 'ADRESSE', label: 'Adresse', required: false, type: 'text', hint: '' },
    { key: 'PARENT', label: 'Parent / Tuteur', required: false, type: 'text', hint: '' },
    { key: 'STATUS', label: 'Status', required: false, type: 'text', hint: 'Ex: actif' }
];

// ═══════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', function () {
    chargerClassesPourImport();
    goStep(1);
    initDragDrop();
});

// ─────────────────────────────────────────────
// NAVIGATION ENTRE ÉTAPES
// ─────────────────────────────────────────────
function goStep(n) {
    IMP.step = n;

    for (var i = 1; i <= 4; i++) {
        var stepEl = document.getElementById('imp-step-' + i);
        var panelEl = document.getElementById('imp-panel-' + i);

        if (stepEl) {
            stepEl.className = 'imp-step' +
                (i < n ? ' done' : i === n ? ' active' : '');
        }
        if (panelEl) {
            panelEl.style.display = (i === n) ? 'block' : 'none';
        }
    }

    var btnPrev = document.getElementById('imp-btn-prev');
    var btnNext = document.getElementById('imp-btn-next');
    var btnLaunch = document.getElementById('imp-btn-launch');

    if (btnPrev) btnPrev.style.display = (n > 1 && n < 4) ? 'inline-flex' : 'none';
    if (btnNext) btnNext.style.display = (n < 4) ? 'inline-flex' : 'none';
    if (btnLaunch) btnLaunch.style.display = 'none'; // Bouton intégrer est dans le panel étape 4

    if (n === 2 && IMP.headers.length) renderMappingTable();
    if (n === 3) renderPreview();
    if (n === 4) renderConfirmationStep();
}

function nextStep() {
    if (IMP.step === 1 && !IMP.workbook) {
        Swal.fire('Attention', 'Veuillez sélectionner un fichier Excel avant de continuer.', 'warning');
        return;
    }
    if (IMP.step === 2 && !validateMapping()) return;
    if (IMP.step === 3 && !IMP.validRows.length) {
        Swal.fire('Aucune ligne valide', 'Toutes les lignes contiennent des anomalies. Corrigez le fichier et recommencez.', 'error');
        return;
    }
    if (IMP.step < 4) goStep(IMP.step + 1);
}

function prevStep() {
    if (IMP.step > 1) goStep(IMP.step - 1);
}

// ═══════════════════════════════════════════════════════════════
// ÉTAPE 1 — DÉPÔT DU FICHIER
// ═══════════════════════════════════════════════════════════════
function initDragDrop() {
    var zone = document.getElementById('imp-dropzone');
    if (!zone) return;

    zone.addEventListener('dragover', function (e) {
        e.preventDefault();
        zone.classList.add('drag-over');
    });
    zone.addEventListener('dragleave', function () {
        zone.classList.remove('drag-over');
    });
    zone.addEventListener('drop', function (e) {
        e.preventDefault();
        zone.classList.remove('drag-over');
        var file = e.dataTransfer.files[0];
        if (file) processFile(file);
    });

    var fileInput = document.getElementById('imp-file-input');
    if (fileInput) {
        fileInput.addEventListener('change', function () {
            if (this.files[0]) processFile(this.files[0]);
        });
    }
}

function processFile(file) {
    var ext = file.name.split('.').pop().toLowerCase();
    if (ext !== 'xlsx' && ext !== 'xls') {
        Swal.fire('Format invalide', 'Veuillez choisir un fichier .xlsx ou .xls', 'error');
        return;
    }

    IMP.fileName = file.name;
    IMP.workbook = null;
    IMP.sheetData = [];
    IMP.headers = [];

    var nameEl = document.getElementById('imp-file-name');
    if (nameEl) nameEl.textContent = file.name;

    var statusEl = document.getElementById('imp-file-status');
    if (statusEl) {
        statusEl.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Lecture en cours...';
        statusEl.style.color = '#007bff';
    }

    var reader = new FileReader();
    reader.onload = function (e) {
        try {
            var data = new Uint8Array(e.target.result);
            var wb = XLSX.read(data, { type: 'array', cellDates: true });
            IMP.workbook = wb;

            var sheetName = wb.SheetNames[0];
            var ws = wb.Sheets[sheetName];
            var json = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });

            if (!json || json.length < 2) {
                throw new Error('Le fichier semble vide ou ne contient pas de données.');
            }

            IMP.headers = json[0].map(function (h) { return String(h || '').trim(); });
            IMP.sheetData = json.slice(1);
            IMP.totalRows = IMP.sheetData.filter(function (r) {
                return r.some(function (c) { return String(c).trim() !== ''; });
            }).length;

            autoMapColumns();

            if (statusEl) {
                statusEl.innerHTML = '<i class="fas fa-check-circle"></i> ' +
                    IMP.totalRows + ' ligne(s) détectée(s) — Feuille : « ' + sheetName + ' »';
                statusEl.style.color = '#28a745';
            }

            renderColumnsPreview();

        } catch (err) {
            if (statusEl) {
                statusEl.innerHTML = '<i class="fas fa-exclamation-triangle"></i> ' + err.message;
                statusEl.style.color = '#dc3545';
            }
            IMP.workbook = null;
        }
    };
    reader.readAsArrayBuffer(file);
}

function normalizeHeader(value) {
    return String(value == null ? '' : value)
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();
}

function autoMapColumns() {
    var aliases = {
        'MATRICULE': ['matricule', 'num', 'numero', 'id eleve', 'id élève', 'num eleve', 'num élève'],
        'ANNEE_SCO': ['annee', 'annee sco', 'annee scolaire', 'année scolaire', 'annee_sco', 'annee scolaire', 'annee id', 'année id', 'annee_id', 'annee id'],
        'NOM': ['nom', 'nom complet', 'nom et prénom', 'eleve', 'élève', 'name', 'prénom nom'],
        'CLASSE': ['classe', 'class', 'groupe', 'classe nom', 'classe (nom)', 'classe id', 'id classe', 'classeid', 'idclasse'],
        'EMAIL': ['email', 'mail', 'courriel', 'e mail', 'e-mail'],
        'TELEPHONE': ['telephone', 'téléphone', 'tel', 'tél', 'phone', 'mobile'],
        'DATE_NAISS': ['date de naissance', 'date naissance', 'date_naissance', 'datenaissance', 'ddn', 'naissance', 'birthdate'],
        'GENRE': ['genre', 'sexe', 'sex', 'gender', 'genre m f'],
        'ADRESSE': ['adresse', 'address', 'adresse complete'],
        'PARENT': ['parent', 'tuteur', 'père', 'mère', 'responsable', 'parent tuteur'],
        'STATUS': ['statut', 'stat', 'status', 'etat', 'état']
    };

    IMP.mapping = {};
    IMP.headers.forEach(function (h, idx) {
        var normalizedHeader = normalizeHeader(h);
        Object.keys(aliases).forEach(function (key) {
            if (IMP.mapping[key] === undefined) {
                var matched = aliases[key].some(function (alias) {
                    return normalizeHeader(alias) === normalizedHeader;
                });
                if (matched) {
                    IMP.mapping[key] = idx;
                }
            }
        });
    });
}

function renderColumnsPreview() {
    var el = document.getElementById('imp-columns-preview');
    if (!el || !IMP.headers.length) return;

    el.innerHTML = IMP.headers.map(function (h, i) {
        return '<span class="col-badge">' +
            '<strong>' + String.fromCharCode(65 + i) + '</strong> ' + escHtml(h) +
            '</span>';
    }).join('');
    el.style.display = 'flex';
}

// ═══════════════════════════════════════════════════════════════
// ÉTAPE 2 — MAPPAGE
// ═══════════════════════════════════════════════════════════════
function renderMappingTable() {
    var tbody = document.getElementById('imp-mapping-body');
    if (!tbody) return;

    // Performance : utiliser un fragment DocumentFragment
    var fragment = document.createDocumentFragment();

    CHAMPS.forEach(function (c) {
        var selectedIdx = IMP.mapping[c.key] !== undefined ? IMP.mapping[c.key] : '';

        var tr = document.createElement('tr');

        // Colonne 1 : label + hint
        var td1 = document.createElement('td');
        td1.innerHTML =
            '<span class="champ-label' + (c.required ? ' required' : '') + '">' +
            escHtml(c.label) +
            '</span>' +
            '<small class="champ-hint">' + escHtml(c.hint) + '</small>';

        // Colonne 2 : select
        var td2 = document.createElement('td');
        var sel = document.createElement('select');
        sel.className = 'form-control mapping-select';
        sel.setAttribute('data-field', c.key);

        var optIgnore = document.createElement('option');
        optIgnore.value = '';
        optIgnore.textContent = '— Ignorer —';
        sel.appendChild(optIgnore);

        IMP.headers.forEach(function (h, i) {
            var opt = document.createElement('option');
            opt.value = i;
            opt.textContent = String.fromCharCode(65 + i) + ' — ' + h;
            if (String(selectedIdx) === String(i)) opt.selected = true;
            sel.appendChild(opt);
        });

        sel.addEventListener('change', function () { onMappingChange(this); });
        td2.appendChild(sel);

        // Colonne 3 : prévisualisation
        var td3 = document.createElement('td');
        td3.className = 'preview-cell';
        td3.id = 'preview-' + c.key;
        var preview = (selectedIdx !== '' && IMP.sheetData.length > 0)
            ? String(IMP.sheetData[0][selectedIdx] || '')
            : '';
        td3.innerHTML = '<span class="preview-val">' + escHtml(preview) + '</span>';

        tr.appendChild(td1);
        tr.appendChild(td2);
        tr.appendChild(td3);
        fragment.appendChild(tr);
    });

    tbody.innerHTML = '';
    tbody.appendChild(fragment);
}

function onMappingChange(selectEl) {
    var field = selectEl.getAttribute('data-field');
    var colIndex = selectEl.value !== '' ? parseInt(selectEl.value, 10) : undefined;

    IMP.mapping[field] = colIndex;

    var previewEl = document.getElementById('preview-' + field);
    if (previewEl) {
        var val = (colIndex !== undefined && IMP.sheetData.length > 0)
            ? String(IMP.sheetData[0][colIndex] || '')
            : '';
        previewEl.innerHTML = '<span class="preview-val">' + escHtml(val) + '</span>';
    }
}

function validateMapping() {
    var missing = CHAMPS.filter(function (c) {
        return c.required && IMP.mapping[c.key] === undefined;
    }).map(function (c) { return c.label; });

    if (missing.length) {
        Swal.fire('Mappage incomplet',
            'Les champs obligatoires suivants ne sont pas mappés :<br><strong>' +
            missing.join(', ') + '</strong>', 'warning');
        return false;
    }
    return true;
}

// ═══════════════════════════════════════════════════════════════
// ÉTAPE 3 — APERÇU + VALIDATION
// ═══════════════════════════════════════════════════════════════
function renderPreview() {
    validateAllRows();

    var stats = document.getElementById('imp-preview-stats');
    if (stats) {
        stats.innerHTML =
            '<div class="imp-stat ok"><i class="fas fa-check-circle"></i> ' +
            '<strong>' + IMP.validRows.length + '</strong> ligne(s) valide(s)</div>' +
            '<div class="imp-stat err"><i class="fas fa-exclamation-triangle"></i> ' +
            '<strong>' + IMP.errorRows.length + '</strong> anomalie(s)</div>' +
            '<div class="imp-stat total"><i class="fas fa-table"></i> ' +
            '<strong>' + (IMP.validRows.length + IMP.errorRows.length) + '</strong> total</div>';
    }

    renderPreviewTable();
}

function validateAllRows() {
    IMP.validRows = [];
    IMP.errorRows = [];

    var matricules = {}; // Détection doublons internes

    IMP.sheetData.forEach(function (row, idx) {
        // Ignorer lignes vides
        if (!row.some(function (c) { return String(c).trim() !== ''; })) return;

        var obj = extractRow(row);
        var errors = [];

        // 1. Champs obligatoires
        CHAMPS.forEach(function (c) {
            if (c.required && (!obj[c.key] || String(obj[c.key]).trim() === '')) {
                errors.push('Champ manquant : ' + c.label);
            }
        });

        // 2. Email
        if (obj.EMAIL && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(obj.EMAIL)) {
            errors.push('Email invalide : "' + obj.EMAIL + '"');
        }

        // 3. Genre
        if (obj.GENRE && ['M', 'F'].indexOf(String(obj.GENRE).toUpperCase()) === -1) {
            errors.push('Genre invalide : "' + obj.GENRE + '" (M ou F attendu)');
        }

        // 4. Date de naissance
        if (obj.DATE_NAISS && obj.DATE_NAISS.trim() !== '') {
            var d = new Date(obj.DATE_NAISS);
            if (isNaN(d.getTime())) {
                errors.push('Date de naissance invalide : "' + obj.DATE_NAISS + '"');
            }
        }

        // 5. CLASSE → résolution vers CLASSE_ID (INT)
        if (obj.CLASSE && obj.CLASSE.trim() !== '') {
            var classeValue = obj.CLASSE.trim();
            var classeIdCandidate = parseInt(classeValue, 10);

            if (!isNaN(classeIdCandidate)) {
                obj.CLASSE_ID = classeIdCandidate;
            } else {
                var classeMatch = null;
                var classeNom = classeValue.toLowerCase();

                for (var cj = 0; cj < IMP.classesList.length; cj++) {
                    var classEntry = IMP.classesList[cj];
                    var nom = String(classEntry.NOM || classEntry.Nom || classEntry.nom || '').trim().toLowerCase();
                    if (nom === classeNom) {
                        classeMatch = classEntry;
                        break;
                    }
                }

                if (!classeMatch) {
                    errors.push('Classe introuvable : "' + obj.CLASSE + '"');
                } else {
                    var rawId = classeMatch.ID !== undefined ? classeMatch.ID
                        : classeMatch.Id !== undefined ? classeMatch.Id
                            : classeMatch.id !== undefined ? classeMatch.id : null;
                    var idNum = parseInt(rawId, 10);
                    if (isNaN(idNum)) {
                        errors.push('ID de classe non numérique pour : "' + obj.CLASSE + '"');
                    } else {
                        obj.CLASSE_ID = idNum;
                    }
                }
            }
        } else if (CHAMPS.find(function (c) { return c.key === 'CLASSE'; }).required) {
            // Déjà signalé dans les champs obligatoires
        }

        // 6. Doublon matricule dans le fichier
        if (obj.MATRICULE) {
            if (matricules[obj.MATRICULE]) {
                errors.push('Doublon dans le fichier : matricule "' + obj.MATRICULE + '" déjà présent');
            } else {
                matricules[obj.MATRICULE] = true;
            }
        }

        obj._ligne = idx + (IMP.skipFirst ? 2 : 1);
        obj._errors = errors;

        // FIX: STATUT dans le payload = valeur texte propre (pas du HTML)
        // On garde une propriété séparée pour l'affichage
        obj._statutTexte = (obj.STATUS && obj.STATUS.trim() !== '') ? obj.STATUS.trim() : 'actif';

        if (errors.length > 0) {
            IMP.errorRows.push(obj);
        } else {
            IMP.validRows.push(obj);
        }
    });
}

function extractRow(row) {
    var obj = {};
    CHAMPS.forEach(function (c) {
        if (IMP.mapping[c.key] !== undefined) {
            var val = row[IMP.mapping[c.key]];
            // Conversion Date (SheetJS avec cellDates:true)
            if (val instanceof Date) {
                val = val.getFullYear() + '-' +
                    String(val.getMonth() + 1).padStart(2, '0') + '-' +
                    String(val.getDate()).padStart(2, '0');
            }
            obj[c.key] = String(val == null ? '' : val).trim();
        }
    });
    return obj;
}

function renderPreviewTable() {
    var container = document.getElementById('imp-preview-table');
    if (!container) return;

    var allRows = IMP.validRows.concat(IMP.errorRows)
        .sort(function (a, b) { return a._ligne - b._ligne; });

    if (!allRows.length) {
        container.innerHTML = '<p style="text-align:center;color:#888;padding:20px;">Aucune donnée à afficher.</p>';
        return;
    }

    // Performance : construction via fragment
    var table = document.createElement('table');
    table.className = 'imp-table';

    // En-tête
    var thead = document.createElement('thead');
    var trH = document.createElement('tr');
    var thLigne = document.createElement('th');
    thLigne.textContent = '#';
    trH.appendChild(thLigne);

    CHAMPS.forEach(function (c) {
        var th = document.createElement('th');
        th.textContent = c.label;
        trH.appendChild(th);
    });

    // FIX: colonne Statut affiche TOUTES les erreurs en détail
    var thStat = document.createElement('th');
    thStat.textContent = 'Vérification';
    trH.appendChild(thStat);
    thead.appendChild(trH);
    table.appendChild(thead);

    // Corps
    var tbody = document.createElement('tbody');
    allRows.forEach(function (row) {
        var isValid = row._errors.length === 0;
        var tr = document.createElement('tr');
        tr.className = isValid ? 'row-valid' : 'row-error';

        // Numéro de ligne
        var tdLigne = document.createElement('td');
        tdLigne.textContent = row._ligne;
        tr.appendChild(tdLigne);

        // Données
        CHAMPS.forEach(function (c) {
            var td = document.createElement('td');
            var val = row[c.key] || '';

            // Pour CLASSE, on affiche le nom saisi + l'ID résolu si disponible
            if (c.key === 'CLASSE' && row.CLASSE_NOM !== undefined) {
                td.innerHTML = escHtml(val) +
                    ' <small style="color:#6c757d;">(NOM=' + row.CLASSE_NOM + ')</small>';
            } else {
                td.textContent = val || '—';
            }
            tr.appendChild(td);
        });

        // ═══════════════════════════════════════════════════════════
        // FIX PRINCIPAL : affichage DÉTAILLÉ de toutes les erreurs
        // Chaque erreur sur sa propre ligne dans la cellule Statut
        // ═══════════════════════════════════════════════════════════
        var tdStat = document.createElement('td');
        if (isValid) {
            tdStat.innerHTML =
                '<span class="badge-ok"><i class="fas fa-check"></i> OK</span>';
        } else {
            // Liste HTML de toutes les erreurs (une par ligne)
            var errList = row._errors.map(function (e) {
                return '<li style="margin:2px 0; font-size:0.85em;">' +
                    '<i class="fas fa-exclamation-circle" style="color:#dc3545;margin-right:4px;"></i>' +
                    escHtml(e) + '</li>';
            }).join('');

            tdStat.innerHTML =
                '<span class="badge-err" style="display:block;text-align:left;">' +
                '<strong><i class="fas fa-times-circle"></i> ' +
                row._errors.length + ' erreur(s) :</strong>' +
                '<ul style="margin:4px 0 0 8px;padding:0;list-style:none;">' + errList + '</ul>' +
                '</span>';
        }
        tr.appendChild(tdStat);
        tbody.appendChild(tr);
    });

    table.appendChild(tbody);

    var wrapper = document.createElement('div');
    wrapper.className = 'imp-preview-wrapper';
    wrapper.style.maxHeight = '380px';
    wrapper.style.overflowY = 'auto';
    wrapper.appendChild(table);

    container.innerHTML = '';
    container.appendChild(wrapper);
}

// ═══════════════════════════════════════════════════════════════
// ÉTAPE 4 — CONFIRMATION AVANT INJECTION
// ═══════════════════════════════════════════════════════════════
function renderConfirmationStep() {
    var container = document.getElementById('imp-result-body');
    if (!container) return;

    // Affichage du résumé de validation avant injection
    var html = '<div class="imp-result-summary">' +
        '<div class="res-stat ok">' +
        '<i class="fas fa-check-circle"></i>' +
        '<strong>' + IMP.validRows.length + '</strong>' +
        '<span>Prêts à intégrer</span>' +
        '</div>' +
        '<div class="res-stat warn">' +
        '<i class="fas fa-exclamation-triangle"></i>' +
        '<strong>' + IMP.errorRows.length + '</strong>' +
        '<span>Seront ignorés</span>' +
        '</div>' +
        '</div>';

    if (IMP.errorRows.length > 0) {
        html += '<div class="imp-section">' +
            '<h5><i class="fas fa-exclamation-circle" style="color:#dc3545;"></i> ' +
            IMP.errorRows.length + ' ligne(s) avec anomalies (ignorées lors de l\'import)</h5>' +
            '<div style="overflow-x:auto;max-height:200px;overflow-y:auto;">' +
            '<table class="imp-table"><thead><tr>' +
            '<th>#</th><th>Matricule</th><th>Nom</th><th>Erreurs</th>' +
            '</tr></thead><tbody>' +
            IMP.errorRows.map(function (r) {
                return '<tr class="row-error">' +
                    '<td>' + r._ligne + '</td>' +
                    '<td>' + escHtml(r.MATRICULE || '—') + '</td>' +
                    '<td>' + escHtml(r.NOM || '—') + '</td>' +
                    '<td style="font-size:0.85em;color:#dc3545;">' +
                    r._errors.map(function (e) { return escHtml(e); }).join('<br>') +
                    '</td>' +
                    '</tr>';
            }).join('') +
            '</tbody></table></div></div>';
    }

    if (IMP.validRows.length === 0) {
        html += '<div style="text-align:center;padding:20px;color:#dc3545;">' +
            '<i class="fas fa-times-circle fa-2x"></i><br><br>' +
            '<strong>Aucune ligne valide à importer.</strong><br>' +
            'Corrigez les erreurs et recommencez.' +
            '</div>';
    } else {
        html += '<div class="imp-success-msg" style="margin-top:16px;">' +
            '<i class="fas fa-info-circle"></i> ' +
            '<strong>' + IMP.validRows.length + '</strong> élève(s) seront intégrés.' +
            ' Cliquez sur <strong>Lancer importation</strong> pour confirmer.' +
            '</div>';
    }

    container.innerHTML = html;

    // Activer/désactiver le bouton d'intégration selon les lignes valides
    var btnLaunch = document.getElementById('imp-btn-launch');
    if (btnLaunch) {
        btnLaunch.style.display = IMP.validRows.length > 0 ? 'inline-flex' : 'none';
    }
}

// ═══════════════════════════════════════════════════════════════
// ÉTAPE 4 — LANCEMENT + MODAL RÉSULTAT
// ═══════════════════════════════════════════════════════════════
function launchImport() {
    // 1. On récupère le bouton
    var btnLaunch = document.getElementById('imp-btn-launch'); // Vérifie bien que l'ID est le bon

    if (!IMP.validRows.length) {
        Swal.fire('Aucune ligne valide',
            'Toutes les lignes contiennent des anomalies. Corrigez le fichier et recommencez.',
            'error');
        return;
    }

    // 2. On grise le bouton et on change l'apparence (état "en cours", pas de verdict prématuré)
    if (btnLaunch) {
        btnLaunch.disabled = true;
        btnLaunch.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Importation en cours...';
        btnLaunch.style.opacity = '0.7';
        btnLaunch.style.cursor = 'not-allowed';
    }

    doIntegration();
}

function doIntegration() {
    showSpinner();

    // FIX: payload propre — CLASSE_ID en INT, STATUT en texte (pas de HTML)
    var payload = IMP.validRows.map(function (r) {
        return {
            MATRICULE: r.MATRICULE || '',
            ANNEE_SCO: r.ANNEE_SCO || '',
            NOM: r.NOM || '',
            CLASSE_ID: String(r.CLASSE_ID || 0),   // texte pour matcher Dictionary<string,string> côté serveur
            EMAIL: r.EMAIL || '',
            TELEPHONE: r.TELEPHONE || '',
            DATE_NAISS: r.DATE_NAISS || null,
            GENRE: r.GENRE || '',
            ADRESSE: r.ADRESSE || '',
            PARENT: r.PARENT || '',
            STATUT: r._statutTexte || 'actif'  // FIX: texte propre, pas de HTML
        };
    });

    fetch('handlers/ImportEleves.ashx', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ eleves: payload })
    })

        .then(function (r) {
            return r.text().then(function (text) {
                if (!text) {
                    throw new Error('Réponse vide du serveur.');
                }

                try {
                    var data = JSON.parse(text);
                    if (!r.ok) {
                        throw new Error(data.message || 'Erreur HTTP ' + r.status);
                    }
                    return data;
                } catch (err) {
                    throw new Error(text || 'Erreur inconnue du serveur.');
                }
            });
        })

        .then(function (data) {
            hideSpinner();

            var btnLaunch = document.getElementById('imp-btn-launch');

            if (data.success && (data.inserted > 0 || data.updated > 0)) {
                var step4 = document.getElementById('imp-step-4');
                if (step4) {
                    step4.classList.remove('active');
                    step4.classList.add('done');
                }

                if (btnLaunch) {
                    btnLaunch.style.display = 'none';
                }

                var summaryText = (data.inserted || 0) + ' ajout(s)';
                if ((data.updated || 0) > 0) {
                    summaryText += ' et ' + (data.updated || 0) + ' mise(s) à jour';
                }

                const Toast = Swal.mixin({
                    toast: true,
                    position: 'top-end',
                    showConfirmButton: false,
                    timer: 5000,
                    timerProgressBar: true,
                    didOpen: (toast) => {
                        toast.addEventListener('mouseenter', Swal.stopTimer)
                        toast.addEventListener('mouseleave', Swal.resumeTimer)
                    }
                });

                Toast.fire({
                    icon: 'success',
                    title: summaryText + ' effectués avec succès !'
                });
            } else {
                // Import partiel ou totalement en échec : on remet le bouton dans un état
                // exploitable au lieu de le laisser bloqué sur le texte "en cours" du clic précédent.
                if (btnLaunch) {
                    btnLaunch.disabled = false;
                    btnLaunch.innerHTML = '<i class="fas fa-rocket"></i> Relancer l\'import';
                    btnLaunch.style.opacity = '1';
                    btnLaunch.style.cursor = 'pointer';
                }
            }

            renderResultModal(data);
        })

        .catch(function (err) {
            hideSpinner();

            var btnLaunch = document.getElementById('imp-btn-launch');
            if (btnLaunch) {
                btnLaunch.disabled = false;
                btnLaunch.innerHTML = '<i class="fas fa-rocket"></i> Lancer importation';
                btnLaunch.style.opacity = '1';
                btnLaunch.style.cursor = 'pointer';
            }
            Swal.fire({
                title: 'Échec de l’import',
                html: '<div style="text-align:left;">' + escHtml(err && err.message ? err.message : 'Erreur inconnue') + '</div>',
                icon: 'error',
                confirmButtonText: 'Fermer'
            });
        });
}

function renderResultModal(data) {
    var container = document.getElementById('imp-result-body');
    if (!container) return;

    var inserts = data.inserted || 0;
    var updated = data.updated || 0;
    var skipped = data.skipped || 0;
    var dups = data.duplicates || [];
    var errsSrv = data.errors || [];
    var hasProblems = (skipped > 0 || errsSrv.length > 0 || !data.success);

    var html = '';
    if (!data.success) {
        html += '<div class="imp-section" style="border-left:4px solid #dc3545;">' +
            '<h5><i class="fas fa-exclamation-circle" style="color:#dc3545;"></i> Échec de l’import</h5>' +
            '<div style="color:#dc3545;">' + escHtml(data.message || 'Erreur inconnue') + '</div>' +
            '</div>';
    }

    html += '<div class="imp-result-summary">' +
        '<div class="res-stat ok"><i class="fas fa-check-circle"></i><strong>' + inserts + '</strong><span>Ajoutés</span></div>' +
        '<div class="res-stat warn"><i class="fas fa-sync-alt"></i><strong>' + updated + '</strong><span>Mises à jour</span></div>' +
        '<div class="res-stat warn"><i class="fas fa-exclamation-triangle"></i><strong>' + skipped + '</strong><span>Ignorés</span></div>' +
        '</div>';

    if (dups.length) {
        html += '<div class="imp-section"><h5><i class="fas fa-copy"></i> Doublons ignorés (' + dups.length + ')</h5>' +
            '<div style="overflow-x:auto;max-height:180px;overflow-y:auto;">' +
            '<table class="imp-table"><thead><tr><th>Matricule</th><th>Nom</th><th>Raison</th></tr></thead><tbody>' +
            dups.map(function (d) {
                return '<tr class="row-warn"><td>' + escHtml(d.MATRICULE || '') + '</td><td>' +
                    escHtml(d.NOM || '') + '</td><td>' + escHtml(d.raison || 'Doublon matricule') + '</td></tr>';
            }).join('') +
            '</tbody></table></div></div>';
    }

    if (errsSrv.length) {
        html += '<div class="imp-section"><h5><i class="fas fa-times-circle"></i> Erreurs serveur (' + errsSrv.length + ')</h5>' +
            '<div style="overflow-x:auto;max-height:180px;overflow-y:auto;">' +
            '<table class="imp-table"><thead><tr><th>Matricule</th><th>Détail de l\'erreur</th></tr></thead><tbody>' +
            errsSrv.map(function (e) {
                return '<tr class="row-error"><td>' + escHtml(e.MATRICULE || '?') + '</td>' +
                    '<td>' + escHtml(e.message || 'Erreur inconnue') + '</td></tr>';
            }).join('') +
            '</tbody></table></div></div>';
    }

    if (!hasProblems) {
        var totalProcessed = inserts + updated;
        html += '<div class="imp-success-msg"><i class="fas fa-check-circle"></i> ' +
            'Import réussi ! ' + totalProcessed + ' élève(s) traité(s) sans anomalie.</div>';
    }

    var btnDefinitif = document.getElementById('imp-btn-definitif');
    if (btnDefinitif) {
        btnDefinitif.disabled = ((inserts + updated) === 0);
        if ((inserts + updated) > 0) {
            btnDefinitif.textContent = '✓ ' + (inserts + updated) + ' ok Redirection vers la page Eleves';
        }
    }

    container.innerHTML = html;
}

function confirmerIntegrationDefinitive() {
    Swal.fire({
        icon: 'success',
        title: 'Redirection vers la page Eleves',
        text: IMP.validRows.length + ' élève(s) ont été intégrés dans la base de données.',
        timer: null,
        showCloseButton: true,
        allowOutsideClick: false,
        showConfirmButton: true,
        confirmButtonText: 'Aller à la liste des élèves',
        confirmButtonColor: '#28a745'
    }).then(function (r) {
        if (r.isConfirmed) {
            window.location.href = '../../modules/eleves/eleves.aspx';
        }
    });
}

function resetImport() {
    // On affiche d'abord le spinner pour montrer que l'action est prise en compte
    showSpinner();

    // Optionnel : Un petit message Swall avant de recharger 
    // ou rechargement direct pour plus de rapidité

    setTimeout(function () {
        // Recharge la page complète
        window.location.reload();
    }, 1000); // Un léger délai pour laisser le temps au spinner d'apparaître
}

// ─────────────────────────────────────────────
// TÉLÉCHARGER LE MODÈLE EXCEL
// ─────────────────────────────────────────────
function downloadTemplate() {
    var headers = CHAMPS.map(function (c) { return c.label + (c.required ? ' *' : ''); });
    var example = ['2024001', '1', 'RAKOTO Jean', '6ème A', 'rakoto@mail.com',
        '0341234567', '2010-05-01', 'M', 'Lot II A Antananarivo', 'RAKOTO Pierre', 'actif'];

    var ws = XLSX.utils.aoa_to_sheet([headers, example]);
    ws['!cols'] = headers.map(function () { return { wch: 22 }; });

    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'ÉLÈVES');
    XLSX.writeFile(wb, 'Modele_Import_Eleves.xlsx');
}

// ─────────────────────────────────────────────
// CHARGER LES CLASSES DEPUIS LA BDD
// ─────────────────────────────────────────────
function chargerClassesPourImport() {
    fetch('../../parametres/classes/handlers/GetClasse.ashx')
        .then(function (r) {
            if (!r.ok) throw new Error('Erreur réseau (' + r.status + ')');
            return r.json();
        })
        .then(function (data) {
            if (data.success) {
                IMP.classesList = data.Classes || data.classes || [];
            } else {
                Swal.fire({
                    title: 'Erreur de configuration',
                    text: 'Impossible de récupérer la liste des classes : ' + (data.message || 'Erreur inconnue'),
                    icon: 'warning',
                    confirmButtonColor: '#3085d6'
                });
            }
        })
        .catch(function (err) {
            Swal.fire({
                title: 'Connexion interrompue',
                html: 'Impossible de charger la liste des classes.<br>' +
                    '<small class="text-muted">' + escHtml(err.message) + '</small>',
                icon: 'error',
                footer: 'Vérifiez votre connexion ou contactez l\'administrateur.'
            });
        });
}

// ─────────────────────────────────────────────
// SPINNER
// ─────────────────────────────────────────────
function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (s) { s.style.display = 'flex'; s.style.visibility = 'visible'; s.style.opacity = '1'; }
}
function hideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (s) { s.style.display = 'none'; s.style.visibility = 'hidden'; s.style.opacity = '0'; }
}

// ─────────────────────────────────────────────
// UTILITAIRES
// ─────────────────────────────────────────────
function escHtml(s) {
    return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
