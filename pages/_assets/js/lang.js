// Gestion du sélecteur de langue (dans le DOMContentLoaded)
document.addEventListener('DOMContentLoaded', function () {
    var langSelect = document.getElementById('langSelect');
    if (langSelect) {
        langSelect.addEventListener('change', function () {
            var culture = this.value;
            if (typeof window.setLanguage === 'function') {
                window.setLanguage(culture);
            } else {
                // Fallback : redirection manuelle
                var url = new URL(window.location.href);
                url.searchParams.set('lang', culture);
                window.location.href = url.toString();
            }
        });
    }
});
