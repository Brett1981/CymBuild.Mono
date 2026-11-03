var scrollPos = 0;
function GetScrollBarPos() {
    scrollPos = document.documentElement.scrollTop;
    console.log("GetScrollBarPos() => " + scrollPos);
}

function SetScrollBarPos() {
    // Restore the saved vertical scroll position

    try {
        setTimeout(() => {
            window.scrollTo({
                top: scrollPos, // Set the vertical scroll position
                behavior: 'instant' // Optional: Use 'smooth' for a smooth scroll effect
            });
        }, 1)
        console.log("SetScrollBarPos() => " + scrollPos);
    }
    catch (e) {
        console.log(e);
    }
}