/**
 * ════════════════════════════════════════════════════════════
 *  DASHBOARD — dashboard.js
 *  Gestion scolaire · Version stable
 * ════════════════════════════════════════════════════════════
 */

'use strict';

// Variables globales pour les chartes
let chartPresence = null;
let chartDonut = null;
let chartFrais = null;
let currentDate = new Date();
let calendarEvents = [];

// URLs des APIs
const API = {
    kpi: 'handlers/GetKPI.ashx',
    presence: 'handlers/GetPresences.ashx',
    repartition: 'handlers/GetRepartition.ashx',
    reussite: 'handlers/GetReussite.ashx',
    frais: 'handlers/GetFrais.ashx',
    absences: 'handlers/GetAbsencesFrequentes.ashx',
    activite: 'handlers/GetActivite.ashx',
    events: 'handlers/GetEvents.ashx'
};

// Couleurs
const C = {
    forest: '#1e3a2f',
    forestLight: '#3d6b54',
    terra: '#b85c38',
    gold: '#c9a84c',
    cream: '#f5f0e8'
};

// ─────────────────────────────────────────────────────────────
// CHARGEMENT PRINCIPAL
// ─────────────────────────────────────────────────────────────
function loadDashboard() {
    showSpinner();
    
    // Mettre à jour les titres
    const dynTitle = document.getElementById('dynPageTitle');
    const dynBreadcrumb = document.getElementById('dynBreadcrumb');
    if (dynTitle) dynTitle.textContent = 'Tableau de bord';
    if (dynBreadcrumb) dynBreadcrumb.textContent = 'Tableau de bord';
    
    // Mettre à jour le lien actif dans la sidebar
    document.querySelectorAll('.sidebar .nav-link, .nav-pills .nav-link').forEach(link => {
        link.classList.remove('active');
    });
    
    // Trouver et activer le lien du dashboard
    const dashboardLinks = document.querySelectorAll('.sidebar .nav-link, .nav-pills .nav-link');
    for (let link of dashboardLinks) {
        if (link.textContent.trim() === 'Dashboard' || link.getAttribute('onclick') === 'loadDashboard()') {
            link.classList.add('active');
            break;
        }
    }
    
    // Charger tous les composants
    Promise.all([
        loadKPI(),
        loadPresences(),
        loadRepartition(),
        loadReussite(),
        loadFrais(),
        loadAbsencesFrequentes(),
        loadActivite(),
        loadCalendarEvents()  // Nouveau: charger les événements
    ]).catch(error => {
        console.error('Erreur chargement dashboard:', error);
    }).finally(() => {
        hideSpinner();
    });
    
    // Générer le calendrier
    generateCalendar(currentDate);
}

