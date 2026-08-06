// js/calendar.js
'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// CALENDRIER — Module Agenda
// ─────────────────────────────────────────────────────────────────────────────

function initCalendar() {
    var calendarEl = document.getElementById('calendar');
    if (!calendarEl) {
        console.error('Element #calendar non trouvé');
        return;
    }
    if (typeof FullCalendar === 'undefined') {
        console.error('FullCalendar non chargé');
        return;
    }

    var Calendar = FullCalendar.Calendar;
    var Draggable = FullCalendar.Draggable;
    var containerEl = document.getElementById('external-events');
    var checkbox = document.getElementById('drop-remove');

    if (containerEl && Draggable) {
        new Draggable(containerEl, {
            itemSelector: '.external-event',
            eventData: function(eventEl) {
                return {
                    title: eventEl.innerText.trim(),
                    backgroundColor: window.getComputedStyle(eventEl, null).getPropertyValue('background-color'),
                    borderColor: window.getComputedStyle(eventEl, null).getPropertyValue('background-color'),
                    textColor: window.getComputedStyle(eventEl, null).getPropertyValue('color'),
                    extendedProps: {
                        type: eventEl.dataset.type || 'autre',
                        location: eventEl.dataset.location || '',
                        publique: eventEl.dataset.publique || 'all'
                    }
                };
            }
        });
    }

    // ✅ Vérifier que calendar n'existe pas déjà
    if (typeof calendar !== 'undefined' && calendar !== null) {
        try {
            calendar.destroy();
        } catch(e) {}
    }

    calendar = new Calendar(calendarEl, {
        headerToolbar: {
            left: 'prev,next today',
            center: 'title',
            right: 'dayGridMonth,timeGridWeek,listWeek'
        },
        locale: 'fr',
        themeSystem: 'bootstrap',
        height: 'auto',
        contentHeight: 'auto',
        buttonText: {
            today: "Aujourd'hui",
            month: 'Mois',
            week: 'Semaine',
            day: 'Jour',
            list: 'Liste'
        },
        events: function(info, successCallback) {
            var events = window._agendaEvents || [];
            successCallback(events);
        },
        eventSources: [],
        eventClick: function(info) {
            if (typeof showEventDetail === 'function') {
                showEventDetail(info.event);
            }
        },
        dateClick: function(info) {
            if (typeof openEventModal === 'function') {
                openEventModal({ date: info.dateStr });
            }
        },
        editable: true,
        droppable: true,
        drop: function(info) {
            if (checkbox && checkbox.checked && info.draggedEl && info.draggedEl.parentNode) {
                info.draggedEl.parentNode.removeChild(info.draggedEl);
            }
            var eventData = {
                title: info.draggedEl.innerText.trim(),
                start: info.dateStr,
                type: info.draggedEl.dataset.type || 'autre',
                color: window.getComputedStyle(info.draggedEl, null).getPropertyValue('background-color'),
                location: info.draggedEl.dataset.location || '',
                publique: info.draggedEl.dataset.publique || 'all'
            };
            if (typeof saveEventFromDrop === 'function') {
                saveEventFromDrop(eventData);
            }
        },
        eventDrop: function(info) {
            if (typeof updateEventDate === 'function') {
                updateEventDate(info.event);
            }
        },
        eventResize: function(info) {
            if (typeof updateEventDate === 'function') {
                updateEventDate(info.event);
            }
        },
        eventDidMount: function(info) {
            var type = info.event.extendedProps.type || 'autre';
            info.el.classList.add('event-type-' + type);
            var tooltip = document.createElement('div');
            tooltip.className = 'event-tooltip';
            var labels = window.typeLabels || {};
            var label = labels[type] || type || 'Événement';
            var loc = info.event.extendedProps.location ? '<br>📍 ' + escapeHtml(info.event.extendedProps.location) : '';
            tooltip.innerHTML = '<strong>' + escapeHtml(info.event.title) + '</strong><br><span class="tooltip-type">' + escapeHtml(label) + '</span>' + loc;
            info.el.style.position = 'relative';
            info.el.appendChild(tooltip);
            info.el.addEventListener('mouseenter', function() {
                tooltip.style.display = 'block';
            });
            info.el.addEventListener('mouseleave', function() {
                tooltip.style.display = 'none';
            });
        },
        datesSet: function() {}
    });

    calendar.render();
    
    // ✅ Exposer calendar globalement
    window.calendar = calendar;
}

function navigateToDate(dateStr) {
    if (calendar) {
        calendar.gotoDate(dateStr);
        calendar.changeView('dayGridMonth');
    }
}

// Exposer globalement
window.initCalendar = initCalendar;
window.navigateToDate = navigateToDate;
window.calendar = calendar;