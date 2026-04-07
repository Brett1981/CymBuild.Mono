(function () {
    "use strict";

    const DEFAULT_STORES = ["SyncQueue", "ErrorQueue"];

    function normaliseStoreNames(storeNames) {
        const names = Array.isArray(storeNames) ? storeNames.slice() : [];
        const combined = DEFAULT_STORES.concat(names);

        return [...new Set(
            combined
                .filter(name => typeof name === "string")
                .map(name => name.trim())
                .filter(name => name.length > 0)
        )];
    }

    function closeDbQuietly(db) {
        try {
            if (db) {
                db.close();
            }
        } catch {
            // Ignore close failures.
        }
    }

    function waitForTransaction(tx) {
        return new Promise((resolve, reject) => {
            tx.oncomplete = () => resolve();
            tx.onerror = () => reject(tx.error || new Error("IndexedDB transaction failed."));
            tx.onabort = () => reject(tx.error || new Error("IndexedDB transaction aborted."));
        });
    }

    function promisifyRequest(request, errorMessage) {
        return new Promise((resolve, reject) => {
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error || new Error(errorMessage));
        });
    }

    async function openExistingDatabase(dbName) {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(dbName);

            request.onerror = () => {
                reject(request.error || new Error(`Failed to open IndexedDB database '${dbName}'.`));
            };

            request.onsuccess = () => {
                resolve(request.result);
            };

            request.onupgradeneeded = () => {
                // This can occur if the DB does not exist yet. In that case the version is new (usually 1)
                // and request.result is valid. We do not create stores here because we want one consistent path
                // via ensureDatabaseHasStores().
            };
        });
    }

    async function ensureDatabaseHasStores(dbName, storeNames) {
        const requiredStores = normaliseStoreNames(storeNames);

        let db = await openExistingDatabase(dbName);

        try {
            const missingStores = requiredStores.filter(name => !db.objectStoreNames.contains(name));
            if (missingStores.length === 0) {
                return db;
            }

            const nextVersion = (db.version || 1) + 1;
            closeDbQuietly(db);

            db = await new Promise((resolve, reject) => {
                const upgradeRequest = indexedDB.open(dbName, nextVersion);

                upgradeRequest.onerror = () => {
                    reject(upgradeRequest.error || new Error(`Failed to upgrade IndexedDB database '${dbName}'.`));
                };

                upgradeRequest.onblocked = () => {
                    reject(new Error(
                        `IndexedDB upgrade for '${dbName}' was blocked. Another tab may still have the database open.`
                    ));
                };

                upgradeRequest.onupgradeneeded = (event) => {
                    const upgradeDb = event.target.result;

                    requiredStores.forEach(name => {
                        if (!upgradeDb.objectStoreNames.contains(name)) {
                            upgradeDb.createObjectStore(name, { keyPath: "Id" });
                        }
                    });
                };

                upgradeRequest.onsuccess = () => {
                    resolve(upgradeRequest.result);
                };
            });

            return db;
        } catch (error) {
            closeDbQuietly(db);
            throw error;
        }
    }

    async function withStore(dbName, storeName, mode, action) {
        const db = await ensureDatabaseHasStores(dbName, [storeName]);

        try {
            const tx = db.transaction(storeName, mode);
            const store = tx.objectStore(storeName);

            const result = await action(store, tx);
            await waitForTransaction(tx);

            return result;
        } finally {
            closeDbQuietly(db);
        }
    }

    const indexedDbInterop = {
        openDb: async function (dbName, version = 1, storeNames = []) {
            // Preserve signature for compatibility. `version` is ignored intentionally because
            // we now self-manage upgrades based on missing stores.
            void version;
            return ensureDatabaseHasStores(dbName, storeNames);
        },

        setItem: async function (dbName, storeName, key, json) {
            const data = JSON.parse(json);
            if (!data.Id) {
                data.Id = key;
            }

            await withStore(dbName, storeName, "readwrite", async (store) => {
                const request = store.put(data);
                await promisifyRequest(request, `Error saving item to store '${storeName}'.`);
                return null;
            });
        },

        getItem: async function (dbName, storeName, key) {
            return withStore(dbName, storeName, "readonly", async (store) => {
                const request = store.get(key);
                const result = await promisifyRequest(request, `Error fetching item from store '${storeName}'.`);
                return result ? JSON.stringify(result) : null;
            });
        },

        setItems: async function (dbName, storeName, itemsJson) {
            const items = JSON.parse(itemsJson);

            await withStore(dbName, storeName, "readwrite", async (store) => {
                if (Array.isArray(items)) {
                    for (let i = 0; i < items.length; i++) {
                        const item = items[i];
                        if (item && !item.Id) {
                            item.Id = i.toString();
                        }

                        const request = store.put(item);
                        await promisifyRequest(request, `Error writing bulk item to store '${storeName}'.`);
                    }
                } else {
                    for (const key in items) {
                        if (!Object.prototype.hasOwnProperty.call(items, key)) {
                            continue;
                        }

                        const item = items[key];
                        if (item && !item.Id) {
                            item.Id = key;
                        }

                        const request = store.put(item);
                        await promisifyRequest(request, `Error writing bulk item to store '${storeName}'.`);
                    }
                }

                return null;
            });
        },

        getAll: async function (dbName, storeName) {
            return withStore(dbName, storeName, "readonly", async (store) => {
                const request = store.getAll();
                const result = await promisifyRequest(request, `Error fetching all items from store '${storeName}'.`);
                return JSON.stringify(result || []);
            });
        },

        deleteItem: async function (dbName, storeName, key) {
            await withStore(dbName, storeName, "readwrite", async (store) => {
                const request = store.delete(key);
                await promisifyRequest(request, `Error deleting item from store '${storeName}'.`);
                return null;
            });
        },

        clearStore: async function (dbName, storeName) {
            await withStore(dbName, storeName, "readwrite", async (store) => {
                const request = store.clear();
                await promisifyRequest(request, `Error clearing store '${storeName}'.`);
                return null;
            });
        },

        deleteDatabase: async function (dbName) {
            return new Promise((resolve, reject) => {
                const request = indexedDB.deleteDatabase(dbName);

                request.onsuccess = () => resolve();
                request.onerror = () => reject(request.error || new Error(`Failed to delete database '${dbName}'.`));
                request.onblocked = () => reject(new Error(`Delete database '${dbName}' was blocked.`));
            });
        }
    };

    window.indexedDbInterop = indexedDbInterop;

    window.syncInterop = {
        triggerSync: async function () {
            if ("serviceWorker" in navigator && "SyncManager" in window) {
                const reg = await navigator.serviceWorker.ready;
                await reg.sync.register("syncOfflineQueue");
                console.log("Sync registered: syncOfflineQueue");
            } else {
                console.warn("Background sync not supported in this browser");
            }
        },

        postData: async function (endpoint, method, payload) {
            try {
                const response = await fetch(endpoint, {
                    method: method,
                    headers: { "Content-Type": "application/json" },
                    body: payload
                });

                if (!response.ok) {
                    const err = await response.text();
                    throw new Error(`${method} to ${endpoint} failed. Server responded with: ${err}`);
                }

                console.log(`${method} to ${endpoint} succeeded`);
            } catch (err) {
                console.error("syncInterop.postData error:", err);
                throw err;
            }
        }
    };
})();