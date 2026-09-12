'use strict';

function initMovementsChart(labels, entrees, sorties) {
    var ctx = document.getElementById('chartMovements');
    if (!ctx) return;

    if (DashboardState.charts.movements) {
        DashboardState.charts.movements.destroy();
    }

    DashboardState.charts.movements = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Entrées',
                    data: entrees,
                    backgroundColor: DASHBOARD_COLORS.success,
                    borderRadius: 4
                },
                {
                    label: 'Sorties',
                    data: sorties,
                    backgroundColor: DASHBOARD_COLORS.danger,
                    borderRadius: 4
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { position: 'top', labels: { usePointStyle: true, padding: 15 } },
                tooltip: { mode: 'index', intersect: false }
            },
            scales: {
                x: { grid: { display: false }, ticks: { maxRotation: 45, minRotation: 45, font: { size: 10 } } },
                y: { beginAtZero: true, ticks: { precision: 0 } }
            }
        }
    });
}

function initCategoriesChart(labels, quantites) {
    var ctx = document.getElementById('chartCategories');
    if (!ctx) return;

    if (DashboardState.charts.categories) {
        DashboardState.charts.categories.destroy();
    }

    var colors = DASHBOARD_COLORS.palette.slice(0, labels.length);

    DashboardState.charts.categories = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: [{
                data: quantites,
                backgroundColor: colors,
                borderWidth: 2,
                borderColor: '#fff'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            cutout: '62%',
            plugins: {
                legend: { display: false },
                tooltip: {
                    callbacks: {
                        label: function(c) {
                            return c.label + ' : ' + formatNumber(c.parsed);
                        }
                    }
                }
            }
        }
    });

    // Légende personnalisée
    var legend = document.getElementById('donutLegend');
    if (legend) {
        var html = '';
        for (var i = 0; i < labels.length; i++) {
            html += '<div class="leg-item">'
                + '<span class="leg-sq" style="background:' + colors[i] + '"></span>'
                + '<span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">'
                + escapeHtml(labels[i]) + '</span>'
                + '<strong>' + formatNumber(quantites[i]) + '</strong>'
                + '</div>';
        }
        legend.innerHTML = html;
    }
}

window.initMovementsChart = initMovementsChart;
window.initCategoriesChart = initCategoriesChart;
