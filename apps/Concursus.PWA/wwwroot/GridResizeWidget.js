let adjustColumnWidthsHandler = null;

function adjustColumnWidthsCore() {
    const columns = document.querySelectorAll(".k-table-md colgroup col");

    if (columns && columns.length > 2) {
        for (let i = 0; i < columns.length; i++) {
            columns[i].style.width = "120px";
        }
    }

    console.log("Applying adjustColumnWidths()");
}

window.adjustColumnWidths = function () {
    try {
        adjustColumnWidthsCore();
    } catch (err) {
        console.warn("adjustColumnWidths failed safely:", err);
    }
};

window.registerAdjustFunction = function () {
    try {
        if (!adjustColumnWidthsHandler) {
            adjustColumnWidthsHandler = adjustColumnWidthsCore;
            window.addEventListener("scroll", adjustColumnWidthsHandler, { passive: true });
            console.log("Registered adjustColumnWidths scroll handler.");
        }
    } catch (err) {
        console.warn("registerAdjustFunction failed safely:", err);
    }
};

window.removeAdjustFunction = function () {
    try {
        if (adjustColumnWidthsHandler) {
            window.removeEventListener("scroll", adjustColumnWidthsHandler);
            adjustColumnWidthsHandler = null;
            console.log("Removed adjustColumnWidths scroll handler.");
        }
    } catch (err) {
        console.warn("removeAdjustFunction failed safely:", err);
    }
};