(function () {
    const headerElement = document.getElementById('mgs-header');
    const SCROLL_THRESHOLD = 64;
    const MOBILE_BREAKPOINT = 768;

    if (!headerElement) {
        return;
    }

    const applyHeaderState = function (isScrolled, isMobile) {
        headerElement.classList.toggle('mgs-header--scrolled', isScrolled && !isMobile);
        headerElement.classList.toggle('mgs-header--mobile', isMobile);
    };

    const updateHeaderState = function () {
        const isMobile = window.innerWidth < MOBILE_BREAKPOINT;
        const isScrolled = window.scrollY > SCROLL_THRESHOLD;

        applyHeaderState(isScrolled, isMobile);
    };

    window.addEventListener('scroll', updateHeaderState, { passive: true });
    window.addEventListener('resize', updateHeaderState);

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', updateHeaderState, { once: true });
        return;
    }

    updateHeaderState();
})();
