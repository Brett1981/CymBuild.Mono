self.onmessage = function (e) {
    const files = e.data.files;
    const storageUrl = e.data.storageUrl;
    const processedFiles = [];

    console.log("Worker: Received files for processing. Total files:", files.length);

    files.forEach((file, index) => {
        console.log(`Worker: Starting to process file ${index + 1}/${files.length} - ${file.name}`);

        processFile(file)
            .then(processedFile => {
                processedFile.storageUrl = storageUrl;

                if (!processedFile.content) {
                    console.error(`Worker: File content is empty for file ${file.name}`);
                } else {
                    console.log(`Worker: Successfully processed file - ${file.name}`);
                }

                processedFiles.push(processedFile);

                if (processedFiles.length === files.length) {
                    console.log("Worker: All files processed. Sending processed files back.");
                    self.postMessage(processedFiles);
                }
            })
            .catch(error => {
                console.error(`Worker: Error processing file ${file.name}:`, error);
                processedFiles.push({
                    name: file.name,
                    size: file.size,
                    content: null, // Ensure content is null on error
                    error: error.message,
                    storageUrl: storageUrl
                });

                if (processedFiles.length === files.length) {
                    console.log("Worker: All files processed with some errors. Sending processed files back.");
                    self.postMessage(processedFiles);
                }
            });
    });
};

function processFile(file) {
    return new Promise((resolve, reject) => {
        console.log(`Worker: Reading file ${file.name} as DataURL`);

        try {
            const reader = new FileReader();

            reader.onload = function (event) {
                const result = event.target.result;

                if (!result) {
                    console.error(`Worker: FileReader returned an empty result for file ${file.name}`);
                    return reject(new Error(`FileReader returned an empty result for file ${file.name}`));
                }

                console.log(`Worker: File read successfully - ${file.name}`);
                const base64String = result.split(',')[1]; // Extract Base64 string

                if (!base64String) {
                    console.error(`Worker: Base64 content extraction failed for file ${file.name}`);
                    return reject(new Error(`Base64 content extraction failed for file ${file.name}`));
                }

                resolve({
                    name: file.name,
                    size: file.size,
                    content: base64String,
                    mimeType: file.type
                });
            };

            reader.onerror = function (error) {
                console.error(`Worker: Error reading file ${file.name}:`, error);
                reject(new Error(`Failed to read file ${file.name}`));
            };

            reader.readAsDataURL(file);
        } catch (error) {
            console.error(`Worker: Exception occurred while processing file ${file.name}:`, error);
            reject(error);
        }
    });
}