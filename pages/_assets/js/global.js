/* ═══════════════════════════════════════════════════════════════
   global.js — Gestion Scolaire
   Version unifiée — conflits résolus, logiques préservées
   ═══════════════════════════════════════════════════════════════
*/

function formatNumber(value, decimals) {
  decimals = decimals || 2;
  var num = parseFloat(value);
  if (isNaN(num)) return '0,00';

  var fixed = num.toFixed(decimals);
  var parts = fixed.split('.');
  var integerPart = parts[0];
  var decimalPart = parts[1] || '';
  var integerWithSpaces = integerPart.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');

  return integerWithSpaces + ',' + decimalPart;
}

// ============================================================================
// INITIALISATION - ATTENDRE QUE jQuery SOIT CHARGÉ
// ============================================================================

// ✅ Attendre que le DOM soit prêt AVANT d'utiliser jQuery
document.addEventListener('DOMContentLoaded', function () {
  // Vérifier que jQuery est bien chargé
  if (typeof $ !== 'undefined') {
    console.log("🔵 Page chargée - Initialisation GlobalJS");
    initDarkMode();
  } else {
    // Fallback : réessayer après un délai
    setTimeout(function () {
      if (typeof $ !== 'undefined') {
        console.log("🔵 Page chargée (retard) - Initialisation GlobalJS");
        initDarkMode();
      }
    }, 500);
  }
});

