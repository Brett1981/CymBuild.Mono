window.serviceWorkerInterop = (function () {

    function enableForceReloadListener() {
        if (!('serviceWorker' in navigator)) return;

        navigator.serviceWorker.addEventListener('message', (event) => {
            if (event.data && event.data.action === 'force-reload') {
                window.location.reload();
            }
        });
    }

    function sendEnvironmentType(env) {
        if (!('serviceWorker' in navigator)) return;

        navigator.serviceWorker.ready
            .then(reg => {
                if (reg.active) {
                    reg.active.postMessage({
                        type: 'SetEnvironmentType',
                        value: env
                    });
                    console.info('[SW-Interop] Environment type sent to Service Worker:', env);
                }
            })
            .catch(error => {
                console.warn('[SW-Interop] Unable to send environment type to service worker.', error);
            });
    }

    function repairApp() {
        if (typeof window.cymBuildRepairApp === 'function') {
            return window.cymBuildRepairApp();
        }

        window.location.reload();
    }

    return {
        enableForceReloadListener,
        sendEnvironmentType,
        repairApp
    };
})();