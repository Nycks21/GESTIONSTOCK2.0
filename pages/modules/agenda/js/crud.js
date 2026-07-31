'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// CRUD — Module Agenda
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SAUVEGARDER UN ÉVÉNEMENT
// ─────────────────────────────────────────────────────────────────────────────

async function saveEvent() {
    var id = document.getElementById('eventId').value;
    var title = document.getElementById('eventTitle').value.trim();
    var type = document.getElementById('eventType').value;
    var start = document.getElementById('eventStart').value;
    var end = document.getElementById('eventEnd').value;
    var description = document.getElementById('eventDescription').value.trim();
    var color = document.getElementById('eventColor').value;
    var location = document.getElementById('eventLocation').value.trim();
    var publique = document.getElementById('eventAudience').value;
    var url = document.getElementById('eventUrl').value.trim();
    
    if (!title) {
        showToast('Veuillez saisir un titre', 'warning');
        document.getElementById('eventTitle').focus();
        return;
    }
    
    if (!start) {
        showToast('Veuillez sélectionner une date de début', 'warning');
        document.getElementById('eventStart').focus();
        return;
    }
    
    if (end) {
        var startDate = new Date(start);
        var endDate = new Date(end);
        
        if (endDate < startDate) {
            showToast('La date et l\'heure de fin doit être postérieure ou égale à la date de début', 'error');
            document.getElementById('eventEnd').focus();
            return;
        }
    }
    
    var endpoint = id ? API_AGENDA.updateEvent : API_AGENDA.addEvent;
    var payload = {
        id: id || null,
        title: title,
        type: type,
        start: start,
        end: end || null,
        description: description,
        color: color,
        location: location,
        publique: publique,
        url: url
    };
    
    showLoading('Sauvegarde en cours...');
    
    try {
        var response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        if (!response.ok) {
            throw new Error('Erreur HTTP ' + response.status);
        }
        
        var data = await response.json();
        
        if (data.success) {
            showToast(id ? 'Événement modifié avec succès' : 'Événement ajouté avec succès', 'success');
            closeEventModal();
            // ✅ Recharger uniquement le calendrier
            await refreshCalendar();
        } else {
            showToast(data.message || 'Erreur lors de l\'enregistrement', 'error');
        }
        hideLoading();
    } catch (e) {
        console.error('Erreur saveEvent:', e);
        hideLoading();
        showToast('Erreur de connexion: ' + e.message, 'error');
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPRIMER UN ÉVÉNEMENT
// ─────────────────────────────────────────────────────────────────────────────

async function deleteEvent(e) {
    if (e) {
        e.preventDefault();
        e.stopPropagation();
    }
    
    var idField = document.getElementById('eventId');
    var id = idField ? idField.value : '';
    
    if (!id) {
        closeEventModal();
        return;
    }
    
    var confirmed = await showConfirmDialog(
        '⚠️ Supprimer l\'événement',
        'Voulez-vous vraiment supprimer cet événement ?\n\nCette action est irréversible.',
        'Oui, supprimer',
        'Annuler',
        true
    );
    
    if (!confirmed) return;
    
    var spinner = document.getElementById('spinnerOverlay');
    if (spinner) spinner.style.display = 'flex';
    
    try {
        var response = await fetch(API_AGENDA.deleteEvent, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        });
        
        if (spinner) spinner.style.display = 'none';
        
        if (!response.ok) {
            throw new Error('Erreur HTTP ' + response.status);
        }
        
        var data = await response.json();
        
        if (data.success) {
            closeEventModal();
            closeConfirmDeleteModal();
            showToast('Événement supprimé avec succès', 'success');
            // ✅ Recharger uniquement le calendrier
            await refreshCalendar();
        } else {
            showToast(data.message || 'Erreur lors de la suppression', 'error');
        }
    } catch (err) {
        console.error('Erreur deleteEvent:', err);
        if (spinner) spinner.style.display = 'none';
        showToast('Erreur de connexion: ' + err.message, 'error');
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAUVEGARDER UN ÉVÉNEMENT (Drop)
// ─────────────────────────────────────────────────────────────────────────────

async function saveEventFromDrop(eventData) {
    var startDate = new Date(eventData.start);
    var endDate = eventData.end ? new Date(eventData.end) : null;
    
    if (endDate && endDate < startDate) {
        endDate = new Date(startDate);
        endDate.setHours(startDate.getHours() + 1);
        eventData.end = endDate.toISOString();
    }
    
    showLoading('Enregistrement...');
    
    try {
        var response = await fetch(API_AGENDA.addEvent, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                title: eventData.title,
                type: eventData.type || 'autre',
                start: eventData.start,
                end: eventData.end || null,
                color: eventData.color || '#1e3a2f',
                location: eventData.location || '',
                publique: eventData.publique || 'all'
            })
        });
        
        var data = await response.json();
        
        if (data.success) {
            showToast('Événement ajouté avec succès', 'success');
            // ✅ Recharger uniquement le calendrier
            await refreshCalendar();
        } else {
            showToast(data.message || 'Erreur', 'error');
        }
        hideLoading();
    } catch (e) {
        hideLoading();
        showToast('Erreur de connexion', 'error');
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MISE À JOUR DE LA DATE D'UN ÉVÉNEMENT
// ─────────────────────────────────────────────────────────────────────────────

async function updateEventDate(event) {
    try {
        if (event.end && event.end < event.start) {
            showToast('La date de fin ne peut pas être antérieure à la date de début', 'warning');
            await refreshCalendar();
            return;
        }
        
        var response = await fetch(API_AGENDA.updateEvent, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id: event.id,
                start: event.start.toISOString(),
                end: event.end ? event.end.toISOString() : null
            })
        });
        
        if (!response.ok) {
            throw new Error('Erreur HTTP ' + response.status);
        }
        
        var data = await response.json();
        if (!data.success) {
            showToast('Erreur lors de la mise à jour de la date', 'error');
            await refreshCalendar();
        }
    } catch (e) {
        console.error('Erreur updateEventDate:', e);
        showToast('Erreur de connexion: ' + e.message, 'error');
        await refreshCalendar();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPOSER LES FONCTIONS GLOBALEMENT
// ─────────────────────────────────────────────────────────────────────────────

window.saveEvent = saveEvent;
window.deleteEvent = deleteEvent;
window.saveEventFromDrop = saveEventFromDrop;
window.updateEventDate = updateEventDate;