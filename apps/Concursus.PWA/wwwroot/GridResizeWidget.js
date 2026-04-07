function adjustColumnWidths() {
    // Check if it's a mobile view
    //var isMobile = window.matchMedia("(max-width: 768px)").matches;

    //if (isMobile) {
    var columns = document.querySelectorAll(".k-table-md colgroup col");

    if (columns && columns.length > 2) {
        for (var i = 0; i < columns.length; i++) {
            columns[i].style.width = "120px";
            console.log("Resetting width for Widget mobile view!");
        }
    }
    // }

    console.log("Applying adjustColumnWidths()");

    //window.onscroll = adjustColumnWidths;
};

function removeAdjustFunction() {
    console.log("Removing adjustColumnWidths()");
    window.onscroll = stickyHeader;
}