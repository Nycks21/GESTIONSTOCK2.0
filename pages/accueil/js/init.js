'use strict';

document.addEventListener('DOMContentLoaded', function() {
    console.log('[Dashboard] Init — Gestion de Stock');
    loadDashboard();

    // Rafraîchissement automatique (optionnel)
    if (DASHBOARD_DEFAULTS.REFRESH_INTERVAL > 0) {
        setInterval(function() {
            if (!document.hidden) {
                loadKpi();
                loadAlerts();
            }
        }, DASHBOARD_DEFAULTS.REFRESH_INTERVAL);
    }
});
