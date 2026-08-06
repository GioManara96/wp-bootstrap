(function () {
    var MENU_WIDGET_SELECTOR = '.elementor-widget-n-menu';
    var MENU_LINK_SELECTOR = '.e-n-menu-content a[href*="#"]';

    var isSamePageAnchor = function (linkElement) {
        if (!linkElement || !linkElement.href) {
            return false;
        }

        var parsedUrl = new URL(linkElement.href, window.location.href);

        if (!parsedUrl.hash || parsedUrl.hash === '#') {
            return false;
        }

        return (
            parsedUrl.origin === window.location.origin &&
            parsedUrl.pathname === window.location.pathname &&
            parsedUrl.search === window.location.search
        );
    };

    var closeMenuForLink = function (linkElement) {
        var menuWidget = linkElement.closest(MENU_WIDGET_SELECTOR);
        if (!menuWidget) {
            return;
        }

        var menuItem = linkElement.closest('.e-n-menu-item');
        if (menuItem) {
            var openedDropdownButton = menuItem.querySelector(
                '.e-n-menu-dropdown-icon[aria-expanded="true"]'
            );

            if (openedDropdownButton) {
                openedDropdownButton.click();
            }
        }

        var openedMenuToggle = menuWidget.querySelector('.e-n-menu-toggle[aria-expanded="true"]');
        if (openedMenuToggle) {
            openedMenuToggle.click();
        }
    };

    document.addEventListener('click', function (event) {
        var clickedLink = event.target.closest(MENU_LINK_SELECTOR);
        if (!clickedLink || !isSamePageAnchor(clickedLink)) {
            return;
        }

        closeMenuForLink(clickedLink);
    });
})();
