/**
 * Formats the slot headers in the scheduler
 *
 * If the header is "00:00", it becomes "AM", "PM" otherwise.
 */
function FormetSchedulerTimeSlotHeaders() {
    try {
        console.log("FormetSchedulerTimeSlotHeaders -> Start");

        const timeCells = Array.from(document.querySelectorAll('.k-scheduler-cell.k-heading-cell'));

        const filteredTimeCells = timeCells.filter(cell => cell.textContent.includes('12:00') || cell.textContent.includes("00:00"));

        filteredTimeCells.forEach(cell => {
            var content = cell.textContent;

            if (cell.textContent.includes("00:00")) {
                cell.textContent = "AM";
            }
            else if (cell.textContent.includes("12:00")) {
                cell.textContent = "PM";
            }
        });
    }
    catch (e) {
        console.log(e);
    }
}