// CymBuildFunctions.js
var _mailbox;
var _customProps;

var filingDestinationPropertyName = "CymBuildOutlookFilingDestination";
var lastFiledLocationSettingName = "LastFiledLocation";
var doNotFilePropertyName = "DoNotFile";

Office.initialize = function (reason) {
    _mailbox = Office.context.mailbox;
    _settings = Office.context.roamingSettings;
}

function performOperation() {
    return new Promise((resolve, reject) => {
        Office.context.mailbox.getCallbackTokenAsync({
            isRest: true
        }, function (asyncResult) {
            if (asyncResult.status === Office.AsyncResultStatus.Succeeded && asyncResult.value !== "") {
                Office.context.mailbox.item.getSharedPropertiesAsync({
                    asyncContext: asyncResult.value
                }, function (asyncResult1) {
                    if (asyncResult1.status === Office.AsyncResultStatus.Succeeded) {
                        let sharedProperties = asyncResult1.value;
                        let delegatePermissions = sharedProperties.delegatePermissions;

                        if ((delegatePermissions & Office.MailboxEnums.DelegatePermissions.Write) != 0) {
                            let rest_url = sharedProperties.targetRestUrl + "/v2.0/users/" + sharedProperties.targetMailbox + "/messages";

                            $.ajax({
                                url: rest_url,
                                dataType: 'json',
                                headers: {
                                    "Authorization": "Bearer " + asyncResult1.asyncContext
                                }
                            }).done(function (response) {
                                resolve(response);
                            }).fail(function (error) {
                                reject("Error occurred: " + error);
                            });
                        } else {
                            reject("Insufficient permissions");
                        }
                    } else {
                        reject("Failed to get shared properties: " + asyncResult1.error.message);
                    }
                });
            } else {
                reject("Failed to get callback token: " + asyncResult.error.message);
            }
        });
    });
}

async function getEmailDetails() {
    return new Promise((resolve, reject) => {
        let emailDetails = {
            userEmail: Office.context.mailbox.userProfile.emailAddress,
            senderEmail: Office.context.mailbox.item.sender.emailAddress,
            mailboxOwnerEmail: null // Initialize to null
        };

        try {
            // Get the callback token for REST API requests
            Office.context.mailbox.getCallbackTokenAsync({ isRest: true }, function (asyncResult) {
                if (asyncResult.status === Office.AsyncResultStatus.Succeeded && asyncResult.value !== "") {
                    let authToken = asyncResult.value;

                    try {
                        // Attempt to get shared properties using the obtained token
                        Office.context.mailbox.item.getSharedPropertiesAsync({ asyncContext: authToken }, function (asyncResult1) {
                            if (asyncResult1.status === Office.AsyncResultStatus.Succeeded) {
                                let sharedProperties = asyncResult1.value;
                                if (sharedProperties && sharedProperties.owner) {
                                    // Successfully retrieved owner email
                                    emailDetails.mailboxOwnerEmail = sharedProperties.owner;
                                } else {
                                    // Fallback to user email if no owner found
                                    emailDetails.mailboxOwnerEmail = emailDetails.userEmail;
                                }
                            } else {
                                // In case of any error, extract the owner email from the error message
                                emailDetails.mailboxOwnerEmail = extractEmailFromError(asyncResult1.error.message) || emailDetails.userEmail;
                            }
                            resolve(emailDetails);
                        });
                    } catch (error) {
                        // Handle cases where getSharedPropertiesAsync is not available
                        console.log("Error: getSharedPropertiesAsync ", error);
                        emailDetails.mailboxOwnerEmail = extractEmailFromError(error.message) || emailDetails.userEmail;
                        resolve(emailDetails);
                    }
                } else {
                    // Fallback to user email if the token retrieval fails
                    emailDetails.mailboxOwnerEmail = emailDetails.userEmail;
                    resolve(emailDetails);
                }
            });
        } catch (error) {
            // Handle cases where getSharedPropertiesAsync is not available
            console.log("Error: getCallbackTokenAsync ", error);
            emailDetails.mailboxOwnerEmail = extractEmailFromError(error.message) || emailDetails.userEmail;
            resolve(emailDetails);
        }
    });
}

