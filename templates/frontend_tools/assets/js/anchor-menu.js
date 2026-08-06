(function () {
    var anchorLinks = Array.prototype.slice.call(
        document.querySelectorAll(
            '.elementor-widget-button a[href*="#"], .elementor-button-wrapper a[href*="#"]'
        )
    ).filter(function (link) {
        if (!link.hash || link.hash === '#') {
            return false;
        }

        var targetId = link.hash.slice(1);
        if (!targetId) {
            return false;
        }

        return Boolean(document.getElementById(targetId));
    });

    if (anchorLinks.length < 2) {
        return;
    }

    var linkBySectionId = new Map();
    anchorLinks.forEach(function (link) {
        var sectionId = link.hash.slice(1);
        if (!linkBySectionId.has(sectionId)) {
            linkBySectionId.set(sectionId, []);
        }

        linkBySectionId.get(sectionId).push(link);
    });

    var setActiveLinks = function (activeSectionId) {
        linkBySectionId.forEach(function (links, sectionId) {
            var isActive = sectionId === activeSectionId;

            links.forEach(function (link) {
                link.classList.toggle('mgs-anchor-link-active', isActive);
                if (isActive) {
                    link.setAttribute('aria-current', 'location');
                } else {
                    link.removeAttribute('aria-current');
                }
            });
        });
    };

    var sectionIds = Array.from(linkBySectionId.keys());
    var updateActiveSectionFromViewport = function () {
        var viewportHeight = window.innerHeight || document.documentElement.clientHeight;
        var activationLine = viewportHeight * 0.35;
        var bestSectionId = null;
        var bestDistance = Number.POSITIVE_INFINITY;
        var lastSectionBeforeLine = null;

        sectionIds.forEach(function (sectionId) {
            var section = document.getElementById(sectionId);
            if (!section) {
                return;
            }

            var rect = section.getBoundingClientRect();
            var distance = Math.abs(rect.top - activationLine);

            if (rect.top <= activationLine) {
                lastSectionBeforeLine = sectionId;
            }

            if (distance < bestDistance) {
                bestDistance = distance;
                bestSectionId = sectionId;
            }
        });

        setActiveLinks(lastSectionBeforeLine || bestSectionId || sectionIds[0]);
    };

    var observer = new IntersectionObserver(
        function () {
            updateActiveSectionFromViewport();
        },
        {
            root: null,
            rootMargin: '-30% 0px -55% 0px',
            threshold: [0.2, 0.4, 0.6]
        }
    );

    linkBySectionId.forEach(function (_links, sectionId) {
        var target = document.getElementById(sectionId);
        if (target) {
            observer.observe(target);
        }
    });

    anchorLinks.forEach(function (link) {
        link.addEventListener('click', function () {
            setActiveLinks(link.hash.slice(1));
        });
    });

    if (window.location.hash && linkBySectionId.has(window.location.hash.slice(1))) {
        setActiveLinks(window.location.hash.slice(1));
    } else {
        var firstSectionId = anchorLinks[0].hash.slice(1);
        setActiveLinks(firstSectionId);
    }

    window.addEventListener('scroll', updateActiveSectionFromViewport, { passive: true });
    window.addEventListener('resize', updateActiveSectionFromViewport);
})();
