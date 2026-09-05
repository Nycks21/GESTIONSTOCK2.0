'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// INITIALISATION — Module Dashboard
// ─────────────────────────────────────────────────────────────────────────────

function init() {
    console.log('DOM chargé, initialisation du dashboard...');
    initializeUI();
    loadDashboard();
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPOSITION GLOBALE
// ─────────────────────────────────────────────────────────────────────────────

Object.assign(window, {
    // Configuration
    API_DASHBOARD: API_DASHBOARD,
    COLORS: COLORS,

    // État
    chartPresence: chartPresence,
    chartDonut: chartDonut,
    chartFrais: chartFrais,
    currentDate: currentDate,
    calendarEvents: calendarEvents,
    dashboardData: dashboardData,

    // Utilitaires
    escapeHtml: escapeHtml,
    formatCurrency: formatCurrency,
    showToast: showToast,
    showLoading: showLoading,
    hideLoading: hideLoading,
    setBarWidth: setBarWidth,

    // UI
    initializeUI: initializeUI,
    activateDashboardLink: activateDashboardLink,
    showStudentDetail: showStudentDetail,
    showKPIDetail: showKPIDetail,

    // Graphiques
    initChartPresence: initChartPresence,
    initChartDonut: initChartDonut,
    initChartFrais: initChartFrais,
    destroyAllCharts: destroyAllCharts,

    // KPI
    updateKPI: updateKPI,
    updateGauges: updateGauges,
    updateGenderRepartition: updateGenderRepartition,

    // Calendrier
    generateCalendar: generateCalendar,
    updateEventList: updateEventList,
    showEventDetail: showEventDetail,
    selectDate: selectDate,
    prevMonth: prevMonth,
    nextMonth: nextMonth,
    todayMonth: todayMonth,

    // Loaders
    loadDashboard: loadDashboard,
    loadKPI: loadKPI,
    loadPresences: loadPresences,
    loadRepartition: loadRepartition,
    loadReussite: loadReussite,
    loadFrais: loadFrais,
    loadAbsencesFrequentes: loadAbsencesFrequentes,
    loadActivite: loadActivite,
    loadCalendarEvents: loadCalendarEvents,

    // Initialisation
    init: init
});

// ─────────────────────────────────────────────────────────────
// DÉMARRAGE
// ─────────────────────────────────────────────────────────────

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}