const pads = new WeakMap();

function pointFor(canvas, event) {
    const rect = canvas.getBoundingClientRect();
    return {
        x: (event.clientX - rect.left) * (canvas.width / rect.width),
        y: (event.clientY - rect.top) * (canvas.height / rect.height)
    };
}

export function initialize(canvas) {
    dispose(canvas);

    const context = canvas.getContext("2d", { alpha: false });
    context.fillStyle = "#ffffff";
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.strokeStyle = "#111827";
    context.lineWidth = 4;
    context.lineCap = "round";
    context.lineJoin = "round";

    const state = { drawing: false, moved: false, hasInk: false, handlers: {} };
    state.handlers.down = event => {
        event.preventDefault();
        const point = pointFor(canvas, event);
        state.drawing = true;
        state.moved = false;
        canvas.setPointerCapture(event.pointerId);
        context.beginPath();
        context.moveTo(point.x, point.y);
    };
    state.handlers.move = event => {
        if (!state.drawing) return;
        event.preventDefault();
        const point = pointFor(canvas, event);
        context.lineTo(point.x, point.y);
        context.stroke();
        state.moved = true;
        state.hasInk = true;
    };
    state.handlers.up = event => {
        if (!state.drawing) return;
        event.preventDefault();
        if (!state.moved) {
            const point = pointFor(canvas, event);
            context.lineTo(point.x + 0.1, point.y + 0.1);
            context.stroke();
            state.hasInk = true;
        }
        state.drawing = false;
        if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    };

    canvas.addEventListener("pointerdown", state.handlers.down);
    canvas.addEventListener("pointermove", state.handlers.move);
    canvas.addEventListener("pointerup", state.handlers.up);
    canvas.addEventListener("pointercancel", state.handlers.up);
    pads.set(canvas, state);
}

export function exportPng(canvas) {
    const state = pads.get(canvas);
    if (!state || !state.hasInk) return null;
    return canvas.toDataURL("image/png");
}

export function dispose(canvas) {
    const state = pads.get(canvas);
    if (!state) return;
    canvas.removeEventListener("pointerdown", state.handlers.down);
    canvas.removeEventListener("pointermove", state.handlers.move);
    canvas.removeEventListener("pointerup", state.handlers.up);
    canvas.removeEventListener("pointercancel", state.handlers.up);
    pads.delete(canvas);
}
