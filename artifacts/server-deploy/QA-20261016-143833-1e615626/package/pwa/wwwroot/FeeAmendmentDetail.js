// Finds the "Stages", "Meetings", and "Visits" property group cards
// and applies a fixed width to their input labels (.input-group-text)
// so that all fields align consistently regardless of label length.
window.findStageAndMeetingElements = () => {
    console.log("Running findStageAndMeetingElements");

    const inputFields = [...document.querySelectorAll('.card')]
        .filter(card => {
            const title = card.querySelector('.card-title')?.textContent.trim();
            return title === 'Stages' || title === 'Meetings' || title === 'Visits';
        })
        .flatMap(card => [...card.querySelectorAll('.input-group-text')]);

    console.log(inputFields);

    inputFields.forEach(element => {
        element.style.width = '200px';
    });
};