// ─────────────────────────────────────────────────────────────
// 1. KPI
// ─────────────────────────────────────────────────────────────
async function loadKPI() {
    try {
        const response = await fetch(API.kpi);
        const data = await response.json();
        
        if (data.success) {
            // Mettre à jour les valeurs KPI
            const valEleves = document.getElementById('valEleves');
            const valClasses = document.getElementById('valClasses');
            const valPresence = document.getElementById('valPresence');
            const valImpayes = document.getElementById('valImpayes');
            
            if (valEleves) valEleves.textContent = data.totalEleves || '—';
            if (valClasses) valClasses.textContent = data.totalClasses || '—';
            if (valPresence) valPresence.textContent = data.tauxPresence || '—';
            if (valImpayes) valImpayes.textContent = formatCurrency(data.fraisImpayes || 0);
            
            // Mettre à jour les pastilles
            const pillEleves = document.getElementById('pillEleves');
            if (pillEleves) {
                pillEleves.textContent = '+' + (data.nouveauxRentree || 0);
                pillEleves.className = 'pill pill-up';
            }
            
            const pillClasses = document.getElementById('pillClasses');
            if (pillClasses) {
                pillClasses.textContent = 'Moy. ' + (data.moyenneEleves || 0) + ' élèves';
            }
            
            const varPres = data.variationPresence || 0;
            const pillPresence = document.getElementById('pillPresence');
            if (pillPresence) {
                pillPresence.textContent = (varPres >= 0 ? '+' : '') + varPres + '%';
                pillPresence.className = 'pill pill-' + (varPres >= 0 ? 'up' : 'dn');
            }
            
            // Mettre à jour les jauges
            updateGauges([
                { label: 'Présence', value: data.tauxPresence || 0, color: C.forest },
                { label: 'Réussite', value: data.tauxReussite || 0, color: C.gold },
                { label: 'Paiements', value: data.tauxPaiement || 0, color: C.terra }
            ]);
            
            // Mettre à jour la répartition garçons/filles
            const total = (data.garcons || 0) + (data.filles || 0);
            if (total > 0) {
                const pG = Math.round((data.garcons / total) * 100);
                const pF = 100 - pG;
                
                const pctGarcons = document.getElementById('pctGarcons');
                const pctFilles = document.getElementById('pctFilles');
                if (pctGarcons) pctGarcons.textContent = pG + '%';
                if (pctFilles) pctFilles.textContent = pF + '%';
                
                setBarWidth('fillGarcons', pG);
                setBarWidth('fillFilles', pF);
            }
        }
    } catch (error) {
        console.error('Erreur KPI:', error);
    }
}

// ─────────────────────────────────────────────────────────────
// 2. PRÉSENCES (graphique)
// ─────────────────────────────────────────────────────────────
async function loadPresences() {
    try {
        const response = await fetch(API.presence);
        const data = await response.json();
        
        const ctx = document.getElementById('chartPresence');
        if (!ctx) {
            console.warn('canvas chartPresence non trouvé');
            return;
        }
        
        if (chartPresence) chartPresence.destroy();
        
        const labels = data.labels || ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
        const presents = data.presents || [0, 0, 0, 0, 0, 0];
        const absents = data.absents || [0, 0, 0, 0, 0, 0];
        
        chartPresence = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [
                    { label: 'Présents', data: presents, backgroundColor: C.forest, borderRadius: 6 },
                    { label: 'Absents', data: absents, backgroundColor: C.terra, borderRadius: 6 }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { 
                    legend: { display: false }, 
                    tooltip: { mode: 'index' } 
                },
                scales: { 
                    x: { stacked: true, grid: { display: false } }, 
                    y: { stacked: true, beginAtZero: true, ticks: { precision: 0 } } 
                }
            }
        });
    } catch (error) {
        console.error('Erreur Présences:', error);
    }
}

// ─────────────────────────────────────────────────────────────
// 3. RÉPARTITION PAR NIVEAU (donut)
// ─────────────────────────────────────────────────────────────
async function loadRepartition() {
    try {
        const response = await fetch(API.repartition);
        const data = await response.json();
        
        const ctx = document.getElementById('chartDonut');
        if (!ctx) {
            console.warn('canvas chartDonut non trouvé');
            return;
        }
        
        const colors = [C.forest, C.forestLight, C.terra, C.gold, '#6c757d', '#17a2b8'];
        const niveaux = data.niveaux || ['6ème', '5ème', '4ème', '3ème', '2nde', '1ère'];
        const counts = data.counts || [0, 0, 0, 0, 0, 0];
        
        if (chartDonut) chartDonut.destroy();
        
        chartDonut = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: niveaux,
                datasets: [{ data: counts, backgroundColor: colors.slice(0, niveaux.length), borderWidth: 2, borderColor: '#fff' }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                cutout: '65%',
                plugins: { 
                    legend: { display: false }, 
                    tooltip: { callbacks: { label: (c) => c.label + ' : ' + c.parsed } } 
                }
            }
        });
        
        // Légende personnalisée
        const legend = document.getElementById('donutLegend');
        if (legend && niveaux.length) {
            legend.innerHTML = niveaux.map((n, i) => `
                <div class="leg-item">
                    <span class="leg-sq" style="background:${colors[i % colors.length]}"></span>
                    ${n} <span style="float:right; font-weight:600;">${counts[i]}</span>
                </div>
            `).join('');
        }
    } catch (error) {
        console.error('Erreur Répartition:', error);
    }
}