// Helper function to extract the email address from an error message
function extractEmailFromError(errorMessage) {
    console.log("Extract Email From Error: ", errorMessage);
    const emailRegex = /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/;
    const match = errorMessage.match(emailRegex);
    console.log(match);
    return match ? match[0] : null;
}
function validateFiling(event) {
    _mailbox.item.loadCustomPropertiesAsync({ asyncContext: event }, checkFilingOnSendCallBack);
}

function checkFilingOnSendCallBack(asyncResult) {
    _customProps = asyncResult.value;
    var filingProperty = _customProps.get(filingDestinationPropertyName);
    var doNotFileProperty = _customProps.get(doNotFilePropertyName);

    if (!filingProperty) {
        filingProperty = "[]";
    }

    if ((filingProperty == "" || filingProperty == "[]") && !doNotFileProperty && _mailbox.item.itemType == 'message') {
        _mailbox.item.notificationMessages.addAsync('NoSend', { type: 'errorMessage', message: 'You have not filed this item!' });
        // Block send.
        asyncResult.asyncContext.completed({ allowEvent: false });
    } else {
        // Update the last filed location
        _settings.set(lastFiledLocationSettingName, filingProperty);
        _settings.saveAsync(function (ar) {
            if (ar.status == Office.AsyncResultStatus.Failed) {
                _mailbox.item.notificationMessages.addAsync('NoSend', { type: 'errorMessage', message: 'Failed to update last sent location' });
                // Block send.
                asyncResult.asyncContext.completed({ allowEvent: false });
            } else {
                // Allow send.
                asyncResult.asyncContext.completed({ allowEvent: true });
            }
        });
    }
}

