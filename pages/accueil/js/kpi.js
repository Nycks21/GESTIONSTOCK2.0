'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// KPI — Module Dashboard
// ─────────────────────────────────────────────────────────────────────────────

function updateKPI(data) {
    if (!data) return;

    var valEleves = document.getElementById('valEleves');
    var valClasses = document.getElementById('valClasses');
    var valPresence = document.getElementById('valPresence');
    var valImpayes = document.getElementById('valImpayes');

    if (valEleves) valEleves.textContent = data.totalEleves || '—';
    if (valClasses) valClasses.textContent = data.totalClasses || '—';
    if (valPresence) valPresence.textContent = data.tauxPresence || '—';
    if (valImpayes) valImpayes.textContent = formatCurrency(data.fraisImpayes || 0);

    // Pastilles
    var pillEleves = document.getElementById('pillEleves');
    if (pillEleves) {
        pillEleves.textContent = '+' + (data.nouveauxRentree || 0);
        pillEleves.className = 'pill pill-up';
    }

    var pillClasses = document.getElementById('pillClasses');
    if (pillClasses) {
        pillClasses.textContent = 'Moy. ' + (data.moyenneEleves || 0) + ' élèves';
    }

    var varPres = data.variationPresence || 0;
    var pillPresence = document.getElementById('pillPresence');
    if (pillPresence) {
        pillPresence.textContent = (varPres >= 0 ? '+' : '') + varPres + '%';
        pillPresence.className = 'pill pill-' + (varPres >= 0 ? 'up' : 'dn');
    }

    // Jauges
    updateGauges([
        { label: 'Présence', value: data.tauxPresence || 0, color: COLORS.forest },
        { label: 'Réussite', value: data.tauxReussite || 0, color: COLORS.gold },
        { label: 'Paiements', value: data.tauxPaiement || 0, color: COLORS.terra }
    ]);

    // Répartition garçons/filles
    updateGenderRepartition(data.garcons || 0, data.filles || 0);
}

function updateGauges(items) {
    var container = document.getElementById('gaugeContainer');
    if (!container) return;

    var html = '';
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var value = Math.min(100, Math.max(0, item.value));
        html += '<div class="gauge-item">'
            + '<div class="gauge-val">' + Math.round(value) + '<span style="font-size:12px">%</span></div>'
            + '<div class="gauge-bar">'
            + '<div class="gauge-fill" style="width:' + value + '%;background:' + item.color + '"></div>'
            + '</div>'
            + '<div class="gauge-lbl">' + item.label + '</div>'
            + '</div>';
    }
    container.innerHTML = html;
}

function updateGenderRepartition(garcons, filles) {
    var total = garcons + filles;
    if (total === 0) return;

    var pG = Math.round((garcons / total) * 100);
    var pF = 100 - pG;

    var pctGarcons = document.getElementById('pctGarcons');
    var pctFilles = document.getElementById('pctFilles');
    if (pctGarcons) pctGarcons.textContent = pG + '%';
    if (pctFilles) pctFilles.textContent = pF + '%';

    setBarWidth('fillGarcons', pG);
    setBarWidth('fillFilles', pF);
}