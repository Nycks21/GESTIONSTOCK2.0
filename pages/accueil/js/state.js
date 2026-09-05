'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// ÉTAT GLOBAL — Module Dashboard
// ─────────────────────────────────────────────────────────────────────────────

var chartPresence = null;
var chartDonut = null;
var chartFrais = null;
var currentDate = new Date();
var calendarEvents = [];
var dashboardData = {
    kpi: null,
    presences: null,
    repartition: null,
    reussite: null,
    frais: null,
    absences: null,
    activite: null
};