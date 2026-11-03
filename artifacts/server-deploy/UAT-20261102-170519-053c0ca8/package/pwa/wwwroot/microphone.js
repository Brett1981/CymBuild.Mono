let mediaRecorder;
let audioChunks = [];

async function startRecording() {
    if (mediaRecorder && mediaRecorder.state !== "inactive") {
        console.warn("A recording is already in progress.");
        return;
    }

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    mediaRecorder = new MediaRecorder(stream);

    mediaRecorder.onstop = function (event) {
        console.log("Recording stopped.");
    };

    mediaRecorder.start();
}

async function stopRecording() {
    return new Promise((resolve, reject) => {
        mediaRecorder.onstop = () => {
            const audioBlob = new Blob(audioChunks, { type: 'audio/wav' });
            resolve(audioBlob);
        };
        mediaRecorder.stop();
    });
}