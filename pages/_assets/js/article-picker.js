(function () {
    function getLabel(option) {
        return option ? option.textContent : '-- Article --';
    }

    function resizePicker(select) {
        var picker = select.closest('.article-picker');
        var menu = picker && picker.querySelector('.article-picker-menu');
        if (!picker || !menu) return;

        var canvas = resizePicker.canvas || (resizePicker.canvas = document.createElement('canvas'));
        var context = canvas.getContext('2d');
        var font = window.getComputedStyle(menu).font;
        context.font = font;
        var longest = 0;
        Array.prototype.forEach.call(select.options, function (option) {
            longest = Math.max(longest, context.measureText(option.textContent).width);
        });

        var desired = Math.ceil(longest + 48);
        var maximum = Math.max(260, window.innerWidth - 32);
        picker.style.setProperty('--article-picker-width', Math.min(Math.max(desired, 280), Math.min(520, maximum)) + 'px');
    }

    function renderPicker(select) {
        var picker = select.closest('.article-picker');
        if (!picker) return;

        var button = picker.querySelector('.article-picker-toggle');
        var list = picker.querySelector('.article-picker-list');
        var search = picker.querySelector('.article-picker-search');
        if (!button || !list || !search) return;

        resizePicker(select);
        button.textContent = getLabel(select.options[select.selectedIndex]);
        list.innerHTML = '';
        var query = search.value.trim().toLowerCase();
        var visible = 0;

        Array.prototype.forEach.call(select.options, function (option) {
            if (!option.value) return;
            if (query && option.textContent.toLowerCase().indexOf(query) === -1) return;

            var item = document.createElement('button');
            item.type = 'button';
            item.className = 'article-picker-option' + (option.selected ? ' is-selected' : '');
            item.textContent = option.textContent;
            item.title = option.textContent;
            item.dataset.value = option.value;
            item.setAttribute('role', 'option');
            item.setAttribute('aria-selected', option.selected ? 'true' : 'false');
            item.addEventListener('click', function () {
                select.value = item.dataset.value;
                select.dispatchEvent(new Event('change', { bubbles: true }));
                button.textContent = getLabel(select.options[select.selectedIndex]);
                picker.classList.remove('is-open');
                button.setAttribute('aria-expanded', 'false');
                renderPicker(select);
            });
            list.appendChild(item);
            visible++;
        });

        if (!visible) {
            var empty = document.createElement('div');
            empty.className = 'article-picker-empty';
            empty.textContent = 'Aucun article trouvé';
            list.appendChild(empty);
        }
    }

    function enhance(select) {
        if (!select || select.dataset.articlePicker === 'true') {
            if (select) renderPicker(select);
            return;
        }

        select.dataset.articlePicker = 'true';
        select.classList.add('article-picker-native');
        var picker = document.createElement('div');
        picker.className = 'article-picker';
        select.parentNode.insertBefore(picker, select);
        picker.appendChild(select);

        var button = document.createElement('button');
        button.type = 'button';
        button.className = 'form-control form-control-sm article-picker-toggle';
        button.setAttribute('aria-haspopup', 'listbox');
        button.setAttribute('aria-expanded', 'false');
        picker.appendChild(button);

        var menu = document.createElement('div');
        menu.className = 'article-picker-menu';
        menu.setAttribute('role', 'listbox');
        var search = document.createElement('input');
        search.type = 'search';
        search.className = 'form-control form-control-sm article-picker-search';
        search.placeholder = 'Rechercher un article';
        search.setAttribute('aria-label', 'Rechercher un article');
        menu.appendChild(search);
        var list = document.createElement('div');
        list.className = 'article-picker-list';
        menu.appendChild(list);
        picker.appendChild(menu);

        button.addEventListener('click', function () {
            var open = !picker.classList.contains('is-open');
            document.querySelectorAll('.article-picker.is-open').forEach(function (other) {
                other.classList.remove('is-open');
                var otherButton = other.querySelector('.article-picker-toggle');
                if (otherButton) otherButton.setAttribute('aria-expanded', 'false');
            });
            picker.classList.toggle('is-open', open);
            button.setAttribute('aria-expanded', open ? 'true' : 'false');
            if (open) {
                search.value = '';
                renderPicker(select);
                search.focus();
            }
        });
        search.addEventListener('input', function () { renderPicker(select); });
        select.addEventListener('change', function () { renderPicker(select); });
        renderPicker(select);
    }

    document.addEventListener('click', function (event) {
        document.querySelectorAll('.article-picker.is-open').forEach(function (picker) {
            if (!picker.contains(event.target)) {
                picker.classList.remove('is-open');
                var button = picker.querySelector('.article-picker-toggle');
                if (button) button.setAttribute('aria-expanded', 'false');
            }
        });
    });

    window.addEventListener('resize', function () {
        document.querySelectorAll('.ligne-article').forEach(resizePicker);
    });

    window.enhanceArticleSelect = enhance;
    window.refreshArticleSelect = renderPicker;
})();
