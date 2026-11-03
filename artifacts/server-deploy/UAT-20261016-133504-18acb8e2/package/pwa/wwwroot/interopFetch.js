window.syncInterop = {
    triggerSync: async function () {
        const reg = await navigator.serviceWorker.ready;
        await reg.sync.register('syncOfflineQueue');
    }
};