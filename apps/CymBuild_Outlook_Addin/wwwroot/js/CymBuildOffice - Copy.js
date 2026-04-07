var retryGetAccessToken = 0;
var bootstrapToken;
var tokenTime;
var item;
var _mailbox;
var _customProps;
var _settings;
var _mailboxName;
var _refreshingToken = false;

var filingDestinationPropertyName = "CymBuildOutlookFilingDestination";
var doNotFilePropertyName = "DoNotFile";
var filingHistoryPropertyName = "CymBuildOutlookFilingHistory";
var filingPendingCategoryName = "FilingPending";
var lastFiledLocationSettingName = "LastFiledLocation";
var buttonExpansionSettingName = "ButtonsExpanded";
var filingMailbox;
var tokenOptions = { allowSignInPrompt: true, allowConsentPrompt: true, forMSGraphAccess: false };

// To support IE (which uses ES5), we have to create a Promise object for the global context.
if (!window.Promise) {
    window.Promise = Office.Promise;
}

// The initialize function is required for all add-ins.
Office.onReady(function (reason) {
    $(document).ready(function () {
        Office.context.mailbox.addHandlerAsync(Office.EventType.ItemChanged, itemChanged);

        applyOfficeTheme();

        getMessageFiller(tokenOptions);
        
        if (_mailbox.item.itemId != undefined) {
            $("#composeHelp").hide();
            $("#readHelp").show();
        } else {
            $("#composeHelp").show();
            $("#readHelp").hide();
        }

        var _expandButtons = _settings.get(buttonExpansionSettingName);

        if (_expandButtons) {
            expandButtons();
        } else {
            collapseButtons();
        }
        // Log the _mailbox and _settings objects to the console
        logMailboxAndSettings();
        // Ensure Blazor is fully loaded before sending mailbox data
        waitForBlazor(() => {
            sendMailboxDataToBlazor();
        });
    });
});

function waitForBlazor(callback) {
    if (typeof Blazor === 'undefined' && Blazor.invokeMethodAsync) {
        Blazor.start().then(() => {
            callback();
        });
    } else {
        console.log("Blazor is not defined yet. Waiting...");
        setTimeout(() => waitForBlazor(callback), 100);
    }
}
function logMailboxAndSettings() {
    _mailbox = Office.context.mailbox;
    _settings = Office.context.roamingSettings;

    // Extract relevant information from _mailbox
    const mailboxInfo = {
        userProfile: {
            displayName: _mailbox.userProfile.displayName,
            emailAddress: _mailbox.userProfile.emailAddress,
            id: _mailbox.userProfile.id
        },
        item: _mailbox.item ? {
            itemId: _mailbox.item.itemId,
            subject: _mailbox.item.subject,
            body: _mailbox.item.body,
            sender: _mailbox.item.sender,
            toRecipients: _mailbox.item.toRecipients,
            ccRecipients: _mailbox.item.ccRecipients,
            bccRecipients: _mailbox.item.bccRecipients,
            attachments: _mailbox.item.attachments,
            conversationId: _mailbox.item.conversationId,
            meeting: _mailbox.item.meeting
        } : null
    };

    // Extract relevant information from _settings
    const settingsInfo = {};
    for (const key in _settings) {
        if (_settings.hasOwnProperty(key)) {
            settingsInfo[key] = _settings.get(key);
        }
    }

    console.log("Mailbox Object:", mailboxInfo);
    console.log("Settings Object:", settingsInfo);
}
// Function to safely stringify objects with circular references
function safeStringify(obj, space = 2) {
    const seen = new WeakSet();
    return JSON.stringify(obj, function (key, value) {
        if (typeof value === "object" && value !== null) {
            if (seen.has(value)) {
                return "[Circular]";
            }
            seen.add(value);
        }
        return value;
    }, space);
}