(function () {
  'use strict';

  /* ─── Constantes ─────────────────────────────────────────────────── */
  var MOBILE_BP = 768;
  var STORAGE_KEY = 'sidebarCollapsed';

  /* ─── Références DOM ─────────────────────────────────────────────── */
  var sidebar, contentWrapper, mainHeader, overlay;

  /* ─── Utilitaires ────────────────────────────────────────────────── */
  function isMobile() {
    return window.innerWidth <= MOBILE_BP;
  }

  /* ─── Création unique de l'overlay ──────────────────────────────── */
  function createOverlay() {
    overlay = document.getElementById('sidebarOverlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.id = 'sidebarOverlay';
      document.body.appendChild(overlay);
    }
    overlay.addEventListener('click', closeSidebarMobile);
  }

  /* ─── Résolution des références DOM ──────────────────────────────── */
  function resolveDOM() {
    sidebar = document.getElementById('sidebar');
    contentWrapper = document.getElementById('contentWrapper');
    mainHeader = document.querySelector('.main-header');
  }

  /* ══════════════════════════════════════════════════
     MOBILE : slide-in / slide-out
  ══════════════════════════════════════════════════ */
  function openSidebarMobile() {
    if (!sidebar) return;
    sidebar.classList.add('sidebar-open');
    sidebar.classList.remove('sidebar-collapsed');
    if (overlay) overlay.classList.add('visible');
    document.body.style.overflow = 'hidden';
  }

  function closeSidebarMobile() {
    if (!sidebar) return;
    sidebar.classList.remove('sidebar-open');
    if (overlay) overlay.classList.remove('visible');
    document.body.style.overflow = '';
  }

  /* ══════════════════════════════════════════════════
     DESKTOP : collapse 250px ↔ 60px
  ══════════════════════════════════════════════════ */
  function toggleDesktop() {
    if (!sidebar) return;

    var isCollapsed = sidebar.classList.toggle('sidebar-collapsed');

    if (contentWrapper) {
      contentWrapper.classList.toggle('sidebar-collapsed', isCollapsed);
    }

    if (mainHeader) {
      mainHeader.style.left = isCollapsed ? '60px' : '250px';
    }

    try {
      localStorage.setItem(STORAGE_KEY, isCollapsed ? '1' : '0');
    } catch (e) { }
  }

  function restoreDesktopState() {
    if (isMobile()) return;
    try {
      if (localStorage.getItem(STORAGE_KEY) === '1') {
        if (sidebar) sidebar.classList.add('sidebar-collapsed');
        if (contentWrapper) contentWrapper.classList.add('sidebar-collapsed');
        if (mainHeader) mainHeader.style.left = '60px';
      }
    } catch (e) { }
  }

  /* ══════════════════════════════════════════════════
     GESTIONNAIRE BURGER
  ══════════════════════════════════════════════════ */
  function onMenuToggleClick(e) {
    e.preventDefault();
    e.stopPropagation();

    if (!sidebar) resolveDOM();
    if (!sidebar) return;

    if (isMobile()) {
      sidebar.classList.contains('sidebar-open')
        ? closeSidebarMobile()
        : openSidebarMobile();
    } else {
      toggleDesktop();
    }
  }

  // ✅ Attendre que le DOM soit chargé pour ajouter les écouteurs
  document.addEventListener('DOMContentLoaded', function () {
    document.addEventListener('click', function (e) {
      var target = e.target;
      if (!target) return;
      var isToggle = target.id === 'menuToggle' || !!target.closest('#menuToggle');
      if (isToggle) onMenuToggleClick(e);
    });
  });

  function bindNavLinks() {
    if (!sidebar) return;
    sidebar.querySelectorAll('.nav-link').forEach(function (link) {
      link.addEventListener('click', function () {
        if (isMobile()) closeSidebarMobile();
      });
    });
  }

  /* ─── Swipe mobile ──────────────────────────────────────────────── */
  var touchStartX = 0;
  var touchStartY = 0;

  document.addEventListener('touchstart', function (e) {
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
  }, { passive: true });

  document.addEventListener('touchend', function (e) {
    if (!isMobile()) return;
    var dx = e.changedTouches[0].clientX - touchStartX;
    var dy = e.changedTouches[0].clientY - touchStartY;

    if (Math.abs(dy) > Math.abs(dx)) return;

    if (dx < -60) closeSidebarMobile();
    if (dx > 60 && touchStartX < 40) openSidebarMobile();
  }, { passive: true });

  /* ─── Resize ────────────────────────────────────────────────────── */
  var resizeTimer;
  window.addEventListener('resize', function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () {
      if (!isMobile()) {
        closeSidebarMobile();
        restoreDesktopState();
      }
      setTimeout(setActiveMenu, 50);
    }, 100);
  });

  /* ══════════════════════════════════════════════════
     NOTIFICATIONS DROPDOWN
  ══════════════════════════════════════════════════ */
  document.addEventListener('click', function (e) {
    var notifToggle = document.getElementById('notifToggle');
    var notifDropdown = document.getElementById('notifDropdown');
    if (!notifToggle || !notifDropdown) return;

    if (notifToggle.contains(e.target)) {
      e.stopPropagation();
      var isOpen = notifDropdown.classList.toggle('show');
      notifToggle.setAttribute('aria-expanded', String(isOpen));
    } else if (!notifDropdown.contains(e.target)) {
      notifDropdown.classList.remove('show');
      notifToggle.setAttribute('aria-expanded', 'false');
    }
  });

  /* ══════════════════════════════════════════════════
     PLEIN ÉCRAN
  ══════════════════════════════════════════════════ */
  document.addEventListener('click', function (e) {
    if (!e.target) return;
    var fsToggle = e.target.id === 'fullscreenToggle'
      ? e.target
      : e.target.closest('#fullscreenToggle');
    if (!fsToggle) return;

    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen &&
        document.documentElement.requestFullscreen().catch(function () { });
    } else {
      document.exitFullscreen && document.exitFullscreen().catch(function () { });
    }
  });

  /* ══════════════════════════════════════════════════
     GESTION DU MENU ACTIF
  ══════════════════════════════════════════════════ */

  function normalizeMenuPath(value) {
    if (!value) return '';
    try {
      var clean = value.split('?')[0].split('#')[0].replace(/\\/g, '/');
      if (clean.indexOf('://') !== -1) {
        return new URL(clean).pathname.replace(/\/+$/, '').toLowerCase();
      }
      return new URL(clean, window.location.href).pathname.replace(/\/+$/, '').toLowerCase();
    } catch (err) {
      return (value || '').split('?')[0].split('#')[0].replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();
    }
  }

  function setActiveMenu() {
    var currentPath = normalizeMenuPath(window.location.pathname);
    var currentFile = currentPath.split('/').pop() || '';
    var menuLinks = document.querySelectorAll('.sidebar .nav-link, .nav-pills .nav-link');

    menuLinks.forEach(function (link) {
      var href = link.getAttribute('href') || '';
      var hrefPath = normalizeMenuPath(href);
      var hrefFile = hrefPath ? hrefPath.split('/').pop() : '';
      var menuCode = (link.getAttribute('data-menu') || '').toLowerCase();
      var pageCode = currentFile.replace(/\.aspx$/i, '').replace(/\.html$/i, '');

      var isCurrent = false;

      if (hrefPath && (currentPath === hrefPath || currentPath.endsWith(hrefPath) || hrefPath.endsWith(currentPath))) {
        isCurrent = true;
      }

      if (!isCurrent && hrefFile && hrefFile === currentFile) {
        isCurrent = true;
      }

      if (!isCurrent && menuCode) {
        if (menuCode === pageCode || currentPath.indexOf('/' + menuCode + '/') !== -1 || currentPath.indexOf(menuCode) !== -1) {
          isCurrent = true;
        }
      }

      link.classList.toggle('active', isCurrent);
      if (isCurrent) {
        link.setAttribute('aria-current', 'page');
      } else {
        link.removeAttribute('aria-current');
      }
    });

    var activeLink = document.querySelector('.sidebar .nav-link.active, .nav-pills .nav-link.active');
    if (activeLink) {
      activeLink.setAttribute('aria-current', 'page');
    }
  }

  document.addEventListener('click', function (e) {
    var navLink = e.target && (e.target.closest('.sidebar .nav-link') || e.target.closest('.nav-pills .nav-link'));
    if (!navLink) return;

    document.querySelectorAll('.sidebar .nav-link, .nav-pills .nav-link').forEach(function (link) {
      link.classList.remove('active');
      link.removeAttribute('aria-current');
    });

    navLink.classList.add('active');
    navLink.setAttribute('aria-current', 'page');
  });

  function addMenuHoverEffect() {
    var menuLinks = document.querySelectorAll('.sidebar .nav-link');
    for (var i = 0; i < menuLinks.length; i++) {
      var link = menuLinks[i];
      link.removeEventListener('mouseenter', onMenuMouseEnter);
      link.removeEventListener('mouseleave', onMenuMouseLeave);
      link.addEventListener('mouseenter', onMenuMouseEnter);
      link.addEventListener('mouseleave', onMenuMouseLeave);
    }
  }

  function onMenuMouseEnter() {
    if (!this.classList.contains('active')) {
      this.style.backgroundColor = '#e9ecef';
      this.style.transition = 'all 0.2s';
    }
  }

  function onMenuMouseLeave() {
    if (!this.classList.contains('active')) {
      this.style.backgroundColor = '';
    }
  }

  /* ══════════════════════════════════════════════════
     BADGE VERSION
  ══════════════════════════════════════════════════ */
  function injectVersionBadge() {
    var version = document.body ? document.body.getAttribute('data-version') : null;
    if (!version || document.getElementById('appVersionBadge')) return;

    var badge = document.createElement('div');
    badge.id = 'appVersionBadge';
    badge.textContent = 'v' + version;
    document.body.appendChild(badge);
  }

  /* ══════════════════════════════════════════════════
     INITIALISATION
  ══════════════════════════════════════════════════ */
  function init() {
    resolveDOM();
    createOverlay();
    restoreDesktopState();
    bindNavLinks();
    injectVersionBadge();

    setTimeout(function () {
      setActiveMenu();
      addMenuHoverEffect();
    }, 100);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  window.setActiveMenu = setActiveMenu;
  window.refreshActiveMenu = function () {
    setTimeout(setActiveMenu, 50);
  };
})();

