'use strict';
var Emploi = Emploi || {};
Emploi.ui = {
    populateSelects: function() {
        var classes = Emploi.state.classes;
        ['classeFilter', 'editClasse'].forEach(function(id, idx) {
            var sel = document.getElementById(id);
            if (!sel) return;
            var current = sel.value;
            sel.innerHTML = (idx === 0)
                ? '<option value="">-- Choisir une classe --</option>'
                : '<option value="">-- Sélectionner --</option>';
            classes.forEach(function(c) {
                var opt = document.createElement('option');
                opt.value = c.ID;
                opt.textContent = c.NOM;
                sel.appendChild(opt);
            });
            if (current) sel.value = current;
        });
        var matSel = document.getElementById('editMatiere');
        if (matSel) {
            matSel.innerHTML = '<option value="">-- Sélectionner d\'abord une classe --</option>';
        }
    },

    renderTable: function() {
        var tbody = document.getElementById('emploiBody');
        if (!tbody) return;

        var hours = Emploi.utils.generateHourSlots();
        var days = [1, 2, 3, 4, 5, 6];

        // Vérifier si des données existent
        var hasData = false;
        for (var key in Emploi.state.emploiData) {
            if (Emploi.state.emploiData.hasOwnProperty(key)) {
                hasData = true;
                break;
            }
        }

        if (!hasData) {
            tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;padding:40px;color:#6c757d;font-size:16px;">Aucun cours pour cette classe</td></tr>';
            this.attachDragEvents();
            return;
        }

        // Pré-calcul de la grille (rowspan)
        var grid = {};
        days.forEach(function(d) {
            grid[d] = [];
            for (var i = 0; i < hours.length; i++) {
                var h = hours[i];
                var key = d + '_' + h.value;
                var cell = Emploi.state.emploiData[key] || null;
                if (cell && cell.matiere) {
                    var heureFin = cell.heureFin || h.value;
                    var endIndex = i;
                    for (var j = i + 1; j < hours.length; j++) {
                        if (hours[j].value < heureFin) {
                            endIndex = j;
                        } else {
                            break;
                        }
                    }
                    var rowspan = endIndex - i + 1;
                    for (var k = i; k <= endIndex; k++) {
                        if (k === i) {
                            grid[d][k] = { cell: cell, rowspan: rowspan, isStart: true };
                        } else {
                            grid[d][k] = { cell: null, rowspan: 0, isStart: false, skip: true };
                        }
                    }
                    i = endIndex;
                } else {
                    grid[d][i] = { cell: null, rowspan: 0, isStart: false, skip: false };
                }
            }
        });

        // Génération du HTML
        var html = '';
        for (var i = 0; i < hours.length; i++) {
            var tr = '<tr><td class="time-col">' + hours[i].label + '</td>';
            days.forEach(function(d) {
                var info = grid[d][i];
                if (!info) {
                    tr += '<td></td>';
                    return;
                }
                if (info.skip) {
                    return;
                }
                if (info.cell && info.isStart) {
                    var cell = info.cell;
                    // Utiliser matiere_nom s'il existe, sinon fallback
                    var matiereName = cell.matiere_nom || cell.matiere || 'Matière inconnue';

                    var bgColor = cell.couleur || '#007bff';
                    var content = '<div class="cell-content" style="background-color:' + bgColor + '; color:#fff; padding:4px; border-radius:4px; height:100%; display:flex; flex-direction:column; justify-content:center;">'
                        + '<span class="matiere">' + Emploi.utils.escapeHtml(matiereName) + '</span>'
                        + (cell.prof ? '<span class="prof" style="display:block;font-size:0.8em;">' + Emploi.utils.escapeHtml(cell.prof) + '</span>' : '')
                        + (cell.salle ? '<span class="salle" style="display:block;font-size:0.8em;">' + Emploi.utils.escapeHtml(cell.salle) + '</span>' : '')
                        + '</div>';

                    tr += '<td data-day="' + d + '" data-time="' + hours[i].value + '" rowspan="' + info.rowspan + '" class="rowspan-cell" style="height:' + (info.rowspan * 50) + 'px;" onclick="Emploi.events.openEdit(event, this)">'
                        + content
                        + '</td>';
                } else if (!info.cell && !info.skip) {
                    tr += '<td data-day="' + d + '" data-time="' + hours[i].value + '" onclick="Emploi.events.openEdit(event, this)">'
                        + '<span class="empty-cell">-</span>'
                        + '</td>';
                }
            });
            tr += '</tr>';
            html += tr;
        }

        tbody.innerHTML = html;
        this.attachDragEvents();
    },

    attachDragEvents: function() {
        var cells = document.querySelectorAll('#emploiBody td[data-day]');
        cells.forEach(function(td) {
            td.draggable = true;
            td.addEventListener('dragstart', Emploi.events.onDragStart);
            td.addEventListener('dragover', Emploi.events.onDragOver);
            td.addEventListener('drop', Emploi.events.onDrop);
            td.addEventListener('dragend', Emploi.events.onDragEnd);
            td.addEventListener('dblclick', function(e) {
                Emploi.events.openEdit(e, this);
            });
        });
    }
};