var CymBuildFunctions = (function () {
    function fileWithPrevious() {
        var fileWithPreviousSetting = _settings.get(lastFiledLocationSettingName);

        if (fileWithPreviousSetting) {
            console.log(fileWithPreviousSetting);
            updateProperty(filingDestinationPropertyName, fileWithPreviousSetting);

            displayFilingHistory();
        }
    }

    async function refreshSearchAI() {
        var grid = $("#filingDestinationsGrid").data("kendoGrid");
        if (!grid) {
            console.error("Grid not found");
            return;
        }
        var dataSource = grid.dataSource;
        if (!dataSource) {
            console.error("DataSource not found");
            return;
        }
        var filters = null;
        var filterIndex;
        var item = Office.context.mailbox.item;
        let fromAddressFilter;
        let subjectFilter;
        var recordSearch;

        await refreshToken();

        // add an extra while here to make sure we don't end up at the server while the token is being refreshed.
        while (_refreshingToken == true) {
            await sleep(100);
        }

        recordSearch = $('#searchBox').val();

        if (item.itemId) {
            var msgTo = item.to;
            fetchedRecipients = "";

            for (var i = 0; i < msgTo.length; i++) {
                if (fetchedRecipients != "") {
                    fetchedRecipients += ",";
                }

                fetchedRecipients += msgTo[i].emailAddress;
            }

            fetchedSubject = item.subject;

            fetchedFrom = item.sender.emailAddress;
        } else {
            fetchingSubject = true;
            item.subject.getAsync(fetchSubjectCallBack);

            while (fetchingSubject) {
                await sleep(200);
            }

            fetchingRecipients = true;
            item.to.getAsync(fetchRecepientsCallBack);

            while (fetchingRecipients) {
                await sleep(200);
            }

            fetchingFrom = true;
            item.from.getAsync(fetchFromCallBack);

            while (fetchingFrom) {
                await sleep(200);
            }
        }

        subjectFilter = {
            field: "Subject",
            operator: "eq",
            value: fetchedSubject,
            FilterName: "Subject"
        }

        toAddressFilter = {
            field: "ToAddresses",
            operator: "eq",
            value: fetchedRecipients,
            FilterName: "ToAddresses"
        }

        fromAddressFilter = {
            field: "FromAddress",
            operator: "eq",
            value: fetchedFrom,
            FilterName: "FromAddress"
        }

        recordFilter = {
            field: "Record",
            operator: "contains",
            value: recordSearch,
            FilterName: "Record"
        }

        if (dataSource.filter() != null) {
            filters = dataSource.filter().filters;
        }

        if (filters == null) {
            filters = [subjectFilter, toAddressFilter, fromAddressFilter, recordFilter];
        } else {
            // Replace our filters, leaving the user's filter in place.
            filterIndex = filters.map((e) => { return e.FilterName }).indexOf("Subject");
            if (filterIndex > -1) {
                filters.splice(filterIndex, 1);
            }

            if (subjectFilter) {
                filters.push(subjectFilter);
            }

            filterIndex = filters.map((e) => { return e.FilterName }).indexOf("FromAddress");
            if (filterIndex > -1) {
                filters.splice(filterIndex, 1);
            }

            if (fromAddressFilter != null) {
                filters.push(fromAddressFilter);
            }

            filterIndex = filters.map((e) => { return e.FilterName }).indexOf("ToAddresses");
            if (filterIndex > -1) {
                filters.splice(filterIndex, 1);
            }

            if (toAddressFilter != null) {
                filters.push(toAddressFilter);
            }

            filterIndex = filters.map((e) => { return e.FilterName }).indexOf("Record");
            if (filterIndex > -1) {
                filters.splice(filterIndex, 1);
            }

            if (recordFilter != null) {
                filters.push(recordFilter);
            }
        }

        if (filters != null) {
            grid.dataSource.filter(filters);
        }
    }

    function setDoNotFile() {
        updateProperty(doNotFilePropertyName, "true");
        updateProperty(filingDestinationPropertyName, null);
        displayFilingHistory();
    }

    function CollapseButtons() {
        const buttonContainer = document.querySelector('.buttonContainer');
        if (buttonContainer) {
            buttonContainer.classList.add('collapsed');
            buttonContainer.classList.remove('expanded');
        }
    }
    function handleNewMessageCompose(event) {
        try {
            console.log("New message compose handler triggered.");
            event.completed({ allowEvent: true });
        } catch (error) {
            console.error("Error in handleNewMessageCompose:", error);
            event.completed({ allowEvent: false, error: error.message });
        }
    }

    function handleQuickAction(event) {
        console.log("Quick action handler");
        // TESTING
        Office.context.mailbox.item.notificationMessages.addAsync(
            "quickAction",
            { type: "informationalMessage", message: "Quick action executed!" }
        );
        event.completed();
    }

    function ExpandButtons() {
        const buttonContainer = document.querySelector('.buttonContainer');
        if (buttonContainer) {
            buttonContainer.classList.add('expanded');
            buttonContainer.classList.remove('collapsed');
        }
    }

    document.addEventListener('DOMContentLoaded', function () {
        // Initialize buttons to collapsed state
        CollapseButtons();
    });

    function collapseButtons() {
        const buttonContainer = document.querySelector('.buttonContainer');
        if (buttonContainer) {
            buttonContainer.classList.add('collapsed');
            buttonContainer.classList.remove('expanded');
            document.querySelector('.collapse-buttons').style.display = 'none';
            document.querySelector('.expand-buttons').style.display = 'block';
        }
    }

    function expandButtons() {
        const buttonContainer = document.querySelector('.buttonContainer');
        if (buttonContainer) {
            buttonContainer.classList.add('expanded');
            buttonContainer.classList.remove('collapsed');
            document.querySelector('.collapse-buttons').style.display = 'block';
            document.querySelector('.expand-buttons').style.display = 'none';
        }
    }

    return {
        fileWithPrevious: fileWithPrevious,
        refreshSearchAI: refreshSearchAI,
        setDoNotFile: setDoNotFile,
        collapseButtons: collapseButtons,
        expandButtons: expandButtons
    };
})();

window.CymBuildFunctions = CymBuildFunctions;