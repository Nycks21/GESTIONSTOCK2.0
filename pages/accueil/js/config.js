'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURATION — Module Dashboard
// ─────────────────────────────────────────────────────────────────────────────

var API_DASHBOARD = {
    kpi: 'handlers/GetKPI.ashx',
    presence: 'handlers/GetPresences.ashx',
    repartition: 'handlers/GetRepartition.ashx',
    reussite: 'handlers/GetReussite.ashx',
    frais: 'handlers/GetFrais.ashx',
    absences: 'handlers/GetAbsencesFrequentes.ashx',
    activite: 'handlers/GetActivite.ashx',
    events: 'handlers/GetEvents.ashx'
};

// Couleurs principales
var COLORS = {
    forest: '#1e3a2f',
    forestLight: '#3d6b54',
    terra: '#b85c38',
    gold: '#c9a84c',
    cream: '#f5f0e8',
    grey: '#6c757d',
    blue: '#17a2b8'
};