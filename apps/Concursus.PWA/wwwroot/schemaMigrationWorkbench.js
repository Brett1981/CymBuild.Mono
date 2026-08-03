const bindingMap = new WeakMap();

function unbind(element) {
    if (!element) {
        return;
    }

    const binding = bindingMap.get(element);
    if (!binding) {
        return;
    }

    for (const item of binding.items) {
        item.element.removeEventListener('scroll', item.handler);
        bindingMap.delete(item.element);
    }
}

function maxScrollTop(element) {
    return Math.max(0, element.scrollHeight - element.clientHeight);
}

function maxScrollLeft(element) {
    return Math.max(0, element.scrollWidth - element.clientWidth);
}

function copyScrollPosition(fromElement, toElement) {
    if (!fromElement || !toElement) {
        return;
    }

    const nextTop = Math.min(fromElement.scrollTop, maxScrollTop(toElement));
    const nextLeft = Math.min(fromElement.scrollLeft, maxScrollLeft(toElement));

    if (Math.abs(toElement.scrollTop - nextTop) > 1) {
        toElement.scrollTop = nextTop;
    }

    if (Math.abs(toElement.scrollLeft - nextLeft) > 1) {
        toElement.scrollLeft = nextLeft;
    }
}

export function bindDefinitionScrollSync(sourceElement, targetElement) {
    if (!sourceElement || !targetElement) {
        return;
    }

    unbind(sourceElement);
    unbind(targetElement);

    let isSynchronising = false;

    const releaseSynchronisation = () => {
        window.requestAnimationFrame(() => {
            isSynchronising = false;
        });
    };

    const syncFromSource = () => {
        if (isSynchronising) {
            return;
        }

        isSynchronising = true;
        copyScrollPosition(sourceElement, targetElement);
        releaseSynchronisation();
    };

    const syncFromTarget = () => {
        if (isSynchronising) {
            return;
        }

        isSynchronising = true;
        copyScrollPosition(targetElement, sourceElement);
        releaseSynchronisation();
    };

    const items = [
        { element: sourceElement, handler: syncFromSource },
        { element: targetElement, handler: syncFromTarget }
    ];

    const binding = { items };
    for (const item of items) {
        bindingMap.set(item.element, binding);
        item.element.addEventListener('scroll', item.handler, { passive: true });
    }

    sourceElement.scrollTop = 0;
    sourceElement.scrollLeft = 0;
    targetElement.scrollTop = 0;
    targetElement.scrollLeft = 0;

    window.requestAnimationFrame(() => {
        copyScrollPosition(sourceElement, targetElement);
    });
}
