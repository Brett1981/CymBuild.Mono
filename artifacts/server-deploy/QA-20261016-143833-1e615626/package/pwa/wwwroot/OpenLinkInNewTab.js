/**
 *
 * Opens a link in a new tab. Should be safe to use
 * with PWA (hyperlinks with <a href=""> might not work).
 */

function openInNewTab(url) {
    window.open(url, '_blank');
};

// Make it available globally
window.openInNewTab = openInNewTab;