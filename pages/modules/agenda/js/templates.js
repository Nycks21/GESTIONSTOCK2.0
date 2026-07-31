'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATES — Module Agenda
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// AJOUTER UN ÉVÉNEMENT DEPUIS UN TEMPLATE
// ─────────────────────────────────────────────────────────────────────────────

async function addEventFromTemplate(templateId) {
    showLoading('Création de l\'événement...');
    
    try {
        var response = await fetch(API_AGENDA.addEventFromTemplate, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                templateId: templateId
            })
        });
        
        var data = await response.json();
        
        if (data.success) {
            showToast('Événement ajouté avec succès', 'success');
            // ✅ Recharger uniquement le calendrier
            await refreshCalendar();
        } else {
            showToast(data.message || 'Erreur lors de l\'ajout', 'error');
        }
        hideLoading();
    } catch (e) {
        console.error('Erreur:', e);
        showToast('Erreur de connexion', 'error');
        hideLoading();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// AJOUTER UN ÉVÉNEMENT DEPUIS LA SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────

function addEventFromSidebar() {
    var input = document.getElementById('new-event');
    if (!input) return;
    
    var title = input.value.trim();
    
    if (title.length === 0) {
        showToast('Veuillez saisir un titre', 'warning');
        return;
    }
    
    var btn = document.getElementById('add-new-event');
    var color = btn ? (btn.dataset.color || '#3c8dbc') : '#3c8dbc';
    
    var container = document.getElementById('external-events');
    if (!container) {
        showToast('Conteneur d\'événements non trouvé', 'error');
        return;
    }
    
    var eventDiv = document.createElement('div');
    eventDiv.className = 'external-event';
    eventDiv.style.backgroundColor = color;
    eventDiv.style.borderColor = color;
    eventDiv.style.color = '#ffffff';
    eventDiv.textContent = title;
    eventDiv.dataset.type = 'autre';
    eventDiv.dataset.publique = 'all';
    
    container.prepend(eventDiv);
    
    if (typeof $ !== 'undefined' && $.fn.draggable) {
        $(eventDiv).draggable({
            zIndex: 1070,
            revert: true,
            revertDuration: 0
        });
    }
    
    input.value = '';
    showToast('Événement ajouté dans la liste', 'success');
}

// ─────────────────────────────────────────────────────────────────────────────
// AFFICHER LES DÉTAILS D'UN ÉVÉNEMENT À VENIR
// ─────────────────────────────────────────────────────────────────────────────

async function showUpcomingEventDetail(eventId) {
    try {
        var response = await fetch(API_AGENDA.getEventDetail + '?id=' + encodeURIComponent(eventId));
        var data = await response.json();
        
        if (!data.success) {
            showToast(data.message || 'Erreur', 'error');
            return;
        }
        
        var event = data.event;
        var color = event.COULEUR || '#007bff';
        var dateStr = formatEventDate(event.DATE_DEBUT);
        var timeStr = event.HEURE_DEBUT ? event.HEURE_DEBUT + (event.HEURE_FIN ? ' - ' + event.HEURE_FIN : '') : 'Journée entière';
        
        var publiqueLabels = {
            'all': 'Tous',
            'eleves': 'Élèves',
            'parents': 'Parents',
            'enseignants': 'Enseignants',
            'personnel': 'Personnel'
        };
        
        Swal.fire({
            title: event.TITRE || 'Événement',
            html: '<div style="text-align:left; padding:10px 0;">' +
                '<div style="display:flex; align-items:center; gap:12px; margin-bottom:12px;">' +
                '<span style="width:20px; height:20px; border-radius:4px; background:' + color + '; display:inline-block;"></span>' +
                '<span style="font-size:13px; color:#6c757d;">' + (event.TYPE || 'Événement') + '</span>' +
                '</div>' +
                '<div style="margin-bottom:8px;"><i class="far fa-calendar-alt" style="width:20px; color:#6c757d;"></i><span style="font-size:14px;">' + dateStr + '</span></div>' +
                '<div style="margin-bottom:8px;"><i class="far fa-clock" style="width:20px; color:#6c757d;"></i><span style="font-size:14px;">' + timeStr + '</span></div>' +
                (event.LIEU ? '<div style="margin-bottom:8px;"><i class="fas fa-map-marker-alt" style="width:20px; color:#6c757d;"></i><span style="font-size:14px;">' + escapeHtml(event.LIEU) + '</span></div>' : '') +
                (event.PUBLIQUE && event.PUBLIQUE !== 'all' ? '<div style="margin-bottom:8px;"><i class="fas fa-users" style="width:20px; color:#6c757d;"></i><span style="font-size:14px;">Public : ' + (publiqueLabels[event.PUBLIQUE] || event.PUBLIQUE) + '</span></div>' : '') +
                (event.URL ? '<div style="margin-bottom:8px;"><i class="fas fa-link" style="width:20px; color:#6c757d;"></i><a href="' + event.URL + '" target="_blank" style="font-size:14px; color:#007bff;">' + event.URL + '</a></div>' : '') +
                (event.DESCRIPTION ? '<div style="margin-top:12px; padding-top:12px; border-top:1px solid #dee2e6;"><div style="font-size:13px; color:#495057;">' + escapeHtml(event.DESCRIPTION) + '</div></div>' : '') +
                '</div>',
            icon: 'info',
            confirmButtonText: 'Fermer',
            confirmButtonColor: '#1e3a2f'
        });
        
    } catch (e) {
        console.error('Erreur:', e);
        showToast('Erreur de connexion', 'error');
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// AFFICHER LES DÉTAILS D'UN ÉVÉNEMENT (dans la modale)
// ─────────────────────────────────────────────────────────────────────────────

function showEventDetail(event) {
    var modal = document.getElementById('detailModal');
    var body = document.getElementById('detailBody');
    if (!modal || !body) return;
    
    var type = event.extendedProps.type || 'autre';
    var description = event.extendedProps.description || '';
    var location = event.extendedProps.location || '';
    var publique = event.extendedProps.publique || 'all';
    var url = event.extendedProps.url || '';
    
    var startDate = new Date(event.start);
    var endDate = event.end ? new Date(event.end) : null;
    
    var publiqueLabels = {
        'all': 'Tous',
        'eleves': 'Élèves',
        'parents': 'Parents',
        'enseignants': 'Enseignants',
        'personnel': 'Personnel'
    };
    
    var html = '<div class="detail-event" style="border-left: 5px solid ' + event.backgroundColor + ';">' +
        '<h4>' + event.title + '</h4>' +
        '<div class="detail-meta">' +
        '<span class="detail-type">' + getTypeLabel(type) + '</span>' +
        '<span class="detail-date">📅 ' + formatEventDate(event.start) + '</span>' +
        (startDate ? '<span class="detail-time">🕐 ' + formatEventTime(event.start) + '</span>' : '') +
        (endDate ? '<span class="detail-time">➜ ' + formatEventTime(event.end) + '</span>' : '') +
        '</div>';
    
    if (location) {
        html += '<div class="detail-location">📍 ' + location + '</div>';
    }
    
    if (publique && publique !== 'all') {
        html += '<div class="detail-audience">👥 Public : ' + (publiqueLabels[publique] || publique) + '</div>';
    }
    
    if (url) {
        html += '<div class="detail-url">🔗 <a href="' + url + '" target="_blank">' + url + '</a></div>';
    }
    
    if (description) {
        html += '<div class="detail-description">' + description + '</div>';
    }
    
    html += '</div>';
    
    body.innerHTML = html;
    
    var editBtn = document.getElementById('btnEditDetail');
    if (editBtn) {
        editBtn.onclick = function() {
            closeDetailModal();
            var eventData = {
                id: event.id,
                title: event.title,
                type: type,
                start: event.start,
                end: event.end,
                description: description,
                color: event.backgroundColor,
                location: location,
                publique: publique,
                url: url
            };
            openEventModal(eventData);
        };
    }
    
    modal.style.display = 'flex';
    modal.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function editDetail() {
    // Fonction appelée via le bouton dans le modal
    // Le onclick est défini dynamiquement dans showEventDetail
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPOSITION GLOBALE
// ─────────────────────────────────────────────────────────────────────────────

window.addEventFromTemplate = addEventFromTemplate;
window.addEventFromSidebar = addEventFromSidebar;
window.showUpcomingEventDetail = showUpcomingEventDetail;
window.showEventDetail = showEventDetail;
window.editDetail = editDetail;