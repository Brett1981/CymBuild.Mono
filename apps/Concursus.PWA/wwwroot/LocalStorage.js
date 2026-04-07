export function get(key) {
    return window.localStorage.getItem(key);
}

export function set(key, value) {
    window.localStorage.setItem(key, value);
}

export function clear() {
    window.localStorage.clear();
}

export function remove(key) {
    window.localStorage.removeItem(key);
}
//Clears filters for all grids
export function clearAll() {
    const savedValus = { ...window.localStorage };

    for (let i in savedValus) {
        //Do not remove saved page numbers.
        if (!i.includes("_currentPageNumber")) {
            console.log("Removing " + i);
            remove(i);
        }
    }
}