/* ══════════════════════════════════════════════════
   i18n — Exposé globalement
══════════════════════════════════════════════════ */
var i18n = {};

function loadLang(lang) {
  lang = lang || localStorage.getItem('appLang') || 'fr';
  fetch(apiUrl('/_assets/lang/' + lang + '.json'))
    .then(function (r) { return r.json(); })
    .then(function (data) {
      i18n = data;
      localStorage.setItem('appLang', lang);
      applyTranslations();
    })
    .catch(function () { });
}

function applyTranslations() {
  document.querySelectorAll('[data-i18n]').forEach(function (el) {
    var key = el.getAttribute('data-i18n');
    var keys = key.split('.');
    var val = i18n;
    for (var i = 0; i < keys.length; i++) {
      val = val && val[keys[i]];
    }
    if (val) el.textContent = val;
  });
}

// ─────────────────────────────────────────────
// SPINNER - Version unifiée
// ─────────────────────────────────────────────
// ✅ Éviter la duplication
if (!window._spinnerDefined) {
  window._spinnerDefined = true;

  function forceHideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none';
    s.style.visibility = 'hidden';
    s.style.opacity = '0';
    s.setAttribute('aria-hidden', 'true');
  }

  function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.opacity = '1';
    s.style.visibility = 'visible';
    s.style.display = 'flex';
    s.removeAttribute('aria-hidden');
  }

  function hideSpinner() {
    forceHideSpinner();
  }

  window.forceHideSpinner = forceHideSpinner;
  window.showSpinner = showSpinner;
  window.hideSpinner = hideSpinner;
}

function ajax(url, payload) {
  return fetch(apiUrl(url), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify(payload)
  }).then(function (r) {
    if (!r.ok) throw new Error('Erreur HTTP ' + r.status);
    return r.json();
  });
}

function updateSortieBadge(pending) {
  var badge = document.getElementById('sortiePendingCount');
  if (!badge) return;

  function render(value) {
    var count = Number(value || 0);
    badge.textContent = count > 0 ? String(count) : '';
    badge.style.display = count > 0 ? 'inline-flex' : 'none';
  }

  if (pending !== undefined && pending !== null) {
    render(pending);
    return;
  }

  fetch(apiUrl('/pages/modules/sorties/handlers/GetSortieStats.ashx'))
    .then(function (response) {
      if (!response.ok) throw new Error('Erreur HTTP ' + response.status);
      return response.json();
    })
    .then(function (data) {
      if (data.success) render(data.pending);
    })
    .catch(function () { });
}
window.updateSortieBadge = updateSortieBadge;

document.addEventListener('DOMContentLoaded', function () {
  updateSortieBadge();
});

