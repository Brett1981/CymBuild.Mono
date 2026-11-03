function sendTokenToIframe(token) {
    const iframe = document.getElementById("secureIframe");
    if (iframe) {
        iframe.contentWindow.postMessage({ type: "accessToken", token: token }, "*");
    }
}

window.addEventListener("message", function (event) {
    if (event.data.type === "accessToken") {
        console.log("Access Token received in iframe:", event.data.token);
        // Use the token for authentication inside the iframe
        authenticateWithToken(event.data.token);
    }
});

function authenticateWithToken(token) {
    // Custom logic to use the token in the iframe
}