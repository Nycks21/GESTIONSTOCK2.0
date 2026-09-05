'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// CALENDRIER — Module Dashboard
// ─────────────────────────────────────────────────────────────────────────────

function generateCalendar(date) {
    var grid = document.getElementById('calendarGrid');
    if (!grid) return;

    var year = date.getFullYear();
    var month = date.getMonth();
    var today = new Date();
    var firstDay = new Date(year, month, 1);
    var lastDate = new Date(year, month + 1, 0).getDate();

    var startOffset = firstDay.getDay() - 1;
    if (startOffset < 0) startOffset = 6;

    var days = getWeekDays();
    var monthNames = getMonthNames();
    var monthShort = getShortMonthNames();

    var html = '';
    for (var d = 0; d < days.length; d++) {
        html += '<div class="cal-hd">' + days[d] + '</div>';
    }

    for (var i = 0; i < startOffset; i++) {
        html += '<div class="cal-d empty"></div>';
    }

    // Récupérer les événements du mois
    var monthEvents = calendarEvents.filter(function(e) {
        if (!e.start) return false;
        var eventDate = new Date(e.start);
        return eventDate.getFullYear() === year && eventDate.getMonth() === month;
    });

    var eventsByDay = {};
    for (var j = 0; j < monthEvents.length; j++) {
        var e = monthEvents[j];
        var eventDate = new Date(e.start);
        var day = eventDate.getDate();
        if (!eventsByDay[day]) eventsByDay[day] = [];
        eventsByDay[day].push(e);
    }

    for (var d2 = 1; d2 <= lastDate; d2++) {
        var isToday = d2 === today.getDate() && month === today.getMonth() && year === today.getFullYear();
        var hasEvent = eventsByDay[d2] && eventsByDay[d2].length > 0;
        var eventColor = hasEvent ? eventsByDay[d2][0].color || COLORS.terra : null;

        var cls = 'cal-d';
        if (isToday) cls += ' today';
        if (hasEvent) cls += ' event';

        var dot = hasEvent ? '<span class="cal-dot" style="background:' + eventColor + '"></span>' : '';
        var title = hasEvent ? eventsByDay[d2].map(function(e) { return e.title; }).join(', ') : '';

        html += '<div class="' + cls + '" onclick="selectDate(' + d2 + ')" title="' + escapeHtml(title) + '">'
            + d2 + dot
            + '</div>';
    }

    grid.innerHTML = html;

    // Mettre à jour le titre du mois
    var monthTitle = document.getElementById('calendarMonthTitle');
    if (monthTitle) {
        monthTitle.textContent = monthNames[month] + ' ' + year;
    }

    // Mettre à jour la liste des événements
    updateEventList(monthEvents);
}

function updateEventList(events) {
    var eventList = document.getElementById('eventList');
    if (!eventList) return;

    if (!events || events.length === 0) {
        eventList.innerHTML = '<div class="event-empty">Aucun événement ce mois</div>';
        return;
    }

    var sorted = events.slice().sort(function(a, b) {
        if (!a.start) return 1;
        if (!b.start) return -1;
        return new Date(a.start) - new Date(b.start);
    });

    var displayEvents = sorted.slice(0, 8);
    var monthShort = getShortMonthNames();
    var typeIcons = {
        'cours': 'fa-chalkboard-teacher',
        'examen': 'fa-file-alt',
        'reunion': 'fa-users',
        'sortie': 'fa-bus',
        'autre': 'fa-calendar-alt'
    };

    var html = '';
    for (var i = 0; i < displayEvents.length; i++) {
        var e = displayEvents[i];
        var eventDate = new Date(e.start);
        var day = eventDate.getDate();
        var month = monthShort[eventDate.getMonth()];
        var color = e.color || COLORS.terra;
        var icon = typeIcons[e.type] || 'fa-calendar-alt';

        html += '<div class="event-list-item" onclick="showEventDetail(\'' + escapeHtml(e.id) + '\')" style="cursor:pointer;">'
            + '<div class="event-color-indicator" style="background:' + color + ';width:4px;flex-shrink:0;border-radius:2px;"></div>'
            + '<div style="flex:1;min-width:0;">'
            + '<div style="display:flex;justify-content:space-between;align-items:center;">'
            + '<span class="event-desc" style="font-size:13px;font-weight:500;color:#1a1a1a;">'
            + '<i class="fas ' + icon + '" style="color:' + color + ';margin-right:6px;font-size:11px;"></i>'
            + escapeHtml(e.title)
            + '</span>'
            + '<span class="event-date" style="font-size:11px;color:#6c757d;white-space:nowrap;margin-left:8px;">'
            + day + ' ' + month
            + (e.heureDebut ? ' à ' + e.heureDebut : '')
            + '</span>'
            + '</div>'
            + (e.description ? '<div style="font-size:11px;color:#6c757d;margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">' + escapeHtml(e.description) + '</div>' : '')
            + '</div>'
            + '</div>';
    }
    eventList.innerHTML = html;
}

