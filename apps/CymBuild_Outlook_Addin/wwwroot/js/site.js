// Please see documentation at https://docs.microsoft.com/aspnet/core/client-side/bundling-and-minification
// for details on configuring this project to bundle and minify static web assets.

// Write your JavaScript code.
function onAjaxError(e) {
    console.log(e);

    errorText = e.status;

    if (e.xhr.responseText != "") {
        errorText = e.xhr.responseText;
    }

    console.log(errorText);
    statusUpdate("icon16", errorText);

    if (retryGetAccessToken <= 0) {
        retryGetAccessToken++;
        getMessageFiller(tokenOptions, true, true);
    }
}

function statusUpdate(icon, text) {
    Office.context.mailbox.item.notificationMessages.replaceAsync("status", {
        type: "informationalMessage",
        icon: icon,
        message: text,
        persistent: false
    });
}