function throttle(func, limit) {
    let inThrottle;
    return function (...args) {
        if (!inThrottle) {
            func.apply(this, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

//window.triggerFileDownload = (fileName, url) => {
//    const anchorElement = document.createElement('a');
//    anchorElement.href = url;
//    anchorElement.download = fileName ?? '';
//    anchorElement.click();
//    anchorElement.remove();
//};

window.triggerFileDownload = (fileName, url) => {
    const extension = fileName.split('.').pop().toLowerCase();
    let mimeType = "application/octet-stream"; // Default fallback

    if (extension === "pdf") {
        mimeType = "application/pdf";
    } else if (extension === "docx") {
        mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    } else if (extension === "xlsx") {
        mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    }

    fetch(url)
        .then(response => response.blob())
        .then(blob => {
            const fileBlob = new Blob([blob], { type: mimeType });
            const link = document.createElement("a");
            link.href = URL.createObjectURL(fileBlob);
            link.download = fileName;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        })
        .catch(error => console.error("Download failed:", error));
};

window.triggerResize = () => {
    setTimeout(() => {
        window.dispatchEvent(new Event('resize'));
    }, 100);
};

window.BlazorDownloadFile = (filename, contentType, base64Data) => {
    const link = document.createElement('a');
    link.download = filename;
    link.href = `data:${contentType};base64,${base64Data}`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
};

window.triggerPDFFileDownload = (fileName, fileBytes) => {
    var blob = new Blob([fileBytes], { type: 'application/pdf' });
    //var blob = new Blob([fileBytes], { type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' });
    var link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = fileName;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

// Create a web worker instance
const fileWorker = new Worker('fileWorker.js');

fileWorker.onmessage = function (e) {
    // Handle the results received from the worker
    const processedFiles = e.data;
    console.log("Files received from worker: ", processedFiles);

    // Convert the array of processed files to a JSON string
    const processedFilesJson = JSON.stringify(processedFiles);

    // Directly invoke the static .NET method without passing the DotNetObjectReference
    DotNet.invokeMethodAsync('Concursus.PWA', 'HandleProcessedFilesStatic', processedFilesJson)
        .then(() => console.log('Files processed and sent to C#'))
        .catch(err => console.error('Error invoking HandleProcessedFiles:', err));
};

function openFileDialog(inputElement) {
    return new Promise((resolve, reject) => {
        let isOpened = false;

        inputElement.onchange = () => {
            const files = Array.from(inputElement.files);
            if (files.length > 0) {
                isOpened = true;
                resolve(files);
            }
        };

        // Check if the dialog is opened
        setTimeout(() => {
            if (!isOpened) {
                reject("File dialog was not opened.");
            }
        }, 500); // Wait for 500ms to see if dialog was opened

        inputElement.click(); // Try to open the dialog
    });
}

window.openGallery = (storageUrl) => {
    return new Promise((resolve) => {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.multiple = true;

        input.onchange = () => {
            const files = Array.from(input.files);
            const processedFiles = files.map(file => ({
                name: file.name,
                size: file.size,
                mimeType: file.type,
                content: null, // To be populated by worker
                storageUrl: storageUrl // Include storageUrl
            }));

            fileWorker.postMessage({ files, storageUrl });
            console.log("Files and storage URL passed to worker for processing");

            fileWorker.onmessage = function (e) {
                const workerFiles = e.data;
                workerFiles.forEach((file, index) => {
                    processedFiles[index].content = file.content;
                });
                console.log("Processed files received from worker: ", processedFiles);
                resolve(processedFiles);
            };
        };

        input.click();
    });
};

async function openCameraWithMediaDevices() {
    return new Promise(async (resolve, reject) => {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ video: true });
            const videoElement = document.createElement('video');
            videoElement.srcObject = stream;
            videoElement.play();

            const takePicture = () => {
                const canvas = document.createElement('canvas');
                canvas.width = videoElement.videoWidth;
                canvas.height = videoElement.videoHeight;
                canvas.getContext('2d').drawImage(videoElement, 0, 0);
                return canvas.toDataURL('image/png');
            };

            const capturedImages = [];

            // Create UI for capturing images
            const captureButton = document.createElement('button');
            captureButton.textContent = 'Capture';
            captureButton.onclick = () => {
                capturedImages.push(takePicture());
                console.log("Image captured, total:", capturedImages.length);
            };

            const finishButton = document.createElement('button');
            finishButton.textContent = 'Finish';
            finishButton.onclick = () => {
                stream.getTracks().forEach(track => track.stop());
                videoElement.remove();
                captureButton.remove();
                finishButton.remove();
                resolve(capturedImages);
            };

            document.body.append(videoElement, captureButton, finishButton);
        } catch (error) {
            reject(error);
        }
    });
}

window.openCamera = (storageUrl) => {
    return new Promise((resolve) => {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.capture = 'camera';
        input.multiple = true; // Allow multiple photos

        input.onchange = () => {
            const files = Array.from(input.files);
            const processedFiles = files.map(file => ({
                name: file.name,
                size: file.size,
                mimeType: file.type,
                content: null, // To be populated by worker
                storageUrl: storageUrl // Include storageUrl
            }));

            // Pass files to the worker for processing
            fileWorker.postMessage({ files, storageUrl });
            console.log("Camera files and storage URL passed to worker for processing");

            fileWorker.onmessage = function (e) {
                const workerFiles = e.data;
                workerFiles.forEach((file, index) => {
                    processedFiles[index].content = file.content;
                });
                console.log("Processed files received from worker: ", processedFiles);
                resolve(processedFiles);
            };
        };

        // Trigger the native camera app
        input.click();
    });
};

// Assign the Blazor instance when the page is loaded.
window.handleProcessedFiles = function (processedFilesJson) {
    if (window.blazorInstance) {
        DotNet.invokeMethodAsync('Concursus.PWA', 'HandleProcessedFilesStatic', processedFilesJson, window.blazorInstance)
            .then(() => console.log('Files processed and sent to C#'))
            .catch(err => console.error('Error invoking HandleProcessedFiles:', err));
    } else {
        console.error('Blazor instance is not initialized.');
    }
};

// Ensure the DotNetObjectReference is set correctly
document.addEventListener('DOMContentLoaded', function () {
    if (!window.blazorInstance) {
        // Ensure blazorInstance is not undefined before creating the reference.
        window.blazorInstance = DotNet.createJSObjectReference({});
    }
});