function showEventDetail(eventId) {
    var event = null;
    for (var i = 0; i < calendarEvents.length; i++) {
        if (calendarEvents[i].id === eventId) {
            event = calendarEvents[i];
            break;
        }
    }

    if (!event) {
        if (typeof Swal !== 'undefined') {
            Swal.fire('Information', 'Événement non trouvé', 'info');
        }
        return;
    }

    var eventDate = new Date(event.start);
    var dateStr = formatDateFr(eventDate);

    var typeLabels = {
        'cours': 'Cours',
        'examen': 'Examen',
        'reunion': 'Réunion',
        'sortie': 'Sortie',
        'autre': 'Autre'
    };

    var details = '<div style="text-align:left;font-size:14px;line-height:1.6;">'
        + '<p><strong>📅 Date :</strong> ' + dateStr + '</p>'
        + (event.heureDebut ? '<p><strong>⏰ Heure :</strong> ' + event.heureDebut + (event.heureFin ? ' - ' + event.heureFin : '') + '</p>' : '')
        + (event.type ? '<p><strong>📂 Type :</strong> ' + (typeLabels[event.type] || event.type) + '</p>' : '')
        + (event.location ? '<p><strong>📍 Lieu :</strong> ' + escapeHtml(event.location) + '</p>' : '')
        + (event.description ? '<p><strong>📝 Description :</strong><br>' + escapeHtml(event.description) + '</p>' : '')
        + (event.url ? '<p><strong>🔗 Lien :</strong> <a href="' + escapeHtml(event.url) + '" target="_blank">' + escapeHtml(event.url) + '</a></p>' : '')
        + '</div>';

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

function selectDate(day) {
    var year = currentDate.getFullYear();
    var month = currentDate.getMonth();

    var dayEvents = calendarEvents.filter(function(e) {
        if (!e.start) return false;
        var eventDate = new Date(e.start);
        return eventDate.getFullYear() === year &&
               eventDate.getMonth() === month &&
               eventDate.getDate() === day;
    });

    if (dayEvents.length === 0) {
        if (typeof Swal !== 'undefined') {
            Swal.fire('Aucun événement', 'Aucun événement prévu le ' + day + '/' + (month + 1) + '/' + year, 'info');
        }
        return;
    }

    var eventList = '';
    for (var i = 0; i < dayEvents.length; i++) {
        var e = dayEvents[i];
        eventList += '• ' + escapeHtml(e.title) + (e.heureDebut ? ' (' + e.heureDebut + ')' : '') + '\n';
    }

    if (typeof Swal !== 'undefined') {
        Swal.fire('Événements du ' + day + '/' + (month + 1) + '/' + year, eventList, 'info');
    } else {
        alert('Événements du ' + day + '/' + (month + 1) + '/' + year + ':\n' + eventList);
    }
}

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

// Exposer globalement
window.generateCalendar = generateCalendar;
window.updateEventList = updateEventList;
window.showEventDetail = showEventDetail;
window.selectDate = selectDate;
window.prevMonth = prevMonth;
window.nextMonth = nextMonth;
window.todayMonth = todayMonth;