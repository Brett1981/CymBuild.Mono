/* ============================================================================
   CymBuild Service Worker (Published)
   ----------------------------------------------------------------------------
   PURPOSE
   - Cache only true static published assets from the Blazor manifest
   - Keep navigation network-first so new releases win quickly
   - Never cache critical bootstrap/config/auth/API endpoints
   - Preserve offline sync queue handling
   - Support "repair/reset" without requiring users to open F12

   IMPORTANT
   - Cache version is deterministic and tied to assetsManifest.version
   - Do NOT use Date.now() for cache versioning in production
   ============================================================================ */

self.importScripts('./service-worker-assets.js');

const currentManifestVersion = self.assetsManifest?.version || 'dev';
const cacheNamePrefix = 'cymbuild-offline-cache-';
const cacheName = `${cacheNamePrefix}${currentManifestVersion}`;

let currentEnvironmentType = 'DEV';

const offlineAssetsInclude = [
    /\.dll$/i,
    /\.pdb$/i,
    /\.wasm$/i,
    /\.html$/i,
    /\.js$/i,
    /\.json$/i,
    /\.css$/i,
    /\.woff2?$/i,
    /\.png$/i,
    /\.jpe?g$/i,
    /\.gif$/i,
    /\.ico$/i,
    /\.blat$/i,
    /\.dat$/i,
    /\.webcil$/i
];

/* Files/endpoints that must never be cached by the SW */
const offlineAssetsExclude = [
    /^service-worker\.js$/i,
    /^service-worker\.published\.js$/i,
    /^service-worker-assets\.js$/i,
    /^appsettings(\..+)?\.json$/i,
    /^manifest\.json$/i,
    /^sw-registrator\.js$/i,
    /^service-worker-interop\.js$/i,
    /^_framework\/blazor\.boot\.json$/i,
    /^_framework\/blazor\.webassembly\.js$/i,
    /^_content\/Microsoft\.Authentication\.WebAssembly\.Msal\/AuthenticationService\.js$/i
];

const assetUrls = new Set(
    (self.assetsManifest?.assets || [])
        .filter(asset => shouldIncludeAsset(asset.url))
        .map(asset => normalizeAssetPath(asset.url))
);

self.addEventListener('install', event => {
    event.waitUntil(onInstall());
    self.skipWaiting();
});

self.addEventListener('activate', event => {
    event.waitUntil(onActivate());
});

self.addEventListener('message', event => {
    const data = event.data;

    if (!data) {
        return;
    }

    if (data.type === 'SetEnvironmentType') {
        currentEnvironmentType = data.value || 'DEV';
        console.info(`[ServiceWorker] EnvironmentType set to: ${currentEnvironmentType}`);
        return;
    }

    if (data === 'SKIP_WAITING') {
        self.skipWaiting();
        return;
    }

    if (data === 'CLEAR_CACHE_RELOAD') {
        event.waitUntil(clearCacheAndReload());
    }
});

self.addEventListener('fetch', event => {
    const request = event.request;

    if (request.method !== 'GET') {
        return;
    }

    const url = new URL(request.url);

    if (shouldBypassRequest(url, request)) {
        return;
    }

    if (request.mode === 'navigate') {
        event.respondWith(handleNavigationRequest(request));
        return;
    }

    const relativePath = normalizeRequestPath(url);

    if (isNetworkOnlyBootstrapFile(relativePath)) {
        event.respondWith(fetch(request, { cache: 'no-store' }));
        return;
    }

    if (assetUrls.has(relativePath)) {
        event.respondWith(cacheFirstForStaticAsset(request));
        return;
    }

    /* Let all other requests fall through to the network */
});

self.addEventListener('sync', event => {
    if (event.tag === 'syncOfflineQueue') {
        event.waitUntil(processOfflineQueue());
    }
});

