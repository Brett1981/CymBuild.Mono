/* ============================================================================
   CymBuild Service Worker Registrator
   ----------------------------------------------------------------------------
   PURPOSE
   - Register the service worker with updateViaCache disabled
   - Detect waiting updates without auto-applying them
   - Notify Blazor/UI when an update becomes available
   - Apply the update only when the user clicks Update App
   - Preserve repair/reset support
   ============================================================================ */

(function () {
    "use strict";

    let refreshing = false;
    let activeRegistration = null;
    const subscribers = new Set();

    const state = {
        isSupported: "serviceWorker" in navigator,
        isRegistered: false,
        isInstalling: false,
        isRefreshing: false,
        isUpdateAvailable: false,
        currentVersion: null,
        waitingVersion: null,
        scope: null,
        lastCheckedUtc: null
    };

    function log(message, ...args) {
        console.info(`[SW-Registrator] ${message}`, ...args);
    }

    function cloneState() {
        return {
            isSupported: !!state.isSupported,
            isRegistered: !!state.isRegistered,
            isInstalling: !!state.isInstalling,
            isRefreshing: !!state.isRefreshing,
            isUpdateAvailable: !!state.isUpdateAvailable,
            currentVersion: state.currentVersion,
            waitingVersion: state.waitingVersion,
            scope: state.scope,
            lastCheckedUtc: state.lastCheckedUtc
        };
    }

    function notifySubscribers() {
        const snapshot = cloneState();

        document.body.classList.toggle("sw-update-available", !!snapshot.isUpdateAvailable);

        window.dispatchEvent(new CustomEvent("cymbuild-sw-state-changed", {
            detail: snapshot
        }));

        subscribers.forEach(ref => {
            try {
                ref.invokeMethodAsync("OnServiceWorkerStatusChanged", snapshot)
                    .catch(error => console.warn("[SW-Registrator] Subscriber callback failed.", error));
            } catch (error) {
                console.warn("[SW-Registrator] Failed to notify subscriber.", error);
            }
        });
    }

    function updateStateFromRegistration(registration) {
        activeRegistration = registration || activeRegistration;

        state.isRegistered = !!activeRegistration;
        state.scope = activeRegistration?.scope || null;
        state.currentVersion = (window.appVersion || null);

        const waitingWorker = activeRegistration?.waiting || null;
        const installingWorker = activeRegistration?.installing || null;

        state.isInstalling = !!installingWorker && installingWorker.state !== "installed";
        state.isUpdateAvailable = !!waitingWorker;
        state.waitingVersion = waitingWorker ? "new version" : null;

        notifySubscribers();
    }

    function wireWorkerState(registration, worker) {
        if (!worker) {
            updateStateFromRegistration(registration);
            return;
        }

        worker.addEventListener("statechange", () => {
            log("Worker state changed:", worker.state);

            if (worker.state === "installed") {
                if (navigator.serviceWorker.controller) {
                    state.isUpdateAvailable = true;
                    state.waitingVersion = "new version";
                    state.isInstalling = false;
                    updateStateFromRegistration(registration);
                    return;
                }

                state.isInstalling = false;
                updateStateFromRegistration(registration);
                return;
            }

            if (worker.state === "installing") {
                state.isInstalling = true;
                updateStateFromRegistration(registration);
                return;
            }

            if (worker.state === "activated" || worker.state === "redundant") {
                state.isInstalling = false;
                updateStateFromRegistration(registration);
            }
        });
    }

    async function registerServiceWorker() {
        if (!("serviceWorker" in navigator)) {
            console.warn("[SW-Registrator] This browser does not support service workers.");
            notifySubscribers();
            return;
        }

        try {
            activeRegistration = await navigator.serviceWorker.register("/service-worker.js", {
                updateViaCache: "none"
            });

            log("Registered service worker.", { scope: activeRegistration.scope });

            state.isRegistered = true;
            state.scope = activeRegistration.scope;
            state.currentVersion = window.appVersion || null;

            if (activeRegistration.installing) {
                wireWorkerState(activeRegistration, activeRegistration.installing);
            }

            if (activeRegistration.waiting) {
                state.isUpdateAvailable = true;
                state.waitingVersion = "new version";
            }

            updateStateFromRegistration(activeRegistration);

            activeRegistration.addEventListener("updatefound", () => {
                const newWorker = activeRegistration.installing;
                if (!newWorker) {
                    return;
                }

                log("Update found.");
                state.isInstalling = true;
                updateStateFromRegistration(activeRegistration);
                wireWorkerState(activeRegistration, newWorker);
            });

            navigator.serviceWorker.addEventListener("controllerchange", () => {
                if (refreshing) {
                    return;
                }

                refreshing = true;
                state.isRefreshing = true;
                notifySubscribers();

                log("Controller changed. Reloading page.");
                window.location.reload();
            });

            setInterval(() => {
                if (activeRegistration) {
                    checkForUpdate().catch(error => {
                        console.warn("[SW-Registrator] Periodic update check failed.", error);
                    });
                }
            }, 60 * 1000);

            document.addEventListener("visibilitychange", () => {
                if (document.visibilityState === "visible" && activeRegistration) {
                    checkForUpdate().catch(error => {
                        console.warn("[SW-Registrator] Visibility update check failed.", error);
                    });
                }
            });

            window.addEventListener("online", () => {
                if (activeRegistration) {
                    checkForUpdate().catch(error => {
                        console.warn("[SW-Registrator] Online update check failed.", error);
                    });
                }
            });
        } catch (error) {
            console.error("[SW-Registrator] Registration failed.", error);
        }
    }

    async function checkForUpdate() {
        if (!activeRegistration) {
            return;
        }

        state.lastCheckedUtc = new Date().toISOString();
        state.isInstalling = true;
        notifySubscribers();

        await activeRegistration.update();

        state.isInstalling = !!activeRegistration.installing;
        updateStateFromRegistration(activeRegistration);
    }

    async function applyUpdate() {
        if (activeRegistration?.waiting) {
            log("Applying waiting service worker update.");
            state.isRefreshing = true;
            notifySubscribers();

            activeRegistration.waiting.postMessage("SKIP_WAITING");
            return;
        }

        await checkForUpdate();

        if (activeRegistration?.waiting) {
            log("Applying newly detected waiting service worker update.");
            state.isRefreshing = true;
            notifySubscribers();

            activeRegistration.waiting.postMessage("SKIP_WAITING");
        }
    }

    async function clearCaches() {
        if (!("caches" in window)) {
            return;
        }

        const keys = await caches.keys();
        await Promise.all(keys.map(key => caches.delete(key)));
    }

    async function clearIndexedDb() {
        if (!window.indexedDB || typeof indexedDB.databases !== "function") {
            return;
        }

        const databases = await indexedDB.databases();

        await Promise.all(
            databases
                .filter(db => !!db.name)
                .map(db => new Promise(resolve => {
                    const request = indexedDB.deleteDatabase(db.name);
                    request.onsuccess = () => resolve();
                    request.onerror = () => resolve();
                    request.onblocked = () => resolve();
                }))
        );
    }

    async function unregisterServiceWorkers() {
        if (!("serviceWorker" in navigator)) {
            return;
        }

        const registrations = await navigator.serviceWorker.getRegistrations();
        await Promise.all(registrations.map(r => r.unregister()));
    }

    async function repairApp() {
        try {
            log("Starting repair/reset.");

            if (navigator.serviceWorker?.controller) {
                navigator.serviceWorker.controller.postMessage("CLEAR_CACHE_RELOAD");
            }

            await clearCaches();
            await clearIndexedDb();
            localStorage.clear();
            sessionStorage.clear();
            await unregisterServiceWorkers();

            const current = new URL(window.location.href);
            current.searchParams.set("swreset", Date.now().toString());

            log("Repair/reset complete. Reloading to", current.toString());
            window.location.replace(current.toString());
        } catch (error) {
            console.error("[SW-Registrator] Repair/reset failed.", error);
            window.location.reload();
        }
    }

    function enableForceReloadListener() {
        if (!("serviceWorker" in navigator)) {
            return;
        }

        navigator.serviceWorker.addEventListener("message", event => {
            const data = event.data;
            if (!data) {
                return;
            }

            if (data.action === "force-reload") {
                log("Force reload message received from service worker.");
                window.location.reload();
            }
        });
    }

    async function sendEnvironmentType(environmentType) {
        try {
            if (!("serviceWorker" in navigator)) {
                return;
            }

            const registration = activeRegistration || await navigator.serviceWorker.ready;
            const payload = {
                type: "SetEnvironmentType",
                value: environmentType || "DEV"
            };

            if (registration.active) {
                registration.active.postMessage(payload);
            }

            if (registration.waiting) {
                registration.waiting.postMessage(payload);
            }

            if (registration.installing) {
                registration.installing.postMessage(payload);
            }
        } catch (error) {
            console.warn("[SW-Registrator] Failed to send environment type.", error);
        }
    }

    function subscribeForUpdates(dotNetRef) {
        if (!dotNetRef) {
            return;
        }

        subscribers.add(dotNetRef);

        try {
            dotNetRef.invokeMethodAsync("OnServiceWorkerStatusChanged", cloneState());
        } catch (error) {
            console.warn("[SW-Registrator] Failed to send initial state to subscriber.", error);
        }
    }

    function unsubscribeForUpdates(dotNetRef) {
        if (!dotNetRef) {
            return;
        }

        subscribers.delete(dotNetRef);
    }

    window.serviceWorkerInterop = window.serviceWorkerInterop || {};
    window.serviceWorkerInterop.getState = () => cloneState();
    window.serviceWorkerInterop.checkForUpdate = () => checkForUpdate();
    window.serviceWorkerInterop.applyUpdate = () => applyUpdate();
    window.serviceWorkerInterop.repairApp = () => repairApp();
    window.serviceWorkerInterop.enableForceReloadListener = () => enableForceReloadListener();
    window.serviceWorkerInterop.sendEnvironmentType = value => sendEnvironmentType(value);
    window.serviceWorkerInterop.subscribeForUpdates = ref => subscribeForUpdates(ref);
    window.serviceWorkerInterop.unsubscribeForUpdates = ref => unsubscribeForUpdates(ref);

    window.addEventListener("load", () => {
        registerServiceWorker().catch(error => {
            console.error("[SW-Registrator] Unhandled registration error.", error);
        });
    });
})();