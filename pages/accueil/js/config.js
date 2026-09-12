'use strict';

window.DASHBOARD_API = {
    KPI:            'index.aspx?action=kpi',
    ALERTS:         'index.aspx?action=alerts',
    MOVEMENTS:      'index.aspx?action=movements',
    STOCK_CATEGORY: 'index.aspx?action=stockByCategory',
    RECENT_MVT:     'index.aspx?action=recentMovements',
    RECENT_DOCS:    'index.aspx?action=recentDocuments',
    TOP_ARTICLES:   'index.aspx?action=topArticles'
};

window.DASHBOARD_COLORS = {
    primary:  '#007bff',
    success:  '#28a745',
    danger:   '#dc3545',
    warning:  '#ffc107',
    gold:     '#c9a84c',
    info:     '#17a2b8',
    palette:  ['#007bff', '#28a745', '#ffc107', '#dc3545', '#17a2b8', '#6f42c1', '#fd7e14', '#20c997']
};

window.DASHBOARD_DEFAULTS = {
    REFRESH_INTERVAL: 60000  // 1 minute (0 = désactivé)
};