async function onInstall() {
    console.info(`[ServiceWorker] Installing version ${currentManifestVersion}`);

    const cache = await caches.open(cacheName);
    const assets = self.assetsManifest?.assets || [];

    for (const asset of assets) {
        if (!shouldIncludeAsset(asset.url)) {
            continue;
        }

        try {
            const request = new Request(asset.url, {
                cache: 'no-cache',
                integrity: asset.hash || undefined
            });

            const response = await fetch(request);

            if (response && response.ok) {
                await cache.put(request, response.clone());
            }
        } catch (error) {
            console.warn(`[ServiceWorker] Failed to pre-cache asset: ${asset.url}`, error);
        }
    }

    console.info(`[ServiceWorker] Install complete for version ${currentManifestVersion}`);
}

async function onActivate() {
    console.info(`[ServiceWorker] Activating version ${currentManifestVersion}`);

    const cacheKeys = await caches.keys();

    await Promise.all(
        cacheKeys
            .filter(key => key.startsWith(cacheNamePrefix) && key !== cacheName)
            .map(key => caches.delete(key))
    );

    await self.clients.claim();

    if ('navigationPreload' in self.registration) {
        try {
            await self.registration.navigationPreload.enable();
        } catch (error) {
            console.warn('[ServiceWorker] Navigation preload enable failed.', error);
        }
    }

    console.info(`[ServiceWorker] Activation complete for version ${currentManifestVersion}`);
}

async function handleNavigationRequest(request) {
    const cache = await caches.open(cacheName);
    const cachedIndex = await cache.match(new Request('index.html'));

    try {
        const preloadResponse = await self.registration.navigationPreload?.getState?.()
            ? await (await self.registration.navigationPreload.getState()).enabled
                ? null
                : null
            : null;

        const networkResponse = await fetch(request, { cache: 'no-store' });

        if (networkResponse && networkResponse.ok) {
            return networkResponse;
        }

        return cachedIndex || networkResponse;
    } catch (error) {
        console.warn('[ServiceWorker] Navigation network fetch failed. Serving cached index.', error);

        if (cachedIndex) {
            return cachedIndex;
        }

        return Response.error();
    }
}

async function cacheFirstForStaticAsset(request) {
    const cache = await caches.open(cacheName);
    const cachedResponse = await cache.match(request);

    if (cachedResponse) {
        return cachedResponse;
    }

    const networkResponse = await fetch(request);

    if (networkResponse && networkResponse.ok) {
        await cache.put(request, networkResponse.clone());
    }

    return networkResponse;
}

async function clearCacheAndReload() {
    console.warn('[ServiceWorker] CLEAR_CACHE_RELOAD requested.');

    const cacheKeys = await caches.keys();
    await Promise.all(cacheKeys.map(key => caches.delete(key)));

    await clearIndexedDbDatabases();

    const windowClients = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true
    });

    for (const client of windowClients) {
        client.postMessage({ action: 'force-reload' });
    }

    try {
        await self.registration.unregister();
    } catch (error) {
        console.warn('[ServiceWorker] Unregister failed during repair/reset.', error);
    }
}

async function clearIndexedDbDatabases() {
    if (!self.indexedDB || typeof indexedDB.databases !== 'function') {
        return;
    }

    try {
        const databases = await indexedDB.databases();

        await Promise.all(
            databases
                .filter(db => !!db.name)
                .map(db => new Promise(resolve => {
                    const deleteRequest = indexedDB.deleteDatabase(db.name);
                    deleteRequest.onsuccess = () => resolve();
                    deleteRequest.onerror = () => resolve();
                    deleteRequest.onblocked = () => resolve();
                }))
        );
    } catch (error) {
        console.warn('[ServiceWorker] IndexedDB cleanup failed.', error);
    }
}

function shouldIncludeAsset(url) {
    const normalized = normalizeAssetPath(url);

    return offlineAssetsInclude.some(pattern => pattern.test(normalized))
        && !offlineAssetsExclude.some(pattern => pattern.test(normalized));
}

