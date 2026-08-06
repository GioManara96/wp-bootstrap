(function () {
    const accordionItems = Array.from(
        document.querySelectorAll('details.e-n-accordion-item[id^="acc-"]')
    );

    if (!accordionItems.length) {
        return;
    }

    const imageItems = Array.from(
        document.querySelectorAll('[id^="img-"]')
    );

    if (!imageItems.length) {
        return;
    }

    const imageById = new Map();
    imageItems.forEach(function (imageItem) {
        imageById.set(imageItem.id, imageItem);
    });

    const removeElementorResponsiveHiddenClasses = function (element) {
        const hiddenClasses = Array.from(element.classList).filter(function (cssClass) {
            return cssClass.indexOf('elementor-hidden-') === 0;
        });

        hiddenClasses.forEach(function (cssClass) {
            element.classList.remove(cssClass);
        });
    };

    const showImageByAccordionId = function (accordionId) {
        const imageId = accordionId.replace(/^acc-/, 'img-');
        const targetImage = imageById.get(imageId);

        if (!targetImage) {
            return;
        }

        imageItems.forEach(function (imageItem) {
            const isActiveImage = imageItem === targetImage;

            if (isActiveImage) {
                removeElementorResponsiveHiddenClasses(imageItem);
                imageItem.removeAttribute('hidden');
            } else {
                imageItem.setAttribute('hidden', '');
            }

            imageItem.setAttribute(
                'aria-hidden',
                isActiveImage ? 'false' : 'true'
            );
        });
    };

    accordionItems.forEach(function (accordionItem) {
        accordionItem.addEventListener('toggle', function () {
            if (!accordionItem.open) {
                return;
            }

            showImageByAccordionId(accordionItem.id);
        });
    });

    const openedAccordionItem = accordionItems.find(function (accordionItem) {
        return accordionItem.open;
    });

    if (openedAccordionItem) {
        showImageByAccordionId(openedAccordionItem.id);
        return;
    }

    showImageByAccordionId(accordionItems[0].id);
})();
