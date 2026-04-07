export async function getTotalMemory() {
    if (window && window.performance && performance.memory) {
        return performance.memory.usedJSHeapSize;
    } else {
        // Simulate fallback
        return 0;
    }
}

export async function getJSObjectReferenceCount() {
    // Count attached .NET interop references
    return window.blazorInstance ? Object.keys(window.blazorInstance).length : 0;
}

export async function getBlazorComponentCount() {
    // There is no native marker for Blazor components in the DOM.
    // Use known container or root tags to estimate active layout components.
    return document.querySelectorAll(".telerik-blazor").length;
}

export async function getTelerikGridCount() {
    return document.querySelectorAll('.k-grid').length;
}

export async function getServiceWorkerCacheSizeMB() {
    if (!('caches' in window)) return 0;
    let total = 0;
    const keys = await caches.keys();
    for (const key of keys) {
        const cache = await caches.open(key);
        const requests = await cache.keys();
        for (const request of requests) {
            const response = await cache.match(request);
            if (response) {
                const cloned = response.clone();
                const blob = await cloned.blob();
                total += blob.size;
            }
        }
    }
    return (total / 1024 / 1024); // in MB
}