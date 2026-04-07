/* CymBuildOffice.js
 * SSO-based token handling using OfficeRuntime.auth.getAccessToken
 * No MSAL, no sessionStorage usage
 */

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

// Base SSO token options – merged with any overrides (e.g. authChallenge)
var tokenOptions = {
    allowSignInPrompt: true,
    allowConsentPrompt: true,
    forMSGraphAccess: false
};

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
    });
});

window.addEventListener("error", function (event) {
    console.error("JavaScript Error: ", event.message, event.error);
});

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
}

function setToken(tkn) {
    bootstrapToken = tkn;
}

async function refreshToken() {
    while (_refreshingToken === true) {
        await sleep(100);
    }

    _refreshingToken = true;

    if (tokenTime) {
        var compareTime = new Date(tokenTime + 2 * 60000);
        var nowTime = new Date().getTime();

        if (compareTime < nowTime) {
            // Token is older than 2 minutes – refresh using SSO
            bootstrapToken = "";
            try {
                bootstrapToken = await OfficeRuntime.auth.getAccessToken(tokenOptions);
            } catch (err) {
                console.log("Error refreshing token via SSO:", err);
                _refreshingToken = false;
                return;
            }

            while (bootstrapToken === "") {
                await sleep(500);
            }

            $.ajax({
                url: "/Outlook/UpdateToken",
                headers: {
                    "Authorization": "Bearer " + bootstrapToken,
                    "Prefer": 'IdType="ImmutableId"'
                },
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

/**
 * Core SSO token helper.
 * - Merges base tokenOptions with any overrides (e.g. authChallenge).
 * - Uses OfficeRuntime.auth.getAccessToken (no MSAL).
 */
async function getAccessToken(options, resetToken, clearCallback) {
    function MockSSOError(code) {
        this.code = code;
    }

    try {
        // Merge base options with any call-specific overrides
        var ssoOptions = Object.assign({}, tokenOptions, options || {});

        if (clearCallback) {
            // Legacy protection – ensure we don't pass a callback property through
            delete ssoOptions.callback;
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
            bootstrapToken = await OfficeRuntime.auth.getAccessToken(ssoOptions);
            retryGetAccessToken = 0;
            tokenTime = new Date().getTime();
            console.log("New access token received (SSO).");
        }
    }
    catch (exception) {
        if (exception.code) {
            var exceptionString = JSON.stringify(exception);
            console.log("Failure getting access token: " + exceptionString);
            handleClientSideErrors(exception);
        }
        else {
            showResult(["EXCEPTION: " + JSON.stringify(exception)]);
        }
    }
}

function returnAccessToken() {
    // Kept for backward compatibility; if you need the token synchronously,
    // refactor callers to `await getAccessToken(...)` and then read `bootstrapToken`.
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
    restItemId = _mailbox.item.itemId;

    if (item.itemId) {
        restItemId = Office.context.mailbox.convertToRestId(item.itemId, Office.MailboxEnums.RestVersion.v2_0);
    }

    if (!item.itemId && _mailbox.item.itemId) {
        showResult(["Failed to get Rest Item ID, please close and re-open CymBuild Mailer."]);
    } else {
        const url = "/Outlook/MessageFiler?messageId=" + restItemId + "&mailbox=" + encodeURIComponent(mailbox) + "&user=" + encodeURIComponent(_mailbox.userProfile.emailAddress);
        console.log("Request URL: " + url);

        $.ajax({
            url: url,
            headers: {
                "Authorization": "Bearer " + bootstrapToken,
                "Prefer": 'IdType="ImmutableId"'
            },
            type: "GET",
            error: function (xhr, status, error) {
                console.error("AJAX Error: ", error);
                console.error("Status: ", status);
                console.error("Response: ", xhr.responseText);
                showResult([error]);

                if (retryGetAccessToken <= 0) {
                    retryGetAccessToken++;
                    getMessageFiller(tokenOptions, true, true);
                }
            }
        })
            .done(function (data) {
                console.log("AJAX Success: Data received");
                $('#controlContainer').html(data);
                $(document).ready(function () {
                    // Initialization logic unrelated to messageFilerLoad
                    console.log("Document ready and initialization complete.");
                });
                applyOfficeTheme();
            })
            .fail(function (xhr, status, error) {
                console.error("AJAX Fail: ", error);
                console.error("Status: ", status);
                console.error("Response: ", xhr.responseText);
                handleServerSideErrors(xhr);
            });
    }
}

async function handleClientSideErrors(error) {
    switch (error.code) {
        case 13001:
            showResult(["No one is signed into Office. But you can use many of the add-ins functions anyway. If you want to log in, press the Get OneDrive File Names button again."]);
            break;
        case 13002:
            showResult(["You can use many of the add-ins functions even though you have not granted consent. If you want to grant consent, press the Get OneDrive File Names button again."]);
            break;
        case 13004:
            showResult([error.message]);
            break;
        case 13006:
            showResult(["Office on the web is experiencing a problem. Please sign out of Office, close the browser, and then start again."]);
            break;
        case 13008:
            showResult(["Office is still working on the last operation. When it completes, try this operation again."]);
            break;
        case 13010:
            showResult(["Follow the instructions to change your browser's zone configuration."]);
            break;
        case 13013:
            showResult(["Error 13013, please wait and the page will refresh when ready."])
            await sleep(5000);
            getMessageFiller();
            break;
        default:
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

        var message = responseText.Message;
        var exceptionMessage = responseText.ExceptionMessage;

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
                showResult(["ERROR: " + JSON.stringify(exceptionMessage)]);
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
        console.log(asyncResult);
    }
}

function setFilingProperties(entityType, rowId, filingStructureId, wasDraft) {
    var duplicate = false;

    var customPropsObj = {
        entityType: entityType,
        rowId: rowId,
        filingStructureId: filingStructureId,
        submitted: false,
        wasDraft: wasDraft
    };

    var customPropsString = _customProps.get(filingDestinationPropertyName);
    var customPropsList = [];

    if (customPropsString) {
        customPropsList = JSON.parse(customPropsString);
    }

    for (let i = 0; i < customPropsList.length; i++) {
        if (customPropsList[i].entityType == customPropsObj.entityType
            && customPropsList[i].rowId == customPropsObj.rowId
            && customPropsList[i].filingStructureId == customPropsObj.filingStructureId) {
            duplicate = true;
        }
    }

    if (duplicate == false) {
        customPropsList.push(customPropsObj);
    }

    customPropsString = JSON.stringify(customPropsList);
    updateProperty(filingDestinationPropertyName, customPropsString);

    updateProperty(doNotFilePropertyName, "false");
}

function removeFilingProperties(entityType, rowId, filingStructureId) {
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

        customPropsString = JSON.stringify(customPropsList);
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

        setTimeout(function () {
            $.ajax({
                url: "/Outlook/FileEmail",
                headers: {
                    "Authorization": "Bearer " + bootstrapToken,
                    "Prefer": 'IdType="ImmutableId"'
                },
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
        }, 100); // 100 milliseconds delay
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

    $.each(data, function (i) {
        var text;
        if (typeof data[i] === 'object') {
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

function processMessage(arg) {
    console.log("Message received in processMessage: " + JSON.stringify(arg));
    let message = JSON.parse(arg.message);

    if (message.status === "success") {
        loginDialog.close();
    } else {
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