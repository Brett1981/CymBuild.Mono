window.isDevice = function () {
    try {
        // Use User-Agent Client Hints if available
        if (navigator.userAgentData) {
            const isMobile = navigator.userAgentData.mobile;
            const platform = navigator.userAgentData.platform || '';

            // Covers Android, iOS (but not iPad in DevTools)
            if (isMobile || /android|ios/i.test(platform)) return true;
        }

        const ua = navigator.userAgent.toLowerCase();
        const platform = navigator.platform.toLowerCase();

        const mobileIndicators = [
            'android', 'iphone', 'ipad', 'ipod', 'blackberry', 'iemobile', 'opera mini', 'mobile'
        ];

        const isIpad = /ipad/.test(ua) || (platform === 'macintel' && navigator.maxTouchPoints > 1);
        const matched = mobileIndicators.some(indicator => ua.includes(indicator));

        const result = matched || isIpad;
        console.log("isDevice result:", result);
        return result;
    } catch (e) {
        console.warn('Device detection failed:', e);
        return false;
    }
};

function adjustModalSize() {
    var modal = document.querySelector('.modal-dialog');
    if (window.innerWidth < 768) {
        modal.style.width = '95%';
    } else {
        modal.style.width = '50%';
    }
}

function getWindowSize() {
    return window.innerWidth;
}