function normalizeAssetPath(url) {
    return url.replace(/^\.\//, '').replace(/^\/+/, '');
}

function normalizeRequestPath(url) {
    return url.pathname.replace(/^\/+/, '');
}

function isNetworkOnlyBootstrapFile(relativePath) {
    return (
        /^service-worker\.js$/i.test(relativePath) ||
        /^service-worker-assets\.js$/i.test(relativePath) ||
        /^appsettings(\..+)?\.json$/i.test(relativePath) ||
        /^manifest\.json$/i.test(relativePath) ||
        /^sw-registrator\.js$/i.test(relativePath) ||
        /^service-worker-interop\.js$/i.test(relativePath) ||
        /^_framework\/blazor\.boot\.json$/i.test(relativePath) ||
        /^_framework\/blazor\.webassembly\.js$/i.test(relativePath) ||
        /^_content\/Microsoft\.Authentication\.WebAssembly\.Msal\/AuthenticationService\.js$/i.test(relativePath)
    );
}

function shouldBypassRequest(url, request) {
    const path = url.pathname.toLowerCase();

    if (path.startsWith('/api/')) return true;
    if (path.startsWith('/authentication/')) return true;
    if (path.includes('/fileprocessinghub')) return true;
    if (path.includes('/negotiate')) return true;
    if (path.includes('/grpc')) return true;
    if (request.headers.get('x-grpc-web')) return true;
    if (request.headers.get('content-type')?.includes('application/grpc')) return true;

    return false;
}

/* ============================================================================
   Offline sync queue support (preserved from existing implementation)
   ============================================================================ */

async function getAllSyncItems(dbName, storeName) {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open(dbName, 1);

        request.onerror = () => reject('Failed to open DB');

        request.onupgradeneeded = event => {
            const db = event.target.result;
            if (!db.objectStoreNames.contains(storeName)) {
                db.createObjectStore(storeName, { keyPath: 'Id' });
            }
        };

        request.onsuccess = () => {
            const db = request.result;
            const tx = db.transaction(storeName, 'readonly');
            const store = tx.objectStore(storeName);

            const items = [];
            const cursorRequest = store.openCursor();

            cursorRequest.onsuccess = event => {
                const cursor = event.target.result;
                if (cursor) {
                    items.push(cursor.value);
                    cursor.continue();
                } else {
                    resolve(items);
                }
            };

            cursorRequest.onerror = () => reject('Cursor error');
        };
    });
}

async function deleteSyncItem(dbName, storeName, key) {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open(dbName, 1);

        request.onerror = () => reject('Failed to open DB');

        request.onupgradeneeded = event => {
            const db = event.target.result;
            if (!db.objectStoreNames.contains(storeName)) {
                db.createObjectStore(storeName, { keyPath: 'Id' });
            }
        };

        request.onsuccess = () => {
            const db = request.result;
            const tx = db.transaction(storeName, 'readwrite');
            const store = tx.objectStore(storeName);

            const deleteRequest = store.delete(key);
            deleteRequest.onsuccess = () => resolve();
            deleteRequest.onerror = () => reject('Delete error');
        };
    });
}

async function processOfflineQueue() {
    const dbName = `CymBuildDB_${getEnvironmentType()}`;
    const queue = await getAllSyncItems(dbName, 'SyncQueue');

    if (!queue || queue.length === 0) {
        console.info('[ServiceWorker] No offline sync items to process.');
        return;
    }

    for (const item of queue) {
        try {
            const response = await fetch(item.Endpoint, {
                method: item.Method,
                headers: { 'Content-Type': 'application/json' },
                body: item.Payload
            });

            if (response.ok) {
                await deleteSyncItem(dbName, 'SyncQueue', item.Id);
                console.info(`[ServiceWorker] Synced and removed: ${item.Endpoint}`);
            } else {
                console.warn(`[ServiceWorker] Failed to sync: ${item.Endpoint}`, await response.text());
            }
        } catch (error) {
            console.error(`[ServiceWorker] Error syncing ${item.Endpoint}:`, error);
        }
    }
}

function getEnvironmentType() {
    return currentEnvironmentType || 'DEV';
}