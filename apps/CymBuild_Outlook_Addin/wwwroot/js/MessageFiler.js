var filingDestinationsGridSelectedRowId;
var filingDestinationsGridSelectedEntityType;
var fetchingSubject = false;
var fetchedSubject;
var fetchingRecipients = false;
var fetchedRecipients;
var fetchingFrom = false;
var fetchedFrom;

var gridElement = $("#filingDestinationsGrid");

function resizeGrid() {
    var gridElement = $("#filingDestinationsGridContainer").find(".k-grid");
    var grid = gridElement.data("kendoGrid");
    if (!grid) {
        return;
    }
    var kContentHeight = $(window).height() - gridElement.position().top;
    var gridHeight = kContentHeight - 70;

    gridElement.height("100%");

    $("#filingDestinationsGridContainer").height(gridHeight);

    grid.resize();
}

$(window).resize(function () {
    resizeGrid();
});

function fetchSubjectCallBack(result) {
    fetchedSubject = result.value;
    fetchingSubject = false;
}

function fetchRecepientsCallBack(result) {
    fetchedRecipients = "";
    msgTo = result.value;

    for (var i = 0; i < msgTo.length; i++) {
        if (fetchedRecipients != "") {
            fetchedRecipients += ",";
        }

        fetchedRecipients += msgTo[i].emailAddress;
    }

    fetchingRecipients = false;
}

