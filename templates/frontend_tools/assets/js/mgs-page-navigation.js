(function ($) {
    'use strict';

    var MOBILE_MAX = 767;
    var HIDE_DELAY_MS = 120;
    var TOP_HIDE_THRESHOLD = 80;
    var DEFAULT_HEADER_OFFSET = 70;
    var SUBMENU_CLOSE_DELAY_MS = 50;

    var $nav = $('.mgs-page-navigation').first();
    var $body = $('body');

    if (!$nav.length) {
        return;
    }

    var lastScrollTop = 0;
    var isHidden = false;
    var hideTimer = null;

    var isMobile = function () {
        return window.innerWidth <= MOBILE_MAX;
    };

    var clearHideTimer = function () {
        if (hideTimer) {
            clearTimeout(hideTimer);
            hideTimer = null;
        }
    };

    var setNavHidden = function (hidden) {
        if (isHidden === hidden) {
            return;
        }

        isHidden = hidden;
        $nav.toggleClass('mgs-page-navigation--hidden', hidden);
        $body.toggleClass('mgs-page-navigation-is-hidden', hidden);
    };

    var setHeaderOffset = function () {
        var $header = $('#mgs-header');
        var height = $header.length ? $header.outerHeight() : DEFAULT_HEADER_OFFSET;

        $nav.css('--mgs-header-offset', height + 'px');
    };

    var closeAllUaelSubmenus = function () {
        $nav.find('.uael-has-submenu-container').each(function () {
            var $container = $(this);
            var $subMenu = $container.next('.sub-menu');

            $container.removeClass('sub-menu-active');
            $container.parent('li.menu-item').removeClass('menu-active');
            $container.find('a').attr('aria-expanded', 'false');

            if ($subMenu.length) {
                $subMenu.removeClass('sub-menu-open');
                $subMenu.css({
                    visibility: 'hidden',
                    opacity: 0,
                    height: 0,
                    transition: 'none'
                });
            }
        });
    };

    var resetDesktopState = function () {
        clearHideTimer();
        setNavHidden(false);
        $body.removeClass('mgs-has-page-navigation mgs-page-navigation-is-hidden');
    };

    var onScroll = function () {
        if (!isMobile()) {
            return;
        }

        var scrollTop = $(window).scrollTop();
        var delta = scrollTop - lastScrollTop;

        if (scrollTop <= TOP_HIDE_THRESHOLD) {
            clearHideTimer();
            setNavHidden(true);
            lastScrollTop = scrollTop;
            return;
        }

        if (delta > 0) {
            if (!isHidden && !hideTimer) {
                hideTimer = setTimeout(function () {
                    hideTimer = null;
                    setNavHidden(true);
                }, HIDE_DELAY_MS);
            }
        } else if (delta < 0) {
            clearHideTimer();
            setNavHidden(false);
        }

        lastScrollTop = scrollTop;
    };

    var onResize = function () {
        setHeaderOffset();

        if (!isMobile()) {
            resetDesktopState();
            return;
        }

        $body.addClass('mgs-has-page-navigation');
    };

    $(function () {
        if (isMobile()) {
            $body.addClass('mgs-has-page-navigation');
            setNavHidden(true);
        }

        setHeaderOffset();
        lastScrollTop = $(window).scrollTop();

        // UAEL triggera click su tutti i .uael-menu-toggle: chiudiamo i submenu dopo il suo handler.
        $nav.on('click', 'a.uael-sub-menu-item[href*="#"]', function () {
            var href = $(this).attr('href') || '';

            if (href === '#' || href.indexOf('#') === -1) {
                return;
            }

            window.setTimeout(closeAllUaelSubmenus, SUBMENU_CLOSE_DELAY_MS);
        });

        $(window).on('resize', onResize);
        $(window).on('scroll', onScroll);
    });
})(jQuery);
