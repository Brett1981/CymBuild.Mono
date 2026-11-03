// CYB-524: hovering near the left/right edge of a horizontally-scrollable
// grid wrapper auto-scrolls that direction, so the user does not need to
// reach the scrollbar at the bottom of a tall grid to navigate sideways.
// Shared by DynamicGridView, FilteredDynamicGridView and DynamicBatchGridView.
window.cymbuildGridEdgeAutoScroll = window.cymbuildGridEdgeAutoScroll || {};

window.cymbuildGridEdgeAutoScroll.attach = function (elementId) {
    const element = document.getElementById(elementId);
    if (!element || element.dataset.cymbuildEdgeScrollAttached === 'true') return;

    const edgeZonePx = 56;
    const maxSpeedPxPerFrame = 18;

    let pointerX = null;
    let rafId = null;

    const step = function () {
        rafId = null;
        if (pointerX === null) return;

        const rect = element.getBoundingClientRect();
        const distanceFromLeft = pointerX - rect.left;
        const distanceFromRight = rect.right - pointerX;

        let delta = 0;
        if (distanceFromLeft >= 0 && distanceFromLeft < edgeZonePx) {
            delta = -maxSpeedPxPerFrame * (1 - (distanceFromLeft / edgeZonePx));
        } else if (distanceFromRight >= 0 && distanceFromRight < edgeZonePx) {
            delta = maxSpeedPxPerFrame * (1 - (distanceFromRight / edgeZonePx));
        }

        if (delta !== 0) {
            element.scrollLeft += delta;
            rafId = window.requestAnimationFrame(step);
        }
    };

    const onPointerMove = function (event) {
        const rect = element.getBoundingClientRect();
        if (event.clientY < rect.top || event.clientY > rect.bottom) {
            pointerX = null;
            return;
        }

        pointerX = event.clientX;
        if (rafId === null) rafId = window.requestAnimationFrame(step);
    };

    const onPointerLeave = function () {
        pointerX = null;
    };

    element.addEventListener('mousemove', onPointerMove);
    element.addEventListener('mouseleave', onPointerLeave);
    element.dataset.cymbuildEdgeScrollAttached = 'true';

    element._cymbuildEdgeScrollCleanup = function () {
        element.removeEventListener('mousemove', onPointerMove);
        element.removeEventListener('mouseleave', onPointerLeave);
        if (rafId !== null) window.cancelAnimationFrame(rafId);
        pointerX = null;
        delete element.dataset.cymbuildEdgeScrollAttached;
        delete element._cymbuildEdgeScrollCleanup;
    };
};

window.cymbuildGridEdgeAutoScroll.detach = function (elementId) {
    const element = document.getElementById(elementId);
    if (element && typeof element._cymbuildEdgeScrollCleanup === 'function') {
        element._cymbuildEdgeScrollCleanup();
    }
};