function fetchFromCallBack(result) {
    fetchedFrom = result.value.emailAddress;
    fetchingFrom = false;
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

var searchChangeTimestamp;

function searchChange() {
    var timeSet = Date.now();
    searchChangeTimestamp = timeSet;
    searchChangeWaiter(searchChangeTimestamp);
}

async function searchChangeWaiter(timeSet) {
    await sleep(300);
    if (searchChangeTimestamp == timeSet) {
        refreshSearchAI();
    }
}

async function refreshSearchAI() {
    var grid = $("#filingDestinationsGrid").data("kendoGrid");
    if (!grid) {
        return;
    }
    var dataSource = grid.dataSource;
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
    };

    toAddressFilter = {
        field: "ToAddresses",
        operator: "eq",
        value: fetchedRecipients,
        FilterName: "ToAddresses"
    };

    fromAddressFilter = {
        field: "FromAddress",
        operator: "eq",
        value: fetchedFrom,
        FilterName: "FromAddress"
    };

    recordFilter = {
        field: "Record",
        operator: "contains",
        value: recordSearch,
        FilterName: "Record"
    };

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

function filingDestinationsGrid_onChange(e) {
    var rows = e.sender.select();
    rows.each(function (e) {
        var grid = $("#filingDestinationsGrid").data("kendoGrid");
        filingDestinationsGridSelectedRowId = grid.dataItem(this).RowId;
        filingDestinationsGridSelectedEntityType = grid.dataItem(this).EntityType;
    });
}

function disableAutoComplete(element) {
    element.addClass("k-input");
}

function getFilingStructureName(id) {
    var returnString = "";

    for (let i = 0; i < filingStructureArray.length; i++) {
        if (filingStructureArray[i].Id == id) {
            returnString = filingStructureArray[i].Name;
            return returnString;
        }
    }

    return returnString;
}

function displayFilingHistory(isFiling = false) {
    var filingHistory = _customProps.get(filingHistoryPropertyName);
    var doNotFile = _customProps.get(doNotFilePropertyName);
    var filingDesinations = _customProps.get(filingDestinationPropertyName);
    var displayHtml = "";
    var pendingHtml = "";

    if (bootstrapToken) {
        $.ajax({
            url: "/Outlook/GetMailerQueueForMessage?messageId=" + messageId + "&mailbox=" + filingMailbox,
            headers: {
                "Authorization": "Bearer " + bootstrapToken,
                "Prefer": 'IdType="ImmutableId"'
            },
            type: "GET",
            error: function (xhr, status, error) {
                console.log(error);
            }
        })
            .done(function (data) {
                for (i = 0; i < data.length; i++) {
                    if (data[i].IsFiled == false && doNotFile != "true") {
                        if (data[i].ErrorMessage != '') {
                            displayHtml += "<div class=\"alert alert-danger\" role=\"alert\"><ul><li>" + data[i].ErrorMessage + "</li></ul></div>";
                        }

                        pendingHtml += "<li>Pending filing to " + data[i].EntityType + " : " + data[i].RowId + " [" + getFilingStructureName(data[i].FilingStructureID) + "]" + "</li>";
                    }
                }

                if (pendingHtml != '') {
                    displayHtml += "<div class=\"alert alert-info\" role=\"alert\"><ul>" + pendingHtml + "<li>Click off, then back on this email to refresh.</li></ul></div>";
                }

                if (isFiling) {
                    displayHtml += "<div class=\"alert alert-info\" role=\"alert\"><ul><li>Processing filing request . . .</li></ul></div>";
                }

                if (doNotFile == "true") {
                    displayHtml += "<div class=\"alert alert-danger\" role=\"alert\"><ul><li>You have opted not to file this email.</li></ul></div>";
                }

                if (filingHistory) {
                    if (filingHistory != "[]") {
                        filingHistory = JSON.parse(filingHistory);
                        var filingHistoryUl = "<div class=\"alert alert-success\" role=\"alert\"><ul>";

                        for (i = 0; i < filingHistory.length; i++) {
                            f = filingHistory[i];
                            if (f) {
                                filingHistoryUl += "<li><a href=\"#\" onclick=\"filingHistoryClick('" + f.entityType + "','" + f.rowId + "')\"><i class=\"fa fa-folder\" /></a> Filed to " + f.entityType + " " + f.rowId + " [" + getFilingStructureName(f.filingStructureId) + "]" + "</li>";
                            }
                        }

                        filingHistoryUl += "</ul></div>";
                        displayHtml += filingHistoryUl;
                    }
                }

                if (filingDesinations) {
                    filingDesinations = JSON.parse(filingDesinations);

                    if (filingDesinations.length > 0) {
                        var filingDesinationsUl = "<div class=\"alert alert-info\" role=\"alert\"><ul>";

                        for (i = 0; i < filingDesinations.length; i++) {
                            f = filingDesinations[i];

                            var afterText = "sending";

                            if (_mailbox.item.itemId != undefined && f.wasDraft == false) {
                                afterText = "submit";
                            }

                            if (f) {
                                if (_mailbox.item.itemId != undefined && f.wasDraft == true) {
                                    filingDesinationsUl += "<li>Pending filing to " + f.entityType + " " + f.rowId + " [" + getFilingStructureName(f.filingStructureId) + "].</li>";
                                } else {
                                    filingDesinationsUl += "<li><a href=\"#\" onclick=\"filingDestinationRemove('" + f.entityType + "','" + f.rowId + "','" + f.filingStructureId + "')\"><i class=\"fa fa-trash-alt\" /></a> Filing to " + f.entityType + " " + f.rowId + " [" + getFilingStructureName(f.filingStructureId) + "]" + " after " + afterText + ".</li>";
                                }
                            }
                        }

                        filingDesinationsUl += "</ul></div>";
                        displayHtml += filingDesinationsUl;
                    }
                }

                $("#filingHistory").html(displayHtml);

                resizeGrid();
            })
            .fail(function (data) {
                console.log(data);
                handleServerSideErrors(data);
            });
    }
}

function filingHistoryClick(et, r) {
    let url = "https://" + window.location.host + "/Outlook/FilingHistoryRedirect?et=" + et + "&r=" + r;
    Office.context.ui.openBrowserWindow(url);
}

function filingDestinationRemove(entityType, rowId, filingStructureId) {
    removeFilingProperties(entityType, rowId, filingStructureId);
    displayFilingHistory();
}

function setFileWithPreviousButton() {
    var fileWithPreviousSetting = _settings.get(lastFiledLocationSettingName);
    var showButton = false;

    if (fileWithPreviousSetting != "undefined" && fileWithPreviousSetting != null) {
        showButton = true;
    }

    if (showButton) {
        $("#fileWithPreviousButton").show();
    } else {
        $("#fileWithPreviousButton").hide();
    }
}

function fileEmail(entityType, rowId, filingStructureId) {
    var wasDraft = true;

    if (_mailbox.item.itemId != undefined) {
        wasDraft = false;
    }

    setFilingProperties(entityType, rowId, filingStructureId, wasDraft);
    displayFilingHistory();
}