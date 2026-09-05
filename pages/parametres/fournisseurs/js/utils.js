// ============================================================
// UTILITAIRES GLOBAUX
// ============================================================

/**
 * Affiche un toast de notification avec SweetAlert2
 * @param {string} title - Titre du toast
 * @param {string} message - Message (optionnel, utilisé comme contenu principal)
 * @param {string} icon - 'success'|'error'|'warning'|'info'
 * @param {number} timer - Durée d'affichage en ms
 */
function showToast(title, message, icon, timer) {
    // Valeurs par défaut
    icon = icon || 'success';
    timer = timer || 3000;

    // Vérifier que Swal est disponible
    if (typeof Swal === 'undefined') {
        console.warn('SweetAlert2 non chargé, fallback vers alert');
        alert((title || '') + (message ? '\n' + message : ''));
        return;
    }

    // Nettoyer les paramètres (les convertir en chaîne, éviter undefined)
    var finalTitle = (title || '').toString();
    var finalMessage = (message || '').toString();

    // Si les deux sont vides, mettre un texte par défaut
    if (!finalTitle && !finalMessage) {
        finalTitle = 'Notification';
    }

    // Si seul le message est fourni, l'utiliser comme titre
    if (!finalTitle && finalMessage) {
        finalTitle = finalMessage;
        finalMessage = '';
    }

    var Toast = Swal.mixin({
        toast: true,
        position: 'top-end',
        showConfirmButton: false,
        timer: timer,
        timerProgressBar: true,
        didOpen: function (toast) {
            toast.addEventListener('mouseenter', Swal.stopTimer);
            toast.addEventListener('mouseleave', Swal.resumeTimer);
        }
    });

    Toast.fire({
        icon: icon,
        title: finalTitle,
        text: finalMessage || undefined
    });
}

/**
 * Affiche un message d'erreur dans un toast
 * @param {string} message
 */
function showErrorToast(message) {
    showToast('Erreur', message, 'error');
}

/**
 * Affiche un message de succès
 * @param {string} message
 */
function showSuccessToast(message) {
    showToast('Succès', message, 'success');
}
