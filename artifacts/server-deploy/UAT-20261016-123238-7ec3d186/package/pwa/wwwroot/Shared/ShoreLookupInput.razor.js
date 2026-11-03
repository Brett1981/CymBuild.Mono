export function getMenuStyle(controlElement) {
    if (!controlElement || typeof controlElement.getBoundingClientRect !== "function") {
        return "";
    }

    const rect = controlElement.getBoundingClientRect();
    if (!rect || rect.width <= 0 || rect.height <= 0) {
        return "";
    }

    const viewportWidth = window.innerWidth || document.documentElement.clientWidth || 1024;
    const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 768;
    const margin = 8;
    const gap = 4;
    const preferredMaxHeight = 288;
    const minimumUsefulHeight = 140;

    const availableWidth = Math.max(180, viewportWidth - (margin * 2));
    const width = Math.min(Math.max(rect.width, 220), availableWidth);

    let left = rect.left;
    if (left + width > viewportWidth - margin) {
        left = viewportWidth - margin - width;
    }
    left = Math.max(margin, left);

    const spaceBelow = Math.max(0, viewportHeight - rect.bottom - gap - margin);
    const spaceAbove = Math.max(0, rect.top - gap - margin);

    let top = rect.bottom + gap;
    let maxHeight = Math.min(preferredMaxHeight, Math.max(minimumUsefulHeight, spaceBelow));

    if (spaceBelow < minimumUsefulHeight && spaceAbove > spaceBelow) {
        maxHeight = Math.min(preferredMaxHeight, Math.max(minimumUsefulHeight, spaceAbove));
        top = Math.max(margin, rect.top - gap - maxHeight);
    }

    maxHeight = Math.min(maxHeight, Math.max(80, viewportHeight - top - margin));

    return [
        "position: fixed",
        `left: ${Math.round(left)}px`,
        `top: ${Math.round(top)}px`,
        `width: ${Math.round(width)}px`,
        `max-height: ${Math.round(maxHeight)}px`,
        "visibility: visible"
    ].join("; ") + ";";
}