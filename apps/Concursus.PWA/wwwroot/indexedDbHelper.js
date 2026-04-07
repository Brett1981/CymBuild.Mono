const indexedDbInterop = {
    // Open a connection to the database
    openDatabase: function (dbName) {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(dbName, 1);

            request.onupgradeneeded = (event) => {
                const db = event.target.result;

                // Create object stores for each gRPC message type
                const stores = [
                    'EntityPropertyActions', 'EntityDataType', 'EntityHoBT',
                    'EntityProperty', 'EntityPropertyGroup', 'EntityQuery',
                    'EntityQueryParameter', 'EntityType', 'GridDefinition',
                    'GridViewColumnDefinition', 'GridViewDefinition', 'Group',
                    'Language', 'LanguageLabel', 'LanguageLabelTranslation',
                    'User', 'UserGroup', 'UserPreferences'
                ];

                stores.forEach(store => {
                    if (!db.objectStoreNames.contains(store)) {
                        db.createObjectStore(store, { keyPath: 'Guid' });
                    }
                });
            };

            request.onsuccess = (event) => {
                resolve(event.target.result);
            };

            request.onerror = (event) => {
                reject(event.target.error);
            };
        });
    },

    // Add an item to the database
    addItem: function (dbName, storeName, item) {
        return this.openDatabase(dbName).then(db => {
            return new Promise((resolve, reject) => {
                const transaction = db.transaction([storeName], 'readwrite');
                const store = transaction.objectStore(storeName);
                const request = store.add(item);

                request.onsuccess = () => {
                    resolve();
                };

                request.onerror = (event) => {
                    reject(event.target.error);
                };
            });
        });
    },

    // Get an item from the database
    getItem: function (dbName, storeName, key) {
        return this.openDatabase(dbName).then(db => {
            return new Promise((resolve, reject) => {
                const transaction = db.transaction([storeName], 'readonly');
                const store = transaction.objectStore(storeName);
                const request = store.get(key);

                request.onsuccess = (event) => {
                    resolve(event.target.result);
                };

                request.onerror = (event) => {
                    reject(event.target.error);
                };
            });
        });
    },

    // Update an item in the database
    updateItem: function (dbName, storeName, item) {
        return this.openDatabase(dbName).then(db => {
            return new Promise((resolve, reject) => {
                const transaction = db.transaction([storeName], 'readwrite');
                const store = transaction.objectStore(storeName);
                const request = store.put(item);

                request.onsuccess = () => {
                    resolve();
                };

                request.onerror = (event) => {
                    reject(event.target.error);
                };
            });
        });
    },

    // Delete an item from the database
    deleteItem: function (dbName, storeName, key) {
        return this.openDatabase(dbName).then(db => {
            return new Promise((resolve, reject) => {
                const transaction = db.transaction([storeName], 'readwrite');
                const store = transaction.objectStore(storeName);
                const request = store.delete(key);

                request.onsuccess = () => {
                    resolve();
                };

                request.onerror = (event) => {
                    reject(event.target.error);
                };
            });
        });
    }
};

// Make the helper available in both main thread and worker context
if (typeof window !== 'undefined') {
    window.indexedDbInterop = indexedDbInterop;
} else if (typeof self !== 'undefined') {
    self.indexedDbInterop = indexedDbInterop;
}