function increase_brightness(hex, percent) {
    // strip the leading # if it's there
    hex = hex.replace(/^\s*#|\s*$/g, '');

    // convert 3 char codes --> 6, e.g. `E0F` --> `EE00FF`
    if (hex.length == 3) {
        hex = hex.replace(/(.)/g, '$1$1');
    }

    var r = parseInt(hex.substr(0, 2), 16),
        g = parseInt(hex.substr(2, 2), 16),
        b = parseInt(hex.substr(4, 2), 16);

    return '#' +
        ((0 | (1 << 8) + r + (256 - r) * percent / 100).toString(16)).substr(1) +
        ((0 | (1 << 8) + g + (256 - g) * percent / 100).toString(16)).substr(1) +
        ((0 | (1 << 8) + b + (256 - b) * percent / 100).toString(16)).substr(1);
}

function applyOfficeTheme() {
    try {
        // Get office theme colors.
        const bodyBackgroundColor = Office.context.officeTheme.bodyBackgroundColor;
        const bodyForegroundColor = Office.context.officeTheme.bodyForegroundColor;
        const controlBackgroundColor = Office.context.officeTheme.controlBackgroundColor;
        const controlForegroundColor = Office.context.officeTheme.controlForegroundColor;

        // Apply body background color to a CSS class.
        $('body').css('background-color', bodyBackgroundColor);
        $('#content-main').css('background-color', bodyBackgroundColor);
        $('#content-main').css('color', bodyForegroundColor);
        $('.k-tabstrip-content').css('background-color', controlBackgroundColor);
        $('.k-tabstrip-content').css('color', controlForegroundColor);
        $('.k-grid').css('background-color', controlBackgroundColor);
        $('.k-grid').css('color', controlForegroundColor);
        $('.k-input').css('background-color', controlBackgroundColor);
        $('.k-input').css('color', controlForegroundColor);

        if (bodyBackgroundColor != "#ffffff") {
            $('.k-toolbar').css('background-color', increase_brightness(bodyBackgroundColor, 25));
            $('.k-toolbar').css('color', bodyForegroundColor);
            $('.k-grid-header').css('background-color', increase_brightness(bodyBackgroundColor, 30));
            $('.k-grid-header').css('color', bodyForegroundColor);
            $('.k-grid-pager').css('background-color', increase_brightness(bodyBackgroundColor, 30));
            $('.k-grid-pager').css('color', bodyForegroundColor);
            $('.k-list').css('background-color', increase_brightness(bodyBackgroundColor, 30));
            $('.k-list').css('color', bodyForegroundColor);
            $('.k-dropdown').css('background-color', increase_brightness(bodyBackgroundColor, 30));
            $('.k-dropdown').css('color', bodyForegroundColor);
            $('.k-grid-content').addClass('dark');
        }

        $('.k-tabstrip-item.k-item .k-link').css('color', bodyForegroundColor);
        $('.k-tabstrip-items-wrapper .k-item').css('text-decoration-color', bodyForegroundColor);
    } catch (e) {
        // Do nothing, this just means the Office JS didn't support this method. 
    }
}

// Handle the item change off a pinned add-in
function itemChanged(eventArgs) {
    location.reload();
    getMessageFiller(tokenOptions, false, true);
}

function setToken(tkn) {
    bootstrapToken = tkn;
}

async function refreshToken() {
    while (_refreshingToken == true) {
        await sleep(100);
    }

    _refreshingToken = true;

    if (tokenTime) {
        var compareTime = new Date(tokenTime + 2 * 60000);
        var nowTime = new Date().getTime();

        if (compareTime < nowTime) {
            options = tokenOptions;
            delete options.callback;
            bootstrapToken = "";
            bootstrapToken = await OfficeRuntime.auth.getAccessToken(options);

            while (bootstrapToken == "") {
                await sleep(500);
            }

            $.ajax({
                url: "/Outlook/UpdateToken",
                headers: { "Authorization": "Bearer " + bootstrapToken },
                type: "POST",
                error: function (xhr, status, error) {
                    console.log(error);
                    _refreshingToken = false;
                }
            })
                .done(function (data) {
                    retryGetAccessToken = 0;
                    tokenTime = new Date().getTime();
                    _refreshingToken = false;
                })
                .fail(function (data) {
                    _refreshingToken = false;
                });
        } else {
            _refreshingToken = false;
        }
    } else {
        _refreshingToken = false;
    }
}

async function getAccessToken(options, resetToken, clearCallback) {
    function MockSSOError(code) {
        this.code = code;
    }

    try {
        if (clearCallback) {
            delete options.callback;
        }

        if (tokenTime) {
            var compareTime = new Date(tokenTime + 2 * 60000);
            var nowTime = new Date().getTime();

            if (compareTime < nowTime) {
                resetToken = true;
            }
        }

        if (!bootstrapToken || resetToken) {
            console.log("Requesting new access token");
            bootstrapToken = await OfficeRuntime.auth.getAccessToken(options);
            retryGetAccessToken = 0;
            tokenTime = new Date().getTime();
            console.log("New access token received: " + bootstrapToken);
        }
    }
    catch (exception) {
        if (exception.code) {
            exceptionString = JSON.stringify(exception);
            console.log("Failure getting access token: " + exceptionString);
            handleClientSideErrors(exception);
        }
        else {
            showResult(["EXCEPTION: " + JSON.stringify(exception)]);
        }
    }
}

function returnAccessToken() {
    getAccessToken(tokenOptions, false, false).then(
        result => { return bootstrapToken; }
    );
}

// Get the message filing component of the add-in
async function getMessageFiller(options, newToken = false, clearCallback = false) {
    // Update UI based on the new current item
    _mailbox = Office.context.mailbox;
    _settings = Office.context.roamingSettings;

    if (_mailbox.item) {
        _mailbox.item.loadCustomPropertiesAsync(customPropsCallback);

        // get the message filer requesting a new token. 
        clearErrorList();
        await getAccessToken(options, newToken, clearCallback);

        if (bootstrapToken) {
            if (!_mailbox.item.getSharedPropertiesAsync) {
                var mailboxName = _mailbox.userProfile.emailAddress;

                if (mailboxName == "" || mailboxName == null) {
                    showResult(['Failed to get mailbox name'])
                } else {
                    buildMessageFiler(mailboxName);
                }

            } else {
                _mailbox.item.getSharedPropertiesAsync(

                    function (result2) {
                        buildMessageFiler(result2.value.owner);
                    }
                );
            }
        }
    } else {
        // There was no mailbox item selected so let the user know we only work with emails. 
        $('#controlContainer').html("<p>Please select an email to use this add-in</p>");
    }
}

// Build the display for the message filer 
function buildMessageFiler(mailbox) {
    clearErrorList();
    _mailboxName = mailbox;
    item = _mailbox.item;
    restItemId = _mailbox.item.itemId

    if (item.itemId) {
        restItemId = Office.context.mailbox.convertToRestId(item.itemId, Office.MailboxEnums.RestVersion.v2_0);
    }

    if (!item.itemId && _mailbox.item.itemId) {
        showResult(["Failed to get Rest Item ID, please close and re-open CymBuild Mailer."]);
    } else {
        $.ajax({
            url: "/Outlook/MessageFiler?messageId=" + restItemId + "&mailbox=" + encodeURIComponent(mailbox) + "&user=" + encodeURIComponent(_mailbox.userProfile.emailAddress),
            headers: { "Authorization": "Bearer " + bootstrapToken },
            type: "GET",
            error: function (xhr, status, error) {
                console.log(error);
                showResult([error]);

                if (retryGetAccessToken <= 0) {
                    retryGetAccessToken++;
                    getMessageFiller(tokenOptions, true, true);
                }
            }
        })
            .done(function (data) {
                $('#controlContainer').html(data);
                $(document).ready(function () {
                    // Ensure messageFilerLoad is defined and call it if necessary
                    if (typeof messageFilerLoad === "function") {
                        messageFilerLoad();
                    } else {
                        console.error("messageFilerLoad is not defined");
                    }
                });
                applyOfficeTheme();
            })
            .fail(function (data) {
                console.log(data);
                handleServerSideErrors(data);
            });
    }
}

async function handleClientSideErrors(error) {
    switch (error.code) {

        case 13001:
            // No one is signed into Office. If the add-in cannot be effectively used when no one 
            // is logged into Office, then the first call of getAccessToken should pass the 
            // `allowSignInPrompt: true` option.
            showResult(["No one is signed into Office. But you can use many of the add-ins functions anyway. If you want to log in, press the Get OneDrive File Names button again."]);
            break;
        case 13002:
            // The user aborted the consent prompt. If the add-in cannot be effectively used when consent
            // has not been granted, then the first call of getAccessToken should pass the `allowConsentPrompt: true` option.
            showResult(["You can use many of the add-ins functions even though you have not granted consent. If you want to grant consent, press the Get OneDrive File Names button again."]);
            break;
        case 13004:
            showResult([error.message]);
            break;
        case 13006:
            // Only seen in Office on the web.
            showResult(["Office on the web is experiencing a problem. Please sign out of Office, close the browser, and then start again."]);
            break;
        case 13008:
            // Only seen in Office on the web.
            showResult(["Office is still working on the last operation. When it completes, try this operation again."]);
            break;
        case 13010:
            // Only seen in Office on the web.
            showResult(["Follow the instructions to change your browser's zone configuration."]);
            break;
        case 13013:
            // API Throttled Exception 
            showResult(["Error 13013, please wait and the page will refresh when ready."])
            await sleep(5000);
            getMessageFiller();
            break;
        default:
            // For all other errors, including 13000, 13003, 13005, 13007, 13012, and 50001, fall back
            // to non-SSO sign-in.
            console.log("Unhandled client side exception");
            console.log(error);

            //dialogFallback();

            break;
    }
}

async function handleServerSideErrors(result) {
    console.log("Handling server side error");
    console.log(result);

    if (result.responseText != "") {
        var responseText = JSON.parse(result.responseText);

        // Our special handling on the server will cause the result that is returned
        // from a AADSTS50076 (a 2FA challenge) to have a Message property but no ExceptionMessage.
        var message = responseText.Message;

        // Results from other errors (other than AADSTS50076) will have an ExceptionMessage property.
        var exceptionMessage = responseText.ExceptionMessage;

        // Microsoft Graph requires an additional form of authentication. Have the Office host 
        // get a new token using the Claims string, which tells AAD to prompt the user for all 
        // required forms of authentication.
        if (message) {
            if (message.indexOf("AADSTS50076") !== -1) {
                if (retryGetAccessToken <= 0) {
                    retryGetAccessToken++;
                    var claims = JSON.parse(message).Claims;
                    var claimsAsString = JSON.stringify(claims);
                    getMessageFiller({ authChallenge: claimsAsString }, true);
                }
                return;
            }
        }
        if (exceptionMessage) {
            // On rare occasions the bootstrap token is unexpired when Office validates it,
            // but expires by the time it is sent to AAD for exchange. AAD will respond
            // with "The provided value for the 'assertion' is not valid. The assertion has expired."
            // Retry the call of getAccessToken (no more than once). This time Office will return a 
            // new unexpired bootstrap token.
            if (
                (
                    (exceptionMessage.indexOf("AADSTS500133") !== -1)
                    || (exceptionMessage.indexOf("AADSTS50027") !== -1)
                )
                && (retryGetAccessToken <= 0)
            ) {
                retryGetAccessToken++;
                await sleep(500);
                getMessageFiller(tokenOptions, true, true);
            }
            else {
                // For debugging: 
                showResult(["ERROR: " + JSON.stringify(exceptionMessage)]);

                // For all other AAD errors, fallback to non-SSO sign-in.                            
                //dialogFallback();
            }
        } else if (result.status == 500) {
            if (retryGetAccessToken <= 0) {
                retryGetAccessToken++;
                await sleep(500);
                getMessageFiller(tokenOptions, true, true);
            }
        }

        if (!message && !exceptionMessage) {
            showResult([result]);
        }
    } else if (result.status == 500) {
        if (retryGetAccessToken <= 0) {
            retryGetAccessToken++;
            await sleep(500);
            getMessageFiller(tokenOptions, true, true);
        }
    }
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Get the item's custom properties from the server and save for later use.
function customPropsCallback(asyncResult) {
    _customProps = asyncResult.value;

    if (!_customProps.get(filingHistoryPropertyName)) {
        updateProperty(filingHistoryPropertyName, "[]");
    }
}

// Sets or updates the specified property, and then saves the change
// to the server.
function updateProperty(name, value) {
    _customProps.set(name, value);
    _customProps.saveAsync(saveCallback);
}

// Removes the specified property, and then persists the removal
// to the server.
function removeProperty(name) {
    _customProps.remove(name);
    _customProps.saveAsync(saveCallback);
}

// Callback for calls to saveAsync method.
function saveCallback(asyncResult) {
    if (asyncResult.status == Office.AsyncResultStatus.Failed) {
        // Handle the failure.
        console.log(asyncResult);
    }
}

function setFilingProperties(entityType, rowId, filingStructureId, wasDraft) {
    var duplicate = false;

    // build the new filing destination object. 
    var customPropsObj = {
        entityType: entityType,
        rowId: rowId,
        filingStructureId: filingStructureId,
        submitted: false,
        wasDraft: wasDraft
    };

    // get the current list of destinations. 
    var customPropsString = _customProps.get(filingDestinationPropertyName);
    var customPropsList = [];

    if (customPropsString) {
        customPropsList = JSON.parse(customPropsString);
    }

    // check for a duplicate entry 
    for (let i = 0; i < customPropsList.length; i++) {

        if (customPropsList[i].entityType == customPropsObj.entityType
            && customPropsList[i].rowId == customPropsObj.rowId
            && customPropsList[i].filingStructureId == customPropsObj.filingStructureId) {
            duplicate = true;
        }
    }

    // add to the collection if it's not a duplicate.
    if (duplicate == false) {
        customPropsList.push(customPropsObj);
    }

    // save the list.
    var customPropsString = JSON.stringify(customPropsList);
    updateProperty(filingDestinationPropertyName, customPropsString);

    // make sure do not file is not set. 
    updateProperty(doNotFilePropertyName, "false");
}

function removeFilingProperties(entityType, rowId, filingStructureId) {
    // get the current list of destinations. 
    var customPropsString = _customProps.get(filingDestinationPropertyName);
    var customPropsList = [];

    if (customPropsString) {
        customPropsList = JSON.parse(customPropsString);

        for (let i = 0; i < customPropsList.length; i++) {

            if (customPropsList[i].entityType == entityType
                && customPropsList[i].rowId == rowId
                && customPropsList[i].filingStructureId == filingStructureId) {
                customPropsList.splice(i, 1);
            }
        }

        // save the list.
        var customPropsString = JSON.stringify(customPropsList);
        updateProperty(filingDestinationPropertyName, customPropsString);
    }
}



function submitFiling() {
    $('#error-list').empty();
    var destinationList = _customProps.get(filingDestinationPropertyName);

    if (destinationList) {
        var desitinationArray = JSON.parse(destinationList);

        for (let i = 0; i < desitinationArray.length; i++) {
            desitinationArray[i].submitted = true;
        }

        destinationList = JSON.stringify(desitinationArray);
        currentItem = Office.context.mailbox.item;

        var _subject = fetchedSubject;
        if (!_subject) {
            _subject = "(no subject)";
        }

        var fileMessageRequest = {
            messageId: messageId,
            mailbox: filingMailbox,
            destinations: destinationList,
            subject: encodeURIComponent(_subject),
            recipients: encodeURIComponent(fetchedRecipients),
            from: encodeURIComponent(fetchedFrom)
        }

        $.ajax({
            url: "/Outlook/FileEmail",
            headers: { "Authorization": "Bearer " + bootstrapToken },
            data: fileMessageRequest,
            type: "POST",
            error: function (xhr, status, error) {
                console.log(error);
            }
        })
            .done(function (data) {
                addCategoryToMessage(filingPendingCategoryName, currentItem);

                setLastFiledLocation();

                customPropsList = JSON.parse(destinationList);

                for (let i = 0; i < customPropsList.length; i++) {
                    removeFilingProperties(customPropsList[i].entityType, customPropsList[i].rowId, customPropsList[i].filingStructureId);
                }

                displayFilingHistory();
            })
            .fail(function (data) {
                handleServerSideErrors(data);
            });
    } else {
        showResult(["Please select some filing destinations first."]);
    }
}

function clearErrorList() {
    $('#error-list').empty();
}

// Displays the data, assumed to be an array.
function showResult(data) {
    data.push("If errors persist please log a help desk ticket.");

    // Use jQuery text() method which automatically encodes values that are passed to it,
    // in order to protect against injection attacks.
    $.each(data, function (i) {
        var text;
        if (
            typeof data[i] === 'object') {
            text = JSON.stringify(data[i]);
        } else {
            text = data[i];
        }

        var li = $('<li/>').addClass('ms-ListItem').appendTo($('#error-list'));
        var outerSpan = $('<span/>').addClass('ms-ListItem-secondaryText').appendTo(li);
        $('<span/>').addClass('ms-fontColor-themePrimary').appendTo(outerSpan).text(text);
    });

    resizeGrid();
}

function logError(result) {
    console.log("Status: " + result.status);
    console.log("Code: " + result.error.code);
    console.log("Name: " + result.error.name);
    console.log("Message: " + result.error.message);
}

// This handler responds to the success or failure message that the pop-up dialog receives from the identity provider
// and access token provider.
function processMessage(arg) {

    console.log("Message received in processMessage: " + JSON.stringify(arg));
    let message = JSON.parse(arg.message);

    if (message.status === "success") {
        // We now have a valid access token.
        loginDialog.close();
    } else {
        // Something went wrong with authentication or the authorization of the web application.
        loginDialog.close();
        showResult(["Unable to successfully authenticate user or authorize application. Error is: " + message.error]);
    }
}

function addCategoryToMessage(categoryName, currentItem) {
    var categoriesToAdd = [categoryName];

    currentItem.categories.addAsync(categoriesToAdd, function (asyncResult) {
        if (asyncResult.status === Office.AsyncResultStatus.Succeeded) {

        } else {
            console.log("categories.addAsync call failed with error: " + asyncResult.error.message);
        }
    });
}

function setLastFiledLocation() {
    var filingPropsObjectString = _customProps.get(filingDestinationPropertyName);
    console.log(filingPropsObjectString);
    _settings.set(lastFiledLocationSettingName, filingPropsObjectString);
    _settings.saveAsync(saveMyAppSettingsCallback);
}

// Saves all roaming settings.
function saveMyAppSettingsCallback(asyncResult) {
    if (asyncResult.status == Office.AsyncResultStatus.Failed) {
        // Handle the failure.
        console.log(asyncResult);
    }
}

function reset() {
    _settings.set(lastFiledLocationSettingName, null);
    _settings.saveAsync(saveMyAppSettingsCallback);

    buildMessageFiler();
}

function expandButtons() {
    $(".buttonContainer").removeClass("collapse");
    $(".buttonContainer").addClass("expand");

    _settings.set(buttonExpansionSettingName, true);
    _settings.saveAsync(saveMyAppSettingsCallback);

    try {
        resizeGrid();
    } catch (err) {

    }
}
// Function to send mailbox and settings to Blazor
function sendMailboxDataToBlazor() {
    _mailbox = Office.context.mailbox;
    _settings = Office.context.roamingSettings;

    const mailbox = {
        userProfile: {
            displayName: _mailbox.userProfile.displayName,
            emailAddress: _mailbox.userProfile.emailAddress,
            id: _mailbox.userProfile.id
        },
        item: _mailbox.item ? {
            itemId: _mailbox.item.itemId,
            subject: _mailbox.item.subject,
            body: _mailbox.item.body,
            sender: _mailbox.item.sender,
            toRecipients: _mailbox.item.toRecipients,
            ccRecipients: _mailbox.item.ccRecipients,
            bccRecipients: _mailbox.item.bccRecipients,
            attachments: _mailbox.item.attachments,
            conversationId: _mailbox.item.conversationId,
            meeting: _mailbox.item.meeting
        } : null
    };

    const settings = {};
    for (const key in _settings) {
        if (_settings.hasOwnProperty(key)) {
            settings[key] = _settings.get(key);
        }
    }

    DotNet.invokeMethodAsync('CymBuild_Outlook_Addin', 'ReceiveMailboxData', JSON.stringify(mailbox), JSON.stringify(settings))
        .then(data => {
            console.log("Data sent to Blazor successfully.");
        })
        .catch(error => {
            console.error("Error sending data to Blazor:", error);
        });
}

function collapseButtons() {
    $(".buttonContainer").removeClass("expand");
    $(".buttonContainer").addClass("collapse");

    _settings.set(buttonExpansionSettingName, false);
    _settings.saveAsync(saveMyAppSettingsCallback);

    try {
        resizeGrid();
    } catch (err) {

    }
}