// ─────────────────────────────────────────────────────────────
// 4. TAUX DE RÉUSSITE PAR CLASSE
// ─────────────────────────────────────────────────────────────
async function loadReussite() {
    try {
        const response = await fetch(API.reussite);
        const data = await response.json();
        
        const container = document.getElementById('reussiteContainer');
        if (!container) return;
        
        if (data.success && data.data && data.data.length) {
            container.innerHTML = data.data.map(item => `
                <div class="prog-item">
                    <div class="prog-head">
                        <span class="prog-name">${escapeHtml(item.classe)}</span>
                        <span class="prog-pct">${item.taux}%</span>
                    </div>
                    <div class="prog-track">
                        <div class="prog-fill" style="width:${item.taux}%; background:${C.forest}"></div>
                    </div>
                </div>
            `).join('');
        } else {
            container.innerHTML = '<p class="text-center" style="color:#6c757d; padding:20px;">Aucune donnée disponible</p>';
        }
    } catch (error) {
        console.error('Erreur Réussite:', error);
        const container = document.getElementById('reussiteContainer');
        if (container) {
            container.innerHTML = '<p class="text-center" style="color:#6c757d; padding:20px;">Données non disponibles</p>';
        }
    }
}

// ─────────────────────────────────────────────────────────────
// 5. FRAIS SCOLAIRES (graphique)
// ─────────────────────────────────────────────────────────────
async function loadFrais() {
    try {
        const response = await fetch(API.frais);
        const data = await response.json();
        
        const ctx = document.getElementById('chartFrais');
        if (!ctx) {
            console.warn('canvas chartFrais non trouvé');
            return;
        }
        
        if (chartFrais) chartFrais.destroy();
        
        const labels = data.labels || ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin'];
        const payes = data.payes || [0, 0, 0, 0, 0, 0];
        const impayes = data.impayes || [0, 0, 0, 0, 0, 0];
        
        chartFrais = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    { label: 'Payé', data: payes, borderColor: C.forest, backgroundColor: 'rgba(30,58,47,0.1)', fill: true, tension: 0.4, pointRadius: 3, pointBackgroundColor: C.forest },
                    { label: 'Impayé', data: impayes, borderColor: C.terra, backgroundColor: 'rgba(184,92,56,0.1)', fill: true, tension: 0.4, pointRadius: 3, pointBackgroundColor: C.terra }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false }, tooltip: { mode: 'index' } },
                scales: { y: { beginAtZero: true, ticks: { callback: (v) => v + 'k' } } }
            }
        });
    } catch (error) {
        console.error('Erreur Frais:', error);
    }
}

// ─────────────────────────────────────────────────────────────
// 6. ABSENCES FRÉQUENTES
// ─────────────────────────────────────────────────────────────
async function loadAbsencesFrequentes() {
    try {
        const response = await fetch(API.absences);
        const data = await response.json();
        
        const tbody = document.getElementById('tbodyAbsences');
        if (!tbody) return;
        
        if (data.success && data.data && data.data.length) {
            tbody.innerHTML = data.data.map(item => {
                const badgeClass = item.statut === 'Critique' ? 'badge-danger' : 'badge-warning';
                return `
                    <tr style="cursor:pointer;" onclick="showStudentDetail('${escapeHtml(item.nom)}')">
                        <td><strong>${escapeHtml(item.nom)}</strong></td>
                        <td>${escapeHtml(item.classe)}</td>
                        <td>${item.nb}</td>
                        <td><span class="badge ${badgeClass}">${escapeHtml(item.statut)}</span></td>
                    </tr>
                `;
            }).join('');
        } else {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center" style="padding:30px;">Aucune absence ce mois</td></tr>';
        }
    } catch (error) {
        console.error('Erreur Absences:', error);
        const tbody = document.getElementById('tbodyAbsences');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center" style="padding:30px;">Erreur chargement</td></tr>';
        }
    }
}

