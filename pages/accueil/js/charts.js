'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// GRAPHIQUES — Module Dashboard
// ─────────────────────────────────────────────────────────────────────────────

function initChartPresence(ctx, labels, presents, absents) {
    if (chartPresence) {
        chartPresence.destroy();
        chartPresence = null;
    }

    if (!ctx) return;

    chartPresence = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels || ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'],
            datasets: [
                {
                    label: 'Présents',
                    data: presents || [0, 0, 0, 0, 0, 0],
                    backgroundColor: COLORS.forest,
                    borderRadius: 6
                },
                {
                    label: 'Absents',
                    data: absents || [0, 0, 0, 0, 0, 0],
                    backgroundColor: COLORS.terra,
                    borderRadius: 6
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: true },
                tooltip: { mode: 'index' }
            },
            scales: {
                x: { stacked: true, grid: { display: false } },
                y: { stacked: true, beginAtZero: true, ticks: { precision: 0 } }
            }
        }
    });
}

function initChartDonut(ctx, labels, counts) {
    if (chartDonut) {
        chartDonut.destroy();
        chartDonut = null;
    }

    if (!ctx) return;

    var colors = [COLORS.forest, COLORS.forestLight, COLORS.terra, COLORS.gold, COLORS.grey, COLORS.blue];
    var niveaux = labels || ['6ème', '5ème', '4ème', '3ème', '2nde', '1ère'];
    var data = counts || [0, 0, 0, 0, 0, 0];

    chartDonut = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: niveaux,
            datasets: [{
                data: data,
                backgroundColor: colors.slice(0, niveaux.length),
                borderWidth: 2,
                borderColor: '#fff'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            cutout: '65%',
            plugins: {
                legend: { display: true },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return context.label + ' : ' + context.parsed;
                        }
                    }
                }
            }
        }
    });

    updateDonutLegend(niveaux, data, colors);
}

function updateDonutLegend(labels, data, colors) {
    var legend = document.getElementById('donutLegend');
    if (!legend || !labels.length) return;

    var html = '';
    for (var i = 0; i < labels.length; i++) {
        html += '<div class="leg-item">'
            + '<span class="leg-sq" style="background:' + colors[i % colors.length] + '"></span>'
            + labels[i] + ' <span style="float:right;font-weight:600;">' + data[i] + '</span>'
            + '</div>';
    }
    legend.innerHTML = html;
}

function initChartFrais(ctx, labels, payes, impayes, totals) {
    if (chartFrais) {
        chartFrais.destroy();
        chartFrais = null;
    }

    if (!ctx) return;

    chartFrais = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels || [],
            datasets: [
                {
                    label: 'Paiements mensuels',
                    data: payes || [0, 0, 0, 0, 0, 0],
                    borderColor: COLORS.forest,
                    backgroundColor: 'rgba(30,58,47,0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 3,
                    pointBackgroundColor: COLORS.forest
                },
                {
                    label: 'Cumul des paiements',
                    data: totals || [0, 0, 0, 0, 0, 0],
                    borderColor: COLORS.gold,
                    backgroundColor: 'rgba(201,168,76,0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 3,
                    pointBackgroundColor: COLORS.gold,
                    borderDash: [5, 5]
                },
                {
                    label: 'Reste à payer',
                    data: impayes || [0, 0, 0, 0, 0, 0],
                    borderColor: COLORS.terra,
                    backgroundColor: 'rgba(184,92,56,0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 3,
                    pointBackgroundColor: COLORS.terra
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: true },
                tooltip: { mode: 'index' }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        callback: function(value) {
                            if (value === 0) return '0 Ar';
                            return value.toLocaleString('fr-MG') + ' Ar';
                        }
                    }
                }
            }
        }
    });
}

/**
 * Initialise le graphique des taux de réussite par classe (barres empilées)
 * avec légende Chart.js native
 * @param {string} ctxId - ID du canvas (ex: 'chartReussite')
 * @param {Array} data - Tableau d'objets contenant {classe, total, reussis, taux}
 */
function initReussiteChart(ctxId, data) {
    var ctx = document.getElementById(ctxId);
    if (!ctx) {
        console.warn('Canvas ' + ctxId + ' non trouvé');
        return;
    }

    // ✅ Vérifier et détruire proprement l'ancien graphique
    if (window.chartReussite) {
        try {
            if (typeof window.chartReussite.destroy === 'function') {
                window.chartReussite.destroy();
            }
        } catch (e) {
            console.warn('Erreur destruction graphique réussi:', e);
        }
        window.chartReussite = null;
    }

    if (!data || data.length === 0) {
        // Afficher un message d'absence de données
        var parent = ctx.parentNode;
        if (parent) {
            var msg = document.createElement('p');
            msg.style.cssText = 'text-align:center;color:#6c757d;padding:20px;';
            msg.textContent = 'Aucune donnée disponible';
            // Nettoyer le conteneur et ajouter le message
            parent.innerHTML = '';
            parent.appendChild(msg);
        }
        return;
    }

    // Extraire les données pour le graphique
    var labels = data.map(function(item) { return item.classe || 'Non définie'; });
    var reussis = data.map(function(item) { return item.reussis || 0; });
    var echecs = data.map(function(item) { 
        var total = item.total || 0;
        var reussis = item.reussis || 0;
        return total - reussis;
    });

    window.chartReussite = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Réussi',
                    data: reussis,
                    backgroundColor: COLORS.forest,
                    borderRadius: 4,
                    barPercentage: 0.6
                },
                {
                    label: 'Échoué',
                    data: echecs,
                    backgroundColor: COLORS.terra,
                    borderRadius: 4,
                    barPercentage: 0.6
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    position: 'top',
                    labels: {
                        usePointStyle: true,
                        pointStyle: 'rectRounded',
                        padding: 20,
                        font: {
                            size: 13,
                            weight: '500'
                        }
                    }
                },
                tooltip: {
                    mode: 'index',
                    callbacks: {
                        label: function(context) {
                            var label = context.dataset.label || '';
                            var value = context.parsed.y || 0;
                            return label + ' : ' + value;
                        },
                        afterBody: function(tooltipItems) {
                            var total = 0;
                            tooltipItems.forEach(function(item) {
                                total += item.parsed.y;
                            });
                            return 'Total : ' + total;
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: { display: false }
                },
                y: {
                    beginAtZero: true,
                    stacked: true,
                    ticks: {
                        precision: 0,
                        stepSize: 1
                    },
                    title: {
                        display: true,
                        text: 'Nombre d\'élèves',
                        font: {
                            size: 12,
                            weight: '500'
                        }
                    }
                }
            }
        }
    });
}

function destroyAllCharts() {
    if (chartPresence) { chartPresence.destroy(); chartPresence = null; }
    if (chartDonut) { chartDonut.destroy(); chartDonut = null; }
    if (chartFrais) { chartFrais.destroy(); chartFrais = null; }
    if (window.chartReussite) {
        try {
            if (typeof window.chartReussite.destroy === 'function') {
                window.chartReussite.destroy();
            }
        } catch (e) {}
        window.chartReussite = null;
    }
}

// Exposer globalement
window.initChartPresence = initChartPresence;
window.initChartDonut = initChartDonut;
window.initChartFrais = initChartFrais;
window.initReussiteChart = initReussiteChart;
window.destroyAllCharts = destroyAllCharts;
window.updateDonutLegend = updateDonutLegend;