'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// LOADERS — Module Dashboard
// ─────────────────────────────────────────────────────────────────────────────

function loadDashboard() {
    showLoading('Chargement du tableau de bord...');

    var dynTitle = document.getElementById('dynPageTitle');
    var dynBreadcrumb = document.getElementById('dynBreadcrumb');
    if (dynTitle) dynTitle.textContent = 'Tableau de bord';
    if (dynBreadcrumb) dynBreadcrumb.textContent = 'Tableau de bord';

    activateDashboardLink();

    Promise.all([
        loadKPI(),
        loadPresences(),
        loadRepartition(),
        loadReussite(),
        loadFrais(),
        loadAbsencesFrequentes(),
        loadActivite(),
        loadCalendarEvents()
    ]).catch(function(error) {
        console.error('Erreur chargement dashboard:', error);
        if (typeof showToast === 'function') {
            showToast('Erreur lors du chargement des données', 'error');
        }
    }).finally(function() {
        hideLoading();
    });

    generateCalendar(currentDate);
}

async function loadKPI() {
    try {
        var response = await fetch(API_DASHBOARD.kpi);
        var data = await response.json();

        if (data.success) {
            dashboardData.kpi = data;
            updateKPI(data);
        }
    } catch (error) {
        console.error('Erreur KPI:', error);
        if (typeof showToast === 'function') {
            showToast('Erreur chargement des indicateurs', 'error');
        }
    }
}

async function loadPresences() {
    try {
        var response = await fetch(API_DASHBOARD.presence);
        var data = await response.json();

        var ctx = document.getElementById('chartPresence');
        if (ctx) {
            initChartPresence(ctx, data.labels, data.presents, data.absents);
        }
    } catch (error) {
        console.error('Erreur Présences:', error);
    }
}

async function loadRepartition() {
    try {
        var response = await fetch(API_DASHBOARD.repartition);
        var data = await response.json();

        var ctx = document.getElementById('chartDonut');
        if (ctx) {
            initChartDonut(ctx, data.niveaux, data.counts);
        }
    } catch (error) {
        console.error('Erreur Répartition:', error);
    }
}

async function loadReussite() {
    try {
        var response = await fetch(API_DASHBOARD.reussite);
        var data = await response.json();

        if (data.success && data.data) {
            // ✅ Utiliser le graphique avec légende intégrée (canvas)
            initReussiteChart('chartReussite', data.data);
        } else {
            // Si pas de données, afficher un message dans le conteneur parent (optionnel)
            var container = document.getElementById('reussiteContainer');
            if (container) {
                container.innerHTML = '<p class="text-center" style="color:#6c757d;padding:20px;">Aucune donnée disponible</p>';
            }
        }
    } catch (error) {
        console.error('Erreur Réussite:', error);
        var container = document.getElementById('reussiteContainer');
        if (container) {
            container.innerHTML = '<p class="text-center" style="color:#6c757d;padding:20px;">Erreur chargement</p>';
        }
    }
}

async function loadFrais() {
    try {
        var response = await fetch(API_DASHBOARD.frais);
        var data = await response.json();

        var ctx = document.getElementById('chartFrais');
        if (ctx) {
            initChartFrais(ctx, data.labels, data.payes, data.impayes, data.totals);
        }
    } catch (error) {
        console.error('Erreur Frais:', error);
    }
}

async function loadAbsencesFrequentes() {
    try {
        var response = await fetch(API_DASHBOARD.absences);
        var data = await response.json();

        var tbody = document.getElementById('tbodyAbsences');
        if (!tbody) return;

        if (data.success && data.data && data.data.length) {
            var html = '';
            for (var i = 0; i < data.data.length; i++) {
                var item = data.data[i];
                var badgeClass = item.statut === 'Critique' ? 'badge-danger' : 
                                 item.statut === 'Surveiller' ? 'badge-warning' : 'badge-success';
                // Afficher 0 si absent
                var absences = item.nb || 0;
                var retards = item.retards || 0;
                html += '<tr style="cursor:pointer;" onclick="showStudentDetail(\'' + escapeHtml(item.nom) + '\')">'
                    + '<td><strong>' + escapeHtml(item.nom) + '</strong></td>'
                    + '<td>' + escapeHtml(item.classe) + '</td>'
                    + '<td>' + absences + '</td>'
                    + '<td>' + retards + '</td>'
                    + '<td><span class="badge ' + badgeClass + '">' + escapeHtml(item.statut) + '</span></td>'
                    + '</tr>';
            }
            tbody.innerHTML = html;
        } else {
            tbody.innerHTML = '<tr><td colspan="5" class="text-center" style="padding:30px;">Aucune absence ni retard ce mois</td></tr>';
        }
    } catch (error) {
        console.error('Erreur Absences:', error);
        var tbody = document.getElementById('tbodyAbsences');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-center" style="padding:30px;">Erreur chargement</td></tr>';
        }
    }
}

async function loadActivite() {
    try {
        var response = await fetch(API_DASHBOARD.activite);
        var data = await response.json();

        var feed = document.getElementById('activityFeed');
        if (!feed) return;

        var icons = {
            success: 'fa-check-circle',
            danger: 'fa-exclamation-circle',
            warning: 'fa-clock',
            info: 'fa-edit'
        };

        if (data.success && data.data && data.data.length) {
            var html = '';
            for (var i = 0; i < data.data.length; i++) {
                var item = data.data[i];
                html += '<div class="activity-item">'
                    + '<div class="activity-icon ' + item.type + '">'
                    + '<i class="fas ' + (icons[item.type] || 'fa-bell') + '"></i>'
                    + '</div>'
                    + '<div class="activity-content">'
                    + '<div class="activity-text">' + escapeHtml(item.texte) + '</div>'
                    + '<div class="activity-time">' + escapeHtml(item.temps) + '</div>'
                    + '</div>'
                    + '</div>';
            }
            feed.innerHTML = html;
        } else {
            feed.innerHTML = '<p class="text-center" style="color:#6c757d;padding:20px;">Aucune activité récente</p>';
        }
    } catch (error) {
        console.error('Erreur Activité:', error);
        var feed = document.getElementById('activityFeed');
        if (feed) {
            feed.innerHTML = '<p class="text-center" style="color:#6c757d;padding:20px;">Erreur chargement</p>';
        }
    }
}

async function loadCalendarEvents() {
    try {
        var response = await fetch(API_DASHBOARD.events);
        var data = await response.json();

        if (data.success && data.events) {
            calendarEvents = data.events;
            generateCalendar(currentDate);
        } else {
            calendarEvents = [];
            generateCalendar(currentDate);
        }
    } catch (error) {
        console.error('Erreur chargement événements:', error);
        calendarEvents = [];
        generateCalendar(currentDate);
    }
}

window.loadDashboard = loadDashboard;
window.loadKPI = loadKPI;
window.loadPresences = loadPresences;
window.loadRepartition = loadRepartition;
window.loadReussite = loadReussite;
window.loadFrais = loadFrais;
window.loadAbsencesFrequentes = loadAbsencesFrequentes;
window.loadActivite = loadActivite;
window.loadCalendarEvents = loadCalendarEvents;