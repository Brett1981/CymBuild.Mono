// instead of `export function …` just attach to window
window.registerDiagnosticsToggle = function (dotnetHelper) {
    document.addEventListener('keydown', e => {
        // Ctrl + Shift + X
        if (e.ctrlKey && e.shiftKey && e.code === 'KeyX') {
            dotnetHelper.invokeMethodAsync('ToggleDiagnostics');
            e.preventDefault();
        }
    });
};

window.cymbuild_registerGridFocusCallback = function (dotnetRef) {
    window.addEventListener('focus', function () {
        dotnetRef.invokeMethodAsync('OnGridGainedFocus');
    });
};