// ─────────────────────────────────────────────────────────────
// 7. ACTIVITÉ RÉCENTE
// ─────────────────────────────────────────────────────────────
async function loadActivite() {
    try {
        const response = await fetch(API.activite);
        const data = await response.json();
        
        const feed = document.getElementById('activityFeed');
        if (!feed) return;
        
        const icons = { success: 'fa-check-circle', danger: 'fa-exclamation-circle', warning: 'fa-clock', info: 'fa-edit' };
        
        if (data.success && data.data && data.data.length) {
            feed.innerHTML = data.data.map(item => `
                <div class="activity-item">
                    <div class="activity-icon ${item.type}">
                        <i class="fas ${icons[item.type] || 'fa-bell'}"></i>
                    </div>
                    <div class="activity-content">
                        <div class="activity-text">${escapeHtml(item.texte)}</div>
                        <div class="activity-time">${escapeHtml(item.temps)}</div>
                    </div>
                </div>
            `).join('');
        } else {
            feed.innerHTML = '<p class="text-center" style="color:#6c757d; padding:20px;">Aucune activité récente</p>';
        }
    } catch (error) {
        console.error('Erreur Activité:', error);
        const feed = document.getElementById('activityFeed');
        if (feed) {
            feed.innerHTML = '<p class="text-center" style="color:#6c757d; padding:20px;">Erreur chargement</p>';
        }
    }
}

// ─────────────────────────────────────────────────────────────
// 8. ÉVÉNEMENTS DU CALENDRIER (NOUVEAU)
// ─────────────────────────────────────────────────────────────
async function loadCalendarEvents() {
    try {
        const response = await fetch(API.events);
        const data = await response.json();
        
        if (data.success && data.events) {
            calendarEvents = data.events;
            // Re-générer le calendrier avec les événements
            generateCalendar(currentDate);
        } else {
            console.warn('Aucun événement chargé');
            calendarEvents = [];
        }
    } catch (error) {
        console.error('Erreur chargement événements:', error);
        calendarEvents = [];
    }
}

// ─────────────────────────────────────────────────────────────
// 9. CALENDRIER (AMÉLIORÉ AVEC ÉVÉNEMENTS)
// ─────────────────────────────────────────────────────────────
function generateCalendar(date) {
    const grid = document.getElementById('calendarGrid');
    if (!grid) return;
    
    const year = date.getFullYear();
    const month = date.getMonth();
    const today = new Date();
    const firstDay = new Date(year, month, 1);
    const lastDate = new Date(year, month + 1, 0).getDate();
    
    let startOffset = firstDay.getDay() - 1;
    if (startOffset < 0) startOffset = 6;
    
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    let html = days.map(d => '<div class="cal-hd">' + d + '</div>').join('');
    
    for (let i = 0; i < startOffset; i++) html += '<div class="cal-d empty"></div>';
    
    // Récupérer les événements pour le mois en cours
    const monthEvents = calendarEvents.filter(e => {
        if (!e.start) return false;
        const eventDate = new Date(e.start);
        return eventDate.getFullYear() === year && eventDate.getMonth() === month;
    });
    
    // Grouper les événements par jour
    const eventsByDay = {};
    monthEvents.forEach(e => {
        const eventDate = new Date(e.start);
        const day = eventDate.getDate();
        if (!eventsByDay[day]) eventsByDay[day] = [];
        eventsByDay[day].push(e);
    });
    
    for (let d = 1; d <= lastDate; d++) {
        const isToday = d === today.getDate() && month === today.getMonth() && year === today.getFullYear();
        const hasEvent = eventsByDay[d] && eventsByDay[d].length > 0;
        const eventColor = hasEvent ? eventsByDay[d][0].color || C.terra : null;
        
        let cls = 'cal-d';
        if (isToday) cls += ' today';
        if (hasEvent) cls += ' event';
        
        // Ajouter un petit indicateur de couleur
        const dot = hasEvent ? `<span class="cal-dot" style="background:${eventColor}"></span>` : '';
        
        html += `<div class="${cls}" onclick="selectDate(${d})" title="${hasEvent ? eventsByDay[d].map(e => e.title).join(', ') : ''}">
            ${d}${dot}
        </div>`;
    }
    
    grid.innerHTML = html;
    
    // Mettre à jour la liste des événements
    updateEventList(monthEvents);
    
    // Mettre à jour le titre du mois
    const monthNames = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    const monthTitle = document.getElementById('calendarMonthTitle');
    if (monthTitle) {
        monthTitle.textContent = monthNames[month] + ' ' + year;
    }
}