// ============================================================================
// CONSTRUCTION D'URL SÉCURISÉE (ANTI MIXED-CONTENT)
// ============================================================================
// ✅ BUG CORRIGÉ : derrière un tunnel ngrok (ngrok http PORT), le serveur
// IIS local tourne en HTTP et ne sait pas qu'il est exposé en HTTPS.
// Toute URL absolue construite côté serveur (redirections, en-têtes Location,
// liens générés) ou résolue dans certains contextes navigateur peut donc
// hériter du scheme "http://" alors que la page est chargée en "https://",
// ce qui déclenche un blocage "Mixed Content".
//
// apiUrl() reconstruit systématiquement l'URL avec le PROTOCOLE ET L'HÔTE
// RÉELS de la page actuelle (window.location), quel que soit le scheme
// d'origine du chemin fourni. Cela neutralise le problème à la source,
// peu importe d'où vient l'incohérence (cache, proxy, réponse serveur...).
function apiUrl(path) {
  if (!path) return path;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  // Détection automatique si BASE_PATH n'est pas défini
  if (typeof window.BASE_PATH === 'undefined') {
    var path = window.location.pathname;
    var match = path.match(/^(.*?)\/pages\//);
    window.BASE_PATH = match ? match[1] + '/' : '';
  }

  var base = window.BASE_PATH || '';
  if (path.startsWith('/')) {
    // Si base se termine par '/', on l'enlève pour éviter un double slash
    if (base.endsWith('/')) base = base.slice(0, -1);
    return window.location.origin + base + path;
  }
  // Chemin relatif : résolution standard
  return new URL(path, window.location.href).toString();
}
window.apiUrl = apiUrl;

// ✅ Garde-fou supplémentaire : intercepter fetch() pour réécrire
// automatiquement toute requête http:// vers https:// quand la page est
// elle-même chargée en https://. Cela protège même les appels qui auraient
// été oubliés lors d'une mise à jour future du code, sans rien casser
// pour les requêtes déjà correctes.
(function patchFetchForMixedContent() {
  if (window._fetchPatchedForHttps) return;
  window._fetchPatchedForHttps = true;

  var originalFetch = window.fetch;
  window.fetch = function (input, init) {
    try {
      if (window.location.protocol === 'https:' && typeof input === 'string' && input.indexOf('http://') === 0) {
        console.warn('⚠️ Requête http:// interceptée et corrigée en https:// →', input);
        input = 'https://' + input.substring('http://'.length);
      }
    } catch (e) { /* ignorer et laisser fetch gérer l'erreur normalement */ }
    return originalFetch.call(this, input, init);
  };
})();

// ============================================================================
// MODE SOMBRE (DARK MODE)
// ============================================================================

function initDarkMode() {
  const toggle = document.getElementById('toggleDarkMode');
  if (!toggle) return;

  const savedMode = localStorage.getItem('darkMode');
  if (savedMode === 'enabled') {
    document.body.classList.add('dark-mode');
    toggle.checked = true;
  }

  toggle.addEventListener('change', function () {
    if (this.checked) {
      document.body.classList.add('dark-mode');
      localStorage.setItem('darkMode', 'enabled');
    } else {
      document.body.classList.remove('dark-mode');
      localStorage.setItem('darkMode', 'disabled');
    }
  });
}

// ============================================================================
// TREE VIEW / ACCORDÉON
// ============================================================================

function initTreeview() {
  var treeviewToggles = document.querySelectorAll('.treeview-toggle');

  for (var i = 0; i < treeviewToggles.length; i++) {
    var toggle = treeviewToggles[i];
    toggle.removeEventListener('click', handleTreeviewClick);
    toggle.addEventListener('click', handleTreeviewClick);
  }

  var activeLink = document.querySelector('.nav-treeview .nav-link.active');
  if (activeLink) {
    var parentTreeview = activeLink.closest('.has-treeview');
    if (parentTreeview) {
      parentTreeview.classList.add('open');
    }
  }
}

function handleTreeviewClick(e) {
  e.preventDefault();
  e.stopPropagation();

  var parentItem = this.closest('.has-treeview');
  if (parentItem) {
    parentItem.classList.toggle('open');
  }
}

// ✅ Initialiser Treeview après chargement du DOM
document.addEventListener('DOMContentLoaded', function () {
  initTreeview();
  // initDarkMode est déjà appelé plus haut
});

// ============================================================================
// MAINTENANCE - 2 VÉRIFICATIONS UNIQUEMENT (VERSION UNIFIÉE GLOBALE)
// ============================================================================

const API_BASE = '/pages/administrations/utilisateur/api/BackupDatabase.aspx';
let countdownTimer = null;
let isBannerShown = false;

// ─── DÉMARRAGE : 2 VÉRIFICATIONS ────────────────────────────────────
function startMaintenanceChecker() {
  // ✅ Éviter les doublons
  if (window._maintenanceInitialized) {
    console.log('⚠️ Maintenance déjà initialisée, ignoré');
    return;
  }
  window._maintenanceInitialized = true;

  console.log('🔍 Vérification 1/2 - Immédiate');

  // 1ère vérification immédiate
  checkStatus(1);

  // 2ème vérification après 5 secondes
  setTimeout(() => {
    console.log('🔍 Vérification 2/2 - Après 5s');
    checkStatus(2);
  }, 5000);
}

// ─── VÉRIFICATION UNIQUE ────────────────────────────────────────────
async function checkStatus(checkNumber) {
  try {
    const url = apiUrl(`${API_BASE}?action=check&t=${Date.now()}`);
    const response = await fetch(url);
    const data = await response.json();

    console.log(`📊 Résultat vérification ${checkNumber}/2:`, data);

    // Cas 1: Maintenance exécutée
    if (data.isExecuted) {
      console.log('✅ Maintenance déjà exécutée');
      clearAllBanners();
      return;
    }

    // Cas 2: Maintenance programmée → bannière de déconnexion
    if (data.isMaintenance && data.maintenanceTime) {
      const userRole = document.getElementById('hfUserRole')?.value || '';
      if (userRole !== '0' && !isBannerShown) {
        isBannerShown = true;
        showMaintenanceBanner(data.maintenanceTime);
      }
      removeBanner('blockedBanner');
      return;
    }

    // Cas 3: Blocage actif → bannière de blocage
    if (data.isBlocked && data.remainingSeconds > 0) {
      showBlockedBanner(data.remainingSeconds);
      removeBanner('globalMaintenanceBanner');
      return;
    }

    // Cas 4: Rien → nettoyer
    clearAllBanners();

  } catch (e) {
    console.log('⚠️ Erreur vérification:', e);
  }
}

// ─── NETTOYAGE ──────────────────────────────────────────────────────
function clearAllBanners() {
  removeBanner('globalMaintenanceBanner');
  removeBanner('blockedBanner');
  enableInteractions();
}

function removeBanner(id) {
  const el = document.getElementById(id);
  if (el) el.remove();
}

function enableInteractions() {
  document.querySelectorAll('button, a, input, select, .nav-link, .btn').forEach(el => {
    el.style.pointerEvents = '';
    el.style.opacity = '';
  });
}

function disableInteractions() {
  document.querySelectorAll('button, a, input, select, .nav-link, .btn').forEach(el => {
    el.style.pointerEvents = 'none';
    el.style.opacity = '0.5';
  });
}

// ─── BANNIÈRE MAINTENANCE ──────────────────────────────────────────
function showMaintenanceBanner(maintenanceTime) {
  if (document.getElementById('globalMaintenanceBanner')) return;

  const version = document.querySelector('[data-version]')?.getAttribute('data-version') || '2.1.17';
  const banner = createBannerElement('globalMaintenanceBanner');

  banner.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
            <div style="display: flex; align-items: center; gap: 14px;">
                <i class="fas fa-database" style="font-size: 28px; color: #ffc107;"></i>
                <div>
                    <div style="font-weight: bold; font-size: 16px; color: #ffc107;">⚠️ MAINTENANCE PROGRAMMÉE</div>
                    <div style="font-size: 13px; opacity: 0.9;">Sauvegarde de la base de données</div>
                </div>
            </div>
            <div style="display: flex; align-items: center; gap: 20px;">
                <div style="text-align: center;">
                    <div style="font-size: 10px; opacity: 0.8;">Déconnexion à</div>
                    <div style="font-size: 14px; font-weight: bold;">${maintenanceTime}</div>
                </div>
                <div style="width: 1px; height: 40px; background: rgba(255,255,255,0.3);"></div>
                <div style="text-align: center;">
                    <div style="font-size: 10px; opacity: 0.8;">Temps restant</div>
                    <div id="countdownDisplay" style="font-size: 32px; font-weight: bold; font-family: monospace; color: #ffc107;">--:--:--</div>
                </div>
                <div style="width: 1px; height: 40px; background: rgba(255,255,255,0.3);"></div>
                <div style="text-align: center;">
                    <div style="font-size: 10px; opacity: 0.7;">Version</div>
                    <div style="font-weight: bold; font-size: 14px;">v${version}</div>
                </div>
            </div>
        </div>
        <div style="width: 100%; height: 4px; background: rgba(255,255,255,0.2); border-radius: 4px; margin-top: 10px; overflow: hidden;">
            <div id="progressBar" style="width: 0%; height: 100%; background: linear-gradient(90deg, #ffc107, #28a745); transition: width 1s linear;"></div>
        </div>
    `;

  document.body.appendChild(banner);
  startCountdown(maintenanceTime);
  injectStyles();
}

// ─── BANNIÈRE BLOCAGE ──────────────────────────────────────────────
function showBlockedBanner(remainingSeconds) {
  const isLoginPage = window.location.pathname.includes('Login.aspx');

  let banner = document.getElementById('blockedBanner');
  if (banner) {
    updateBlockBanner(remainingSeconds);
    return;
  }

  banner = createBannerElement('blockedBanner', '#dc3545');
  banner.innerHTML = `
        <div style="display: flex; align-items: center; justify-content: center; gap: 20px; flex-wrap: wrap;">
            <i class="fas fa-lock" style="font-size: 28px;"></i>
            <div>
                <strong style="font-size: 16px;">🔒 COMPTE TEMPORAIREMENT BLOQUÉ</strong><br>
                <span style="font-size: 13px;">Maintenance en cours. Réessayez dans</span>
            </div>
            <div style="background: rgba(255,255,255,0.2); padding: 8px 20px; border-radius: 50px;">
                <span id="blockCountdown" style="font-size: 32px; font-weight: bold; font-family: monospace;">${remainingSeconds}s</span>
            </div>
        </div>
        <div style="width: 100%; height: 4px; background: rgba(255,255,255,0.3); border-radius: 4px; margin-top: 10px;">
            <div id="blockProgress" style="width: ${(1 - remainingSeconds / 60) * 100}%; height: 100%; background: #ffc107; transition: width 1s linear;"></div>
        </div>
    `;

  document.body.appendChild(banner);

  if (!isLoginPage) {
    disableInteractions();
  }

  startBlockCountdown(remainingSeconds);
  injectStyles();
}

// ─── UTILITAIRES ────────────────────────────────────────────────────
function createBannerElement(id, bgColor = 'linear-gradient(135deg, #dc3545 0%, #c82333 100%)') {
  const banner = document.createElement('div');
  banner.id = id;
  banner.style.cssText = `
        position: fixed;
        bottom: 0;
        left: 0;
        right: 0;
        background: ${bgColor};
        color: white;
        padding: 14px 20px;
        z-index: 99999;
        font-family: 'Segoe UI', Arial, sans-serif;
        box-shadow: 0 -4px 20px rgba(0,0,0,0.3);
        animation: slideUp 0.5s ease;
        border-top: 3px solid #ffc107;
    `;
  return banner;
}

function injectStyles() {
  if (document.getElementById('maintenanceStyles')) return;
  const style = document.createElement('style');
  style.id = 'maintenanceStyles';
  style.textContent = `
        @keyframes slideUp {
            from { transform: translateY(100%); opacity: 0; }
            to { transform: translateY(0); opacity: 1; }
        }
        @keyframes pulseAlert {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.6; }
        }
    `;
  document.head.appendChild(style);
}

// ─── COMPTEURS ──────────────────────────────────────────────────────
function startCountdown(targetTime) {
  if (countdownTimer) clearInterval(countdownTimer);

  const target = new Date();
  const [hours, minutes] = targetTime.split(':');
  target.setHours(parseInt(hours), parseInt(minutes), 0, 0);
  if (target < new Date()) target.setDate(target.getDate() + 1);

  countdownTimer = setInterval(() => {
    const diff = target - new Date();

    if (diff <= 0) {
      clearInterval(countdownTimer);
      handleDisconnect();
    } else {
      const h = Math.floor(diff / 3600000);
      const m = Math.floor((diff % 3600000) / 60000);
      const s = Math.floor((diff % 60000) / 1000);

      const el = document.getElementById('countdownDisplay');
      const progress = document.getElementById('progressBar');

      if (el) {
        el.textContent = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
        if (diff < 60000) {
          el.style.animation = 'pulseAlert 0.5s infinite';
          el.style.color = '#ff6b6b';
        }
      }
      if (progress) {
        const totalSec = Math.floor(diff / 1000);
        progress.style.width = `${Math.min(100, (1 - totalSec / 86400) * 100)}%`;
      }
    }
  }, 1000);
}

function startBlockCountdown(seconds) {
  if (countdownTimer) clearInterval(countdownTimer);

  let remaining = seconds;
  const MAX = 60;

  countdownTimer = setInterval(() => {
    remaining--;
    const el = document.getElementById('blockCountdown');
    const progress = document.getElementById('blockProgress');

    if (el) el.textContent = remaining + 's';
    if (progress) {
      progress.style.width = `${Math.min(100, ((MAX - remaining) / MAX) * 100)}%`;
    }

    if (remaining <= 0) {
      clearInterval(countdownTimer);
      removeBanner('blockedBanner');
      enableInteractions();
      if (window.location.pathname.includes('Login.aspx')) {
        window.location.reload();
      }
    }
  }, 1000);
}

function updateBlockBanner(remaining) {
  const el = document.getElementById('blockCountdown');
  const progress = document.getElementById('blockProgress');
  if (el) el.textContent = remaining + 's';
  if (progress) {
    progress.style.width = `${Math.min(100, ((60 - remaining) / 60) * 100)}%`;
  }
}

// ─── DÉCONNEXION ──────────────────────────────────────────────────
function handleDisconnect() {
  const banner = document.getElementById('globalMaintenanceBanner');
  if (banner) {
    banner.style.background = '#28a745';
    banner.innerHTML = `
            <div style="display: flex; align-items: center; justify-content: center; gap: 20px; padding: 10px;">
                <i class="fas fa-sync-alt fa-spin" style="font-size: 32px;"></i>
                <div style="text-align: center;">
                    <strong style="font-size: 18px;">🔄 MAINTENANCE EN COURS</strong><br>
                    <span style="font-size: 14px;">Sauvegarde de la base de données en cours...</span>
                    <div style="font-size: 13px; margin-top: 5px; opacity: 0.9;">⏳ Redirection...</div>
                </div>
            </div>
        `;
  }

  clearAllBanners();
  setTimeout(() => {
    window.location.href = '../../../auth/Login.aspx?msg=maintenance';
  }, 5000);
}

// ─── EXPOSITION GLOBALE ────────────────────────────────────────────
window.startMaintenanceChecker = startMaintenanceChecker;

// ─── DÉMARRAGE AUTOMATIQUE DE LA MAINTENANCE ──────────────────────
// ✅ Version robuste qui fonctionne sur TOUTES les pages SANS jQuery

function initMaintenance() {
  if (window._maintenanceInitialized) {
    return;
  }

  // Attendre que le DOM soit prêt
  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    setTimeout(startMaintenanceChecker, 300);
  } else {
    document.addEventListener('DOMContentLoaded', function () {
      setTimeout(startMaintenanceChecker, 300);
    });
  }
}

// Démarrer la maintenance
initMaintenance();

// Fallback après 3 secondes si pas démarré
setTimeout(function () {
  if (!window._maintenanceInitialized) {
    console.log('🔵 Forçage maintenance (fallback)');
    startMaintenanceChecker();
  }
}, 3000);

// ============================================================================
// GESTION DES MODALS
// ============================================================================

function openModal(id) {
  const modal = document.getElementById(id);
  if (modal) {
    modal.style.display = 'flex';
    document.body.style.overflow = 'hidden';
    if (id === 'editHistoriqueModal') {
      modal.style.zIndex = '999999';
    } else {
      modal.style.zIndex = '9999';
    }
    const modalContent = modal.querySelector('.modal-content');
    if (modalContent) {
      modalContent.style.zIndex = modal.style.zIndex;
    }
  }
}

function closeModal(id) {
  const modal = document.getElementById(id);
  if (modal) {
    modal.style.display = 'none';
    const anyOpen = ['paymentModal', 'editHistoriqueModal', 'tarifModal', 'restoreModal'].some(function (mid) {
      const m = document.getElementById(mid);
      return m && m.style.display === 'flex';
    });
    if (!anyOpen) {
      document.body.style.overflow = '';
    }
  }
}

// ============================================
// GESTION DU SÉLECTEUR DE LANGUE - VERSION .NET 4.0
// ============================================
document.addEventListener('DOMContentLoaded', function () {
  console.log('🔍 Initialisation du sélecteur de langue...');

  // Récupérer tous les sélecteurs
  var selectors = document.querySelectorAll('.language-selector');
  console.log('📦 Sélecteurs trouvés:', selectors.length);

  for (var i = 0; i < selectors.length; i++) {
    var selector = selectors[i];
    var btn = selector.querySelector('.btn');
    var dropdown = selector.querySelector('.dropdown-menu');

    if (btn && dropdown) {
      console.log('✅ Sélecteur ' + i + ' initialisé');

      // Toggle du dropdown - utiliser une closure pour conserver la référence
      (function (btnRef, dropdownRef) {
        btnRef.addEventListener('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          dropdownRef.classList.toggle('show');
          console.log('📂 Dropdown toggled:', dropdownRef.classList.contains('show'));
        });
      })(btn, dropdown);
    } else {
      console.warn('⚠️ Sélecteur ' + i + ' incomplet:', {
        btn: !!btn,
        dropdown: !!dropdown
      });
    }
  }

  // Fermer le dropdown si on clique ailleurs
  document.addEventListener('click', function (e) {
    var allDropdowns = document.querySelectorAll('.language-selector .dropdown-menu');
    for (var i = 0; i < allDropdowns.length; i++) {
      var dropdown = allDropdowns[i];
      var parent = dropdown.parentNode;
      if (parent && !parent.contains(e.target)) {
        dropdown.classList.remove('show');
      }
    }
  });

  // ✅ Fonction robuste : conserve les autres paramètres, évite les doublons, valide la culture.
  window.setLanguage = function (culture) {
    if (!culture) return;

    var normalizedCulture = String(culture).trim();
    if (!normalizedCulture) return;

    var supportedCultures = ['fr', 'en', 'mg'];
    var baseCulture = normalizedCulture.replace('_', '-').split('-')[0].toLowerCase();
    var finalCulture = supportedCultures.indexOf(baseCulture) !== -1 ? baseCulture : 'fr';

    var url = new URL(window.location.href);
    var params = new URLSearchParams(url.search);
    params.delete('lang');
    params.set('lang', finalCulture);
    url.search = params.toString();

    window.location.href = url.toString();
  };

  console.log('✅ Sélecteur de langue initialisé');
});

// ... (contenu existant jusqu'à la fin) ...

// ============================================================================
// AJOUTS POUR LE MODULE ARTICLES (CRUD)
// ============================================================================

/**
 * fetchJsonSafe - Appel fetch robuste avec gestion des sessions et du JSON.
 */
if (typeof window.fetchJsonSafe !== 'function') {
  window.fetchJsonSafe = async function (url, options = {}) {
    const response = await fetch(url, {
      ...options,
      credentials: 'include',
      headers: {
        'Content-Type': options && options.body && typeof options.body === 'string'
          ? 'application/json; charset=utf-8'
          : (options.headers && options.headers['Content-Type']) || 'application/json; charset=utf-8',
        'X-Requested-With': 'XMLHttpRequest',
        ...(options.headers || {})
      }
    });

    // Gestion des sessions expirées
    if (response.status === 401 || response.status === 403) {
      if (typeof Swal !== 'undefined') {
        await Swal.fire({
          icon: 'warning',
          title: 'Session expirée',
          text: 'Votre session a expiré. Veuillez vous reconnecter.',
          confirmButtonText: 'Se reconnecter'
        });
      }
      window.location.href = '/auth/Login.aspx?msg=session_expired';
      throw new Error('Session expirée');
    }

    if (!response.ok) {
      const text = await response.text();
      if (text.trim().startsWith('<!DOCTYPE') || text.trim().startsWith('<html')) {
        throw new Error(`Erreur serveur ${response.status} : le serveur a renvoyé une page HTML. Vérifiez les logs serveur.`);
      }
      throw new Error(`Erreur HTTP ${response.status} : ${text.substring(0, 200)}`);
    }

    const contentType = response.headers.get('content-type') || '';
    if (!contentType.includes('application/json')) {
      const text = await response.text();
      if (text.includes('Login.aspx') || text.includes('login.aspx') || (text.trim().startsWith('<') && response.url.includes('Login'))) {
        window.location.href = '/auth/Login.aspx?msg=session_expired';
        throw new Error('Session expirée - redirection vers login');
      }
      console.error('Réponse non JSON (Content-Type:', contentType, '):', text.substring(0, 500));
      throw new Error('Le serveur a renvoyé une réponse non JSON. Vérifiez l\'état du serveur.');
    }

    try {
      return await response.json();
    } catch (e) {
      const text = await response.text();
      console.error('Erreur de parsing JSON :', text.substring(0, 500));
      throw new Error('Réponse JSON invalide.');
    }
  };
}

/**
 * showErrorToast - Affiche une notification d'erreur (toast).
 */
if (typeof window.showErrorToast !== 'function') {
  window.showErrorToast = function (message, title) {
    if (typeof Swal !== 'undefined') {
      Swal.mixin({
        toast: true,
        position: 'top-end',
        showConfirmButton: false,
        timer: 4000,
        timerProgressBar: true,
        icon: 'error',
        title: title || 'Erreur',
        text: message
      }).fire();
    } else {
      alert('Erreur: ' + message);
    }
  };
}

/**
 * escapeHtml - Échappe les caractères HTML pour prévenir XSS.
 */
if (typeof window.escapeHtml !== 'function') {
  window.escapeHtml = function (str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  };
}

/**
 * setVal / getVal - Gestion simplifiée des champs de formulaire.
 */
if (typeof window.setVal !== 'function') {
  window.setVal = function (id, value) {
    var el = document.getElementById(id);
    if (el) {
      if (el.tagName === 'SELECT' || el.type === 'text' || el.type === 'number' || el.type === 'password' || el.type === 'hidden' || el.tagName === 'TEXTAREA') {
        el.value = value !== undefined && value !== null ? value : '';
      } else if (el.type === 'checkbox' || el.type === 'radio') {
        el.checked = !!value;
      }
    }
  };
}

if (typeof window.getVal !== 'function') {
  window.getVal = function (id) {
    var el = document.getElementById(id);
    if (!el) return '';
    if (el.type === 'checkbox' || el.type === 'radio') {
      return el.checked ? (el.value || 'on') : '';
    }
    return el.value || '';
  };
}

/**
 * clearFieldErrors - Efface les messages d'erreur sous les champs.
 */
if (typeof window.clearFieldErrors !== 'function') {
  window.clearFieldErrors = function (ids) {
    if (!ids) return;
    var idsArray = Array.isArray(ids) ? ids : [ids];
    idsArray.forEach(function (id) {
      var errorEl = document.getElementById(id + '_error');
      if (errorEl) errorEl.textContent = '';
      var field = document.getElementById(id);
      if (field) field.classList.remove('is-invalid');
    });
  };
}

/**
 * showFieldError - Affiche un message d'erreur sous un champ.
 */
if (typeof window.showFieldError !== 'function') {
  window.showFieldError = function (id, message) {
    var field = document.getElementById(id);
    if (field) field.classList.add('is-invalid');
    var errorEl = document.getElementById(id + '_error');
    if (errorEl) {
      errorEl.textContent = message;
      errorEl.style.color = '#dc3545';
      errorEl.style.fontSize = '0.875em';
    } else {
      // Créer l'élément d'erreur s'il n'existe pas
      var parent = field ? field.parentNode : null;
      if (parent) {
        var newError = document.createElement('div');
        newError.id = id + '_error';
        newError.className = 'invalid-feedback';
        newError.textContent = message;
        parent.appendChild(newError);
      }
    }
  };
}

/**
 * Stubs pour les fonctions du module articles (peuvent être redéfinies).
 */
if (typeof window.updateStatsCards !== 'function') {
  window.updateStatsCards = function () {
    // Peut être redéfini dans la page
  };
}
if (typeof window.renderTable !== 'function') {
  window.renderTable = function () {
    // Peut être redéfini dans la page
  };
}
if (typeof window.applyFilters !== 'function') {
  window.applyFilters = function () {
    // Peut être redéfini dans la page
  };
}

// ============================================================================
// EXPOSITION GLOBALE
// ============================================================================
// Fonctions existantes
window.ajax = ajax;
window.loadLang = loadLang;
window.initDarkMode = initDarkMode;
window.openModal = openModal;
window.closeModal = closeModal;

// Fonctions pour le module articles (CRUD) – ajoutées sans écraser
window.fetchJsonSafe = window.fetchJsonSafe;
window.showErrorToast = window.showErrorToast;
window.escapeHtml = window.escapeHtml;
window.setVal = window.setVal;
window.getVal = window.getVal;
window.clearFieldErrors = window.clearFieldErrors;
window.showFieldError = window.showFieldError;
window.updateStatsCards = window.updateStatsCards;
window.renderTable = window.renderTable;
window.applyFilters = window.applyFilters;