// ─────────────────────────────────────────────────────────────
// 10. LISTE DES ÉVÉNEMENTS
// ─────────────────────────────────────────────────────────────
function updateEventList(events) {
    const eventList = document.getElementById('eventList');
    if (!eventList) return;
    
    if (!events || events.length === 0) {
        eventList.innerHTML = '<div class="event-empty">Aucun événement ce mois</div>';
        return;
    }
    
    // Trier par date
    const sorted = [...events].sort((a, b) => {
        if (!a.start) return 1;
        if (!b.start) return -1;
        return new Date(a.start) - new Date(b.start);
    });
    
    // Limiter à 5 événements pour ne pas surcharger
    const displayEvents = sorted.slice(0, 8);
    
    eventList.innerHTML = displayEvents.map(e => {
        const eventDate = new Date(e.start);
        const day = eventDate.getDate();
        const monthNames = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
        const month = monthNames[eventDate.getMonth()];
        const color = e.color || C.terra;
        
        // Déterminer l'icône selon le type
        let icon = 'fa-calendar-alt';
        if (e.type === 'cours') icon = 'fa-chalkboard-teacher';
        else if (e.type === 'examen') icon = 'fa-file-alt';
        else if (e.type === 'reunion') icon = 'fa-users';
        else if (e.type === 'sortie') icon = 'fa-bus';
        
        return `
            <div class="event-list-item" onclick="showEventDetail('${escapeHtml(e.id)}')" style="cursor:pointer;">
                <div class="event-color-indicator" style="background:${color};width:4px;flex-shrink:0;border-radius:2px;"></div>
                <div style="flex:1;min-width:0;">
                    <div style="display:flex;justify-content:space-between;align-items:center;">
                        <span class="event-desc" style="font-size:13px;font-weight:500;color:#1a1a1a;">
                            <i class="fas ${icon}" style="color:${color};margin-right:6px;font-size:11px;"></i>
                            ${escapeHtml(e.title)}
                        </span>
                        <span class="event-date" style="font-size:11px;color:#6c757d;white-space:nowrap;margin-left:8px;">
                            ${day} ${month}
                            ${e.heureDebut ? ' à ' + e.heureDebut : ''}
                        </span>
                    </div>
                    ${e.description ? `<div style="font-size:11px;color:#6c757d;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${escapeHtml(e.description)}</div>` : ''}
                </div>
            </div>
        `;
    }).join('');
}

// ─────────────────────────────────────────────────────────────
// 11. NAVIGATION DU CALENDRIER
// ─────────────────────────────────────────────────────────────
function prevMonth() {
    currentDate.setMonth(currentDate.getMonth() - 1);
    generateCalendar(currentDate);
    return false;
}

function nextMonth() {
    currentDate.setMonth(currentDate.getMonth() + 1);
    generateCalendar(currentDate);
    return false;
}

function todayMonth() {
    currentDate = new Date();
    generateCalendar(currentDate);
    return false;
}

// ─────────────────────────────────────────────────────────────
// 12. DÉTAIL D'UN ÉVÉNEMENT
// ─────────────────────────────────────────────────────────────
function showEventDetail(eventId) {
    const event = calendarEvents.find(e => e.id === eventId);
    if (!event) {
        if (typeof Swal !== 'undefined') {
            Swal.fire('Information', 'Événement non trouvé', 'info');
        }
        return;
    }
    
    const eventDate = new Date(event.start);
    const dateStr = eventDate.toLocaleDateString('fr-FR', { 
        weekday: 'long', 
        day: 'numeric', 
        month: 'long', 
        year: 'numeric' 
    });
    
    const typeLabels = {
        'cours': 'Cours',
        'examen': 'Examen',
        'reunion': 'Réunion',
        'sortie': 'Sortie',
        'autre': 'Autre'
    };
    
    let details = `
        <div style="text-align:left;font-size:14px;line-height:1.6;">
            <p><strong>📅 Date :</strong> ${dateStr}</p>
            ${event.heureDebut ? `<p><strong>⏰ Heure :</strong> ${event.heureDebut}${event.heureFin ? ' - ' + event.heureFin : ''}</p>` : ''}
            ${event.type ? `<p><strong>📂 Type :</strong> ${typeLabels[event.type] || event.type}</p>` : ''}
            ${event.location ? `<p><strong>📍 Lieu :</strong> ${escapeHtml(event.location)}</p>` : ''}
            ${event.description ? `<p><strong>📝 Description :</strong><br>${escapeHtml(event.description)}</p>` : ''}
            ${event.url ? `<p><strong>🔗 Lien :</strong> <a href="${escapeHtml(event.url)}" target="_blank">${escapeHtml(event.url)}</a></p>` : ''}
        </div>
    `;
    
    if (typeof Swal !== 'undefined') {
        Swal.fire({
            title: event.title || 'Événement',
            html: details,
            icon: 'info',
            confirmButtonText: 'Fermer',
            width: '500px'
        });
    } else {
        alert('Événement: ' + event.title + '\nDate: ' + dateStr);
    }
}

// ─────────────────────────────────────────────────────────────
// 13. JAUGES
// ─────────────────────────────────────────────────────────────
function updateGauges(items) {
    const container = document.getElementById('gaugeContainer');
    if (!container) return;
    
    container.innerHTML = items.map(item => `
        <div class="gauge-item">
            <div class="gauge-val">${Math.round(item.value)}<span style="font-size:12px">%</span></div>
            <div class="gauge-bar">
                <div class="gauge-fill" style="width:${Math.min(100, Math.max(0, item.value))}%; background:${item.color}"></div>
            </div>
            <div class="gauge-lbl">${item.label}</div>
        </div>
    `).join('');
}

// ─────────────────────────────────────────────────────────────
// UTILITAIRES
// ─────────────────────────────────────────────────────────────
function showSpinner() {
    const el = document.getElementById('spinnerOverlay');
    if (el) el.style.display = 'flex';
}

function hideSpinner() {
    const el = document.getElementById('spinnerOverlay');
    if (el) el.style.display = 'none';
}

function setBarWidth(id, percent) {
    const el = document.getElementById(id);
    if (el) {
        setTimeout(() => { 
            el.style.width = Math.min(100, Math.max(0, percent)) + '%'; 
        }, 100);
    }
}

function formatCurrency(value) {
    if (value >= 1000000) return (value / 1000000).toFixed(1) + 'M Ar';
    if (value >= 1000) return (value / 1000).toFixed(0) + 'k Ar';
    return value + ' Ar';
}

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// ─────────────────────────────────────────────────────────────
// INITIALISATION
// ─────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function() {
    console.log('DOM chargé, initialisation du dashboard...');
    initializeApp();
    loadDashboard();
});

function initializeApp() {
    // Menu toggle
    const menuToggle = document.getElementById('menuToggle');
    const sidebar = document.getElementById('sidebar');
    const contentWrapper = document.getElementById('contentWrapper');
    
    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', function() {
            sidebar.classList.toggle('collapsed');
            if (contentWrapper) contentWrapper.classList.toggle('expanded');
        });
    }
    
    // Notifications
    const notifToggle = document.getElementById('notifToggle');
    const notifDropdown = document.getElementById('notifDropdown');
    
    if (notifToggle && notifDropdown) {
        notifToggle.addEventListener('click', function(e) {
            e.stopPropagation();
            notifDropdown.classList.toggle('show');
        });
        
        document.addEventListener('click', function() {
            notifDropdown.classList.remove('show');
        });
    }
    
    // Fullscreen
    const fullscreenToggle = document.getElementById('fullscreenToggle');
    if (fullscreenToggle) {
        fullscreenToggle.addEventListener('click', function() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen();
            } else {
                document.exitFullscreen();
            }
        });
    }
}

// ─────────────────────────────────────────────────────────────
// FONCTIONS GLOBALES POUR LES INTERACTIONS
// ─────────────────────────────────────────────────────────────
window.showStudentDetail = function(name) {
    if (typeof Swal !== 'undefined') {
        Swal.fire('Élève', `Détails de ${name}`, 'info');
    } else {
        alert('Détails de ' + name);
    }
};

window.selectDate = function(day) {
    // Afficher les événements du jour sélectionné
    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();
    const dayEvents = calendarEvents.filter(e => {
        if (!e.start) return false;
        const eventDate = new Date(e.start);
        return eventDate.getFullYear() === year && 
               eventDate.getMonth() === month && 
               eventDate.getDate() === day;
    });
    
    if (dayEvents.length === 0) {
        if (typeof Swal !== 'undefined') {
            Swal.fire('Aucun événement', `Aucun événement prévu le ${day}/${month+1}/${year}`, 'info');
        }
        return;
    }
    
    const eventList = dayEvents.map(e => `• ${escapeHtml(e.title)}${e.heureDebut ? ' (' + e.heureDebut + ')' : ''}`).join('\n');
    if (typeof Swal !== 'undefined') {
        Swal.fire(`Événements du ${day}/${month+1}/${year}`, eventList, 'info');
    } else {
        alert(`Événements du ${day}/${month+1}/${year}:\n${eventList}`);
    }
};

window.showKPIDetail = function(type) {
    const titles = { 
        eleves: 'Total des élèves', 
        classes: 'Classes actives', 
        presence: 'Taux de présence', 
        impayes: 'Frais impayés' 
    };
    if (typeof Swal !== 'undefined') {
        Swal.fire('Détail', titles[type] || 'Information', 'info');
    }
};

// Fonctions de navigation du calendrier (exposées globalement)
window.prevMonth = prevMonth;
window.nextMonth = nextMonth;
window.todayMonth = todayMonth;
window.showEventDetail = showEventDetail;

// Fonctions modales globales
window.closeModal = function() {
    const modal = document.getElementById('bulletinModal');
    if (modal) modal.style.display = 'none';
};

window.saveBulletin = function() {
    if (typeof Swal !== 'undefined') {
        Swal.fire('Info', 'Fonctionnalité à implémenter', 'info');
    }
};

window.closePaymentModal = function() {
    const modal = document.getElementById('paymentModal');
    if (modal) modal.style.display = 'none';
};

window.savePayment = function() {
    if (typeof Swal !== 'undefined') {
        Swal.fire('Info', 'Fonctionnalité à implémenter', 'info');
    }
};

window.updatePaymentInfo = function() {
    // À implémenter
};

window.closeAddBulletinModal = function() {
    const modal = document.getElementById('addBulletinModal');
    if (modal) modal.style.display = 'none';
};

window.saveNewBulletin = function() {
    if (typeof Swal !== 'undefined') {
        Swal.fire('Info', 'Fonctionnalité à implémenter', 'info');
    }
};