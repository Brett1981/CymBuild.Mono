using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;

using Telerik.Blazor.Components;
using static Concursus.PWA.Shared.MessageDisplay;
using EntityProperty = Concursus.API.Core.EntityProperty;

namespace Concursus.PWA.Shared;

public partial class ButtonMenu
{
    protected FormHelper? formHelper;

    private IDictionary<string, object> DetailPageParameters = new Dictionary<string, object>();

    public API.Client.MenuItem? ClickedItem { get; set; }

    [Parameter] public EventCallback CloseWindow { get; set; }

    [Parameter] public DataObject? dataObject { get; set; }
    [Parameter] public List<EntityProperty> EntityProperties { get; set; } = new();
    [Parameter] public string EntityTypeGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public EventCallback GridUpdated { get; set; }
    [Parameter] public bool IsLoaded { get; set; } = true;
    public List<API.Client.MenuItem>? MenuItems { get; set; }
    public TelerikWindow ModalWindow { get; set; }
    [Parameter] public EventCallback OnClose { get; set; }

    // [Parameter] public EventCallback<Exception> OnError { get; set; }
    [Parameter] public EventCallback<Exception> OnError { get; set; }

    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();

    [Parameter] public EventCallback<DriveListItem?> RecieveItemDoubleClick { get; set; }

    [Parameter] public EventCallback RefreshRequested { get; set; }

    [Parameter] public string ReturnUrl { get; set; } = "";

    [Parameter] public EventCallback ReSyncDataObject { get; set; } //To ensure the dataobject is re-synced after generating a document.
    [Parameter] public EventCallback SaveDataObject { get; set; }

    //CBLD-791: These two are used to block the save & exit buttons.
    [Parameter] public bool DeleteOperationPerformed { get; set; }

    [Parameter] public EventCallback<bool> DeleteOperationPerformedChanged { get; set; }

    [Parameter] public bool HasChanges { get; set; } = false;
    [Parameter] public EventCallback<bool> HasChangesChanged { get; set; }

    private string? GridCodeSelection { get; set; }
    private string HeaderCssIcon { get; set; } = "";
    private string HeaderText { get; set; } = "";
    private string? LoadPageUrl { get; set; }
    private bool ModalWindowIsVisible { get; set; } = false;
    private bool windowIsClosable { get; set; } = true;
    private string? WindowTitle { get; set; }

    //CBLD-384 - "Cache" the URL instead of assigning it to the dataObject in OnParameterSet.
    private string sharePointUrl { get; set; } = "";

    private string isButtonLoading = "spinner-border spinner-border-sm";
    private string buttonLoadingText = "Loading";

    public async Task NavigateToUrlAsync(string url, bool openInNewTab)
    {
        try
        {
            if (openInNewTab)
                _ = JSRuntime.InvokeAsync<object>("open", url, "_blank");
            else
                NavManager.NavigateTo(url ?? "", false, true);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", $"Error navigating to URL. {url}");
            ex.Data.Add("PageMethod", "ButtonMenu/NavigateToUrlAsync()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    public async Task RequestRefresh()
    {
        try
        {
            dataObject = new DataObject();
            await RefreshComponent();
            await RefreshRequested.InvokeAsync(null);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to refresh the component.");
            ex.Data.Add("PageMethod", "ButtonMenu/RequesRefresh()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    public async Task ShowModal()
    {
        ModalWindowIsVisible = true;
    }

    protected void CloseWindowCross()
    {
        ModalWindowIsVisible = false;
    }

    protected async Task<ExecuteMenuItemResponse> OnClickHandler(API.Client.MenuItem item)
    {
        try
        {
            formHelper = new FormHelper(coreClient, sageIntegrationService, EntityTypeGuid, userService);
            ClickedItem = item;
            if (item.Text == "Cancel")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "Cancel");
                // Close the menu MenuItems = null; Return to previous Window without saving
                await NavigateToUrlAsync(item.Url ?? "", item.OpenInNewTab);
                //NavManager.NavigateTo(NavManager.Uri, true);
                /*
                 * Fix for CBLD-140
                 *
                 * [*] Because this is called here, even if there are changes made,
                 * the modal will just end up closing.
                 *
                 * [*] If not called & no changes are made, the modal will not close.
                 *
                 * 10/06/24 --> Decided to take the functionality from here & add it to the
                 * OnNavigation() function found in the EditPage.razor.cs file.
                 * **/

                //await OnClose.InvokeAsync();
                CloseWindowCross();

                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"Cancel\"");
            }
            else if (item.Text == "Permissions")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "Permissions");
                //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
                var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, item._Guid);

                // Open the Modal showing the permissions dialog set LoadPageUrl to empty as
                // GridCode required instead
                DetailPageParameters.Clear();
                DetailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                DetailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                DetailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                DetailPageParameters.Add("OnError", EventCallback.Factory.Create(this, OnError));
                DetailPageParameters.Add("RecordGuid", item.RecordGuid);
                LoadPageUrl = " Concursus.PWA.Shared.Permissions";
                GridCodeSelection = "";
                WindowTitle = "Permissions";
                HeaderCssIcon = item.Icon?.ToString() ?? "";
                HeaderText = item.Text;
                _ = ShowModal();
                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"Permissions\"");
            }
            else if (item.Text == "Record History")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "Record History");
                //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
                var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, item._Guid);

                // Open the Modal showing the permissions dialog set LoadPageUrl to empty as
                // GridCode required instead
                DetailPageParameters.Clear();
                DetailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                DetailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                DetailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                DetailPageParameters.Add("OnError", EventCallback.Factory.Create(this, OnError));
                DetailPageParameters.Add("RecordGuid", item.RecordGuid);
                LoadPageUrl = " Concursus.PWA.Shared.RecordHistory";
                GridCodeSelection = "";
                WindowTitle = "Record History";
                HeaderCssIcon = item.Icon?.ToString() ?? "";
                HeaderText = item.Text;
                _ = ShowModal();

                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"Record History\"");
            }
            else if (item.Text == "View Documents")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "View Documents");
                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"View Documents\"");

                try
                {
                    /*
                     * OE: CBLD-384 Slightly altered the original logic by checking for dataObject.SharePointUrl since we can get this in the OnInitialisedAsync().
                     * **/
                    if (dataObject != null && sharePointUrl != "")
                    {
                        _ = NavigateToUrlAsync(sharePointUrl ?? "", item.OpenInNewTab);
                    }
                    else
                    {
                        var response = await formHelper.SharePointCreate(new SharePointCreateRequest()
                        {
                            DataObject = dataObject,
                            DataObjectUpsertRequest = new DataObjectUpsertRequest()
                            {
                                DataObject = dataObject,
                                EntityQueryGuid = Guid.Empty.ToString(),
                                ValidateOnly = true
                            }
                        });
                        if (!string.IsNullOrEmpty(response.ErrorReturned))
                        {
                            throw new Exception(response.ErrorReturned);
                        }
                        dataObject = response.DataObject;
                        sharePointUrl = response.DataObject.SharePointUrl; //Assign the URL here, too.

                        _ = NavigateToUrlAsync(dataObject?.SharePointUrl ?? "", item.OpenInNewTab);
                    }
                }
                catch (Exception ex)
                {
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while trying to view documents.");
                    ex.Data.Add("PageMethod", "ButtonMenu/OnClickHandler(View Documents)");
                    _ = OnError.InvokeAsync(ex);
                }
            }
            else if (item.Text == "Document Tasks")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "Document Tasks");
                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"Document Tasks\"");

                try
                {
                    //OE: CBLD-498 --> Save the dataObject first
                    await SaveDataObject.InvokeAsync();

                    //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
                    var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, item.EntityQueryGuid);

                    DetailPageParameters.Clear();
                    DetailPageParameters.Add("ListOfMergeDocuments", dataObject.MergeDocuments);
                    DetailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString());
                    DetailPageParameters.Add("Windowed", true);
                    // DetailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                    DetailPageParameters.Add("RecordGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(item.RecordGuid).ToString());
                    DetailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                    DetailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                    DetailPageParameters.Add("EntityProperties", EntityProperties);
                    DetailPageParameters.Add("ReSyncDataObject", EventCallback.Factory.Create(this, ReSyncDataObject));
                    //Populate require URL for Modal window
                    LoadPageUrl = " Concursus.PWA.Pages.DocumentTaskView";
                    GridCodeSelection = "";
                    WindowTitle = "Document Tasks";
                    HeaderCssIcon = item.Icon?.ToString() ?? "";
                    HeaderText = item.Text;
                    _ = ShowModal();
                }
                catch (Exception ex)
                {
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while trying to view document tasks.");
                    ex.Data.Add("PageMethod", "ButtonMenu/OnClickHandler(Document Tasks)");
                    _ = OnError.InvokeAsync(ex);
                }
            }
            else if (item.Text == "Modal Collection")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "Modal Collection");
                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"Modal Collection\"");

                try
                {
                    //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
                    var (parentDataObjectReference, serializedParentDataObjectReference) =
                        PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid,
                            item.EntityQueryGuid);

                    DetailPageParameters.Clear();
                    DetailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                    DetailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                    LoadPageUrl = " Concursus.PWA.Pages.ModalCollection";
                    WindowTitle = "Modal Collection";
                    HeaderCssIcon = item.Icon?.ToString() ?? "";
                    HeaderText = item.Text;
                    _ = ShowModal();
                }
                catch (Exception ex)
                {
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while trying to view the modal collection.");
                    ex.Data.Add("PageMethod", "ButtonMenu/OnClickHandler(Modal Collection)");
                    _ = OnError.InvokeAsync(ex);
                }
            }
            else if (item.Text == "SharePoint Browser")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "SharePoint Browser");
                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"SharePoint Browser\"");

                try
                {
                    var SharePointSiteID = dataObject.DataProperties
                        .FirstOrDefault(p => p.EntityPropertyGuid == "6551966b-1294-437e-8e20-e9771c9f2d1e").Value
                        .Unpack<StringValue>().Value;

                    if (Guid.Parse(SharePointSiteID) != Guid.Empty)
                    {
                        var sharePointSitesDropDown = PWAFunctions.GetSharePointSiteDropDownNameFromGuid(SharePointSiteID);

                        DetailPageParameters.Clear();
                        DetailPageParameters.Add("EntityTypeGuid", Guid.Empty.ToString());
                        DetailPageParameters.Add("SharePointSiteId", SharePointSiteID);
                        DetailPageParameters.Add("IsWindowOpen", true);
                        // DetailPageParameters.Add("CloseWindow",
                        // EventCallback.Factory.Create(this, CloseWindow));
                        DetailPageParameters.Add("TemplateFolderName", sharePointSitesDropDown);
                        // Wrap the HandleItemDoubleClick method in an EventCallback
                        var eventCallback = EventCallback.Factory.Create<DriveListItem>(this, HandleItemDoubleClick);
                        // Pass the EventCallback to the child component
                        DetailPageParameters.Add("OnItemDoubleClick", eventCallback);
                        //Populate require URL for Modal window
                        LoadPageUrl = " Concursus.PWA.Shared.SharePointBrowser";
                        GridCodeSelection = "";
                        WindowTitle = "SharePoint Browser";
                        HeaderCssIcon = item.Icon?.ToString() ?? "";
                        HeaderText = item.Text;
                        _ = ShowModal();
                    }
                }
                catch (Exception ex)
                {
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while trying to view the SharePoint Browser.");
                    ex.Data.Add("PageMethod", "ButtonMenu/OnClickHandler(SharePoint Browser)");
                    _ = OnError.InvokeAsync(ex);
                }
            }
            else if (item.Text == "Generate CSV Download")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "Generate CSV Download");
                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"Generate CSV Download\"");

                try
                {
                    var infoMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Information);
                    await OnError.InvokeAsync(infoMessage);
                    //Retrieve the value of the Export Details from SageExportDetail
                    var sageExportDetail = dataObject?.DataProperties?
                        .FirstOrDefault(p => p.EntityPropertyGuid == "ba409890-fefe-4751-a12c-b6f978324d0e")
                        ?.Value
                        .Unpack<StringValue>().Value;

                    if (!string.IsNullOrEmpty(sageExportDetail))
                    {
                        // Get current date and time
                        DateTime now = DateTime.Now;

                        // Format the date and time
                        string formattedDate = now.ToString("dd/MM/yyyy_HH:mm");

                        PWAFunctions.GenerateCsvDownload(sageExportDetail, JSRuntime, $"Sage Export {formattedDate}.csv");
                    }
                    var successMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Success);
                    await OnError.InvokeAsync(successMessage);
                }
                catch (Exception ex)
                {
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while trying to generate a CSV download.");
                    ex.Data.Add("PageMethod", "ButtonMenu/OnClickHandler(Generate CSV Download)");
                    _ = OnError.InvokeAsync(ex);
                }
            }
            else if (item.Text == "Revise Quote")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "Duplicate Quote");
                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"Revise Quote\"");

                var DupeQuoteInfoMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Information);
                await OnError.InvokeAsync(DupeQuoteInfoMessage);
            }
            else if (item.Text == "Duplicate Enquiry")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "Duplicate Enquiry");
                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"Revise Quote\"");

                var DupeEnquiryInfoMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Information);
                await OnError.InvokeAsync(DupeEnquiryInfoMessage);
            }
            else if (item.Text == "Delete")
            {
                _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), "Delete");
                InteractionTracker.Log(NavManager.Uri ?? "Clicking Task Menu Item", $"User Clicked \"Delete\"");

                try
                {
                    var infoMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Information);
                    await OnError.InvokeAsync(infoMessage);

                    var response = await formHelper.DataObjectDeleteAsync(dataObject ?? new DataObject(),
                        PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(item.EntityQueryGuid).ToString());

                    if (!string.IsNullOrEmpty(response.ErrorReturned))
                    {
                        //Unique case: Show warning message for workflow deletion.
                        if (response.ErrorReturned.Contains("Cannot delete enabled workflows") || response.ErrorReturned.Contains("Only members of the Superusers group can run this action."))
                        {
                            var cannotDeleteRecord = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(response.ErrorReturned), ShowMessageType.Warning);

                            await OnError.InvokeAsync(cannotDeleteRecord);

                            return new ExecuteMenuItemResponse();
                        }
                        //Show error message (Note: need to find a way to dynamically select the message type - Error, warning, info)
                        else
                        {
                            var errorMsg = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(response.ErrorReturned), ShowMessageType.Error);

                            await OnError.InvokeAsync(errorMsg);

                            return new ExecuteMenuItemResponse();
                        }
                    }

                    var successMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Success);
                    await OnError.InvokeAsync(successMessage);

                    //Only if we have multiple modals should we disable the save buttons - otherwise, stick to redirect.
                    if (modalService.GetOpenModals().Count > 1)
                    {
                        //THis should disabled the buttons!
                        DeleteOperationPerformed = true;
                        await DeleteOperationPerformedChanged.InvokeAsync(true);

                        StateHasChanged();

                        //No need to perform any other operations.
                        return new ExecuteMenuItemResponse();
                    }
                    else
                    {
                        _ = NavigateToUrlAsync(ReturnUrl ?? "", item.OpenInNewTab);
                    }
                }
                catch (Exception ex)
                {
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while trying to delete the record.");
                    ex.Data.Add("PageMethod", "ButtonMenu/OnClickHandler(Delete)");
                    _ = OnError.InvokeAsync(ex);
                }
            }

            // Open the link
            //_= NavigateToUrlAsync(item.Url ?? "", item.openInNewTab);
            //Check for action menu items
            if (string.IsNullOrEmpty(item.EntityQueryGuid) || dataObject == null)
            {
                return new ExecuteMenuItemResponse();
            }

            try
            {
                // Need to save record before executing action menu item -- This has been changed to
                // true to stop an error. record must be saved by user
                var saveResponse = await PWAFunctions.TryUpsertDataObjectAsync(formHelper, dataObject, item, true);

                dataObject = await formHelper.ReadDataObjectAsync(dataObject.Guid, ParentDataObjectReference); //CBLD-516.

                if (saveResponse is { Item2.HasValidationMessages: false })
                {
                    await PWAFunctions.DisplayMessageAsync("Record saved successfully....", ShowMessageType.Success);
                    // Removed the line below as it was causing the dataObject to lose its values
                    //dataObject = saveResponse.Value.Item2;
                    var response = await formHelper.MenuItemPostAsync(item.EntityQueryGuid, dataObject);
                    if (!string.IsNullOrEmpty(response.ErrorReturned) && item.EntityQueryGuid != Guid.Empty.ToString())
                    {
                        throw new RpcException(new Status(StatusCode.FailedPrecondition, response.ErrorReturned));
                    }
                    if (!response.ExitOnSuccess)
                    {
                        var OriginalDataObjectGuid = dataObject.Guid;
                        dataObject = response.DataObject;

                        // Check if the action menu item is "Duplicate Quote"
                        if (item.Text == "Revise Quote")
                        {
                            var dupeQuoteSuccessMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Success);
                            await OnError.InvokeAsync(dupeQuoteSuccessMessage);

                            // Wait for 2 seconds before navigating
                            await Task.Delay(2000);

                            // Process data object references for navigation
                            ParentDataObjectReference = new DataObjectReference(response.DataObject.Guid, "1C4794C1-F956-4C32-B886-5500AC778A56");
                            var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, response.DataObject.Guid, "1C4794C1-F956-4C32-B886-5500AC778A56");

                            //CBLD - 771
                            // Step 1: Parse safe GUID
                            string guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(response.DataObject.Guid).ToString();

                            // Step 2: Serialized reference should already be encoded (confirm this!)
                            string sPDOR = serializedParentDataObjectReference;

                            // Step 3: ENCODE the full URL you are appending
                            string uri = System.Web.HttpUtility.UrlEncode(NavManager.BaseUri + "quotes/00000000-0000-0000-0000-000000000000");

                            // Step 4: Combine
                            string url = $"QuoteDetail/{guid}/{sPDOR}/{uri}";

                            // Debug
                            Console.WriteLine($"Navigating to: {url}");

                            // Step 5: Navigate
                            NavManager.NavigateTo(url, forceLoad: true, replace: true);

                            return response; // Ensure no further operations interfere with navigation
                        }
                        else if (item.Text == "Duplicate Enquiry")
                        {
                            var dupeEnquirySuccessMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Success);
                            await OnError.InvokeAsync(dupeEnquirySuccessMessage);

                            // Wait for 2 seconds before navigating
                            await Task.Delay(2000);

                            // Process data object references for navigation
                            ParentDataObjectReference = new DataObjectReference(response.DataObject.Guid, "3B4F2DF9-B6CF-4A49-9EED-2206473867A1");
                            var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, response.DataObject.Guid, "3B4F2DF9-B6CF-4A49-9EED-2206473867A1");

                            //CBLD-771
                            // Step 1: Parse safe GUID
                            string guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(response.DataObject.Guid).ToString();

                            // Step 2: Serialized reference should already be encoded (confirm this!)
                            string sPDOR = serializedParentDataObjectReference;

                            // Step 3: ENCODE the full URL you are appending
                            string uri = System.Web.HttpUtility.UrlEncode(NavManager.BaseUri + "Enquiries/00000000-0000-0000-0000-000000000000");

                            // Step 4: Combine
                            string url = $"EnquiryDetail/{guid}/{sPDOR}/{uri}";

                            // Debug
                            Console.WriteLine($"Navigating to: {url}");

                            // Step 5: Navigate
                            NavManager.NavigateTo(url, forceLoad: true, replace: true);

                            return response; // Ensure no further operations interfere with navigation
                        }
                        else if (item.Text == "Revise Enquiry")
                        {
                            var dupeEnquirySuccessMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Success);
                            await OnError.InvokeAsync(dupeEnquirySuccessMessage);

                            // Wait for 2 seconds before navigating
                            await Task.Delay(2000);

                            // Process data object references for navigation
                            ParentDataObjectReference = new DataObjectReference(response.DataObject.Guid, "3B4F2DF9-B6CF-4A49-9EED-2206473867A1");
                            var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, response.DataObject.Guid, "3B4F2DF9-B6CF-4A49-9EED-2206473867A1");

                            //CBLD-771
                            // Step 1: Parse safe GUID
                            string guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(response.DataObject.Guid).ToString();

                            // Step 2: Serialized reference should already be encoded (confirm this!)
                            string sPDOR = serializedParentDataObjectReference;

                            // Step 3: ENCODE the full URL you are appending
                            string uri = System.Web.HttpUtility.UrlEncode(NavManager.BaseUri + "Enquiries/00000000-0000-0000-0000-000000000000");

                            // Step 4: Combine
                            string url = $"EnquiryDetail/{guid}/{sPDOR}/{uri}";

                            // Debug
                            Console.WriteLine($"Navigating to: {url}");

                            // Step 5: Navigate
                            NavManager.NavigateTo(url, forceLoad: true, replace: true);

                            return response; // Ensure no further operations interfere with navigation
                        }

                        StateHasChanged();
                    }
                    else
                    {
                        NavManager.NavigateTo(ReturnUrl ?? "");
                    }
                }
                else
                {
                    var errorMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Error);
                    await OnError.InvokeAsync(errorMessage);
                    return new ExecuteMenuItemResponse() { DataObject = dataObject };
                }

                var successMessage = PWAFunctions.GetMessageDisplayFromActionMenuItem(item, new Exception(), ShowMessageType.Success);
                await OnError.InvokeAsync(successMessage);
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "An error occurred while trying to execute the action menu item.");
                ex.Data.Add("PageMethod", "ButtonMenu/OnClickHandler()");
                _ = OnError.InvokeAsync(ex);
                throw;
            }
            // CBLD-629 - SB: added to enforce ReSync of dataobject after Task finished
            await ReSyncDataObject.InvokeAsync();
            //// END CBLD-629
            return new ExecuteMenuItemResponse() { DataObject = dataObject };
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to execute the action menu item.");
            ex.Data.Add("PageMethod", "ButtonMenu/OnClickHandler()");
            _ = OnError.InvokeAsync(ex);
            throw;
        }
    }

    private bool ToPreventSharePointCreationIfEmptyGuid()
    {
        string Url = NavManager.Uri.ToString();
        string EmptyGuid = Guid.Empty.ToString();

        if (Url.Contains("EnquiryDetail/" + EmptyGuid))
            return true;

        return false;
    }

    protected override void OnInitialized()
    {
        try
        {
            base.OnInitialized();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to initialise the button menu.");
            ex.Data.Add("PageMethod", "ButtonMenu/OnInitialized()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    //protected override void OnParametersSet()
    //{
    //    OnInitialized();
    //}

    protected override Task OnParametersSetAsync()
    {
        InitializeButton();
        return base.OnParametersSetAsync();
    }

    //CBLD-416: Seperated function so we can call on its own.
    public async Task InitializeButton()
    {
        //Call it before the button is actually rendered. //CBLD-416
        // if ((sharePointUrl == "" && !ToPreventSharePointCreationIfEmptyGuid())
        //if(!string.IsNullOrEmpty(dataObject?.SharePointSiteIdentifier) && sharePointUrl == "")
        if (string.IsNullOrEmpty(sharePointUrl))
        {
            sharePointUrl = dataObject?.SharePointUrl ?? "";
            if (!string.IsNullOrEmpty(dataObject?.SharePointSiteIdentifier) && sharePointUrl == "")
            {
                await SetSharePointLocationForButton();
            }
        }

        MenuItems = new List<API.Client.MenuItem>
            {
                new()
                {
                    Text = "Tasks", // items that don't have a URL will not render links
                    Items = new List<API.Client.MenuItem>
                    {
                        // Check if SharePointUrl contains a value
                        //!string.IsNullOrEmpty(dataObject?.SharePointSiteIdentifier)
                         //CBLD-415.
                         sharePointUrl != ""
                            ? new API.Client.MenuItem
                            {
                                Text = "View Documents",
                                Icon = "bi bi-folder-fill",
                                OpenInNewTab = true
                            }
                            : new API.Client.MenuItem(), // Set to null if condition is false
                        new()
                        {
                            Text = "Record History",
                            Icon = "bi bi-clock-history",
                            RecordGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObject?.Guid).ToString()
                        },
                        new()
                        {
                            IsSeparator = true
                        },
                        new()
                        {
                            Text = "Permissions",
                            Icon = "bi bi-key-fill",
                            RecordGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObject?.Guid).ToString()
                        },
                        new()
                        {
                            Text = "Cancel",
                            Url = ReturnUrl,
                            Icon = "bi bi-x-circle-fill"
                        },
                        new()
                        {
                            IsSeparator = true
                        },
                        new()
                        {
                            Text = "Delete",
                            Icon = "bi bi-trash",
                            EntityTypeGuid = dataObject?.EntityTypeGuid,
                            EntityQueryGuid = Guid.Empty.ToString(),
                            ObjectGuid = dataObject?.Guid
                        },
                        //If Development environment, show Modal Collection
                        appConfiguration.EnvironmentType == "DEV" ? new()
                        {
                            Text = "Modal Collection",
                            Icon = "bi bi-window-stack"
                        }: new API.Client.MenuItem(), // Set to null if condition is false
                    }
                }
            };
        if (MenuItems != null && MenuItems[0].Items == null) MenuItems[0].Items = new List<API.Client.MenuItem>();
        {
            var mergeDocumentEntry = dataObject?.EntityTypeGuid ?? "";
            if (dataObject?.ActionMenuItems.Count > 0)
                //Loop through dataObject.ActionMenuItems adding a new MenuItem
                foreach (var item in dataObject.ActionMenuItems.OrderBy(o => o.SortOrder))
                    if (item.Type == "A")
                        MenuItems?[0]?.Items?.Add(new API.Client.MenuItem
                        {
                            Text = item.Label + (HasChanges ? " (Please, save the record)" : ""),
                            Icon = item.IconCss,
                            EntityQueryGuid = item.EntityQueryGuid,
                            EntityTypeGuid = item.EntityTypeGuid,
                            IsReadOnly = (dataObject?.HasValidationMessages ?? false) || HasChanges,
                            RedirectToTargetGuid = item.RedirectToTargetGuid,
                            SortOrder = item.SortOrder,
                        });
                    else
                        MenuItems?[0]?.Items?.Add(new API.Client.MenuItem
                        {
                            IsSeparator = true
                        });
            if (dataObject?.MergeDocuments.Count > 0)
            {
                //Create New Menu Item called 'Document Tasks'
                var documentTasks = new API.Client.MenuItem
                {
                    Text = "Document Tasks",
                    Icon = "bi bi-file-earmark-text-fill",
                    EntityTypeGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString(),
                    RecordGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObject?.Guid).ToString()
                };

                MenuItems?[0]?.Items?.Add(documentTasks);
            }

            if (mergeDocumentEntry == "ced50b7f-976b-421d-93d9-f4992d0afe95")
            {
                var SharePointSiteID = dataObject.DataProperties
                    .FirstOrDefault(p => p.EntityPropertyGuid == "6551966b-1294-437e-8e20-e9771c9f2d1e").Value
                    .Unpack<StringValue>().Value;

                //Create New Menu Item called 'SharePoint Browser'
                var documentTasks = new API.Client.MenuItem
                {
                    Text = "SharePoint Browser",
                    Icon = "bi bi-file-earmark-text-fill"
                };

                MenuItems?[0]?.Items?.Add(documentTasks);
            }

            if (dataObject.EntityTypeGuid == "ba705b59-dbd9-4aa2-891e-0d55376650f9") //SageExportDetail
            {
                //Create New Menu Item called 'Generate CSV Download'
                var exportTasks = new API.Client.MenuItem
                {
                    Text = "Generate CSV Download",
                    Icon = "bi bi-file-earmark-text-fill",
                    EntityTypeGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString(),
                    RecordGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObject?.Guid).ToString()
                };

                MenuItems?[0]?.Items?.Add(exportTasks);
            }
        }
        //Set the loader to false for the button.
        _ = buttonIsLoading(false);
        StateHasChanged();
    }

    //Local function for adding a loading icon while the SharePoint URL is retrieved.
    //OE: CBLD-411: Added async to ensure the UI is not blocked.
    private async Task buttonIsLoading(bool loading)
    {
        //await Task.Delay(10000); //For testing non-blocking UI mechanism.
        if (loading)
        {
            //Set it to empty - this way, the user will have to wait for the button to load.
            isButtonLoading = "spinner-border spinner-border-sm";
            buttonLoadingText = "Loading";

            MenuItems = new List<API.Client.MenuItem> { new() { Text = "" } };
        }
        else
        {
            isButtonLoading = "";
            buttonLoadingText = "";
        }
        StateHasChanged();
    }

    //OE: CBLD-384
    //Retrieves the SharePoint URL on page load instead of when the button is clicked.
    public async Task SetSharePointLocationForButton()
    {
        if (sharePointUrl != "")
            return;

        try
        {
            formHelper = new FormHelper(coreClient, sageIntegrationService, EntityTypeGuid, userService);
            _ = buttonIsLoading(true);

            if (formHelper != null)
            {
                //CBLD-415.

                //string _dataObject = JsonConvert.SerializeObject(dataObject, Formatting.Indented);

                //Console.WriteLine(_dataObject);

                var response = await formHelper.GetSharePointUrl(dataObject);
                if (response.Message != "")
                {
                    sharePointUrl = response.Message;
                    _ = buttonIsLoading(false);

                    return;
                }
                /**
                 * CBLD-415: Left the old method in just in case we need to fall back onto it.
                 *
                 */
                else
                {
                    var res = await formHelper.SharePointCreate(new SharePointCreateRequest()
                    {
                        DataObject = dataObject,
                        DataObjectUpsertRequest = new DataObjectUpsertRequest()
                        {
                            DataObject = dataObject,
                            EntityQueryGuid = Guid.Empty.ToString(),
                            ValidateOnly = true
                        }
                    });

                    if (!string.IsNullOrEmpty(res.ErrorReturned))
                    {
                        throw new Exception(res.ErrorReturned);
                    }

                    dataObject = res.DataObject;
                    //CBLD - 384: If a field changes, the dataobject gets changed which means the URL gets lost.Store URL in its own variable.
                    sharePointUrl = res.DataObject.SharePointUrl;

                    StateHasChanged();
                }
            }
        }
        catch (Exception ex)
        {
            return;
        }
        finally
        {
            _ = buttonIsLoading(false);
        }
    }

    private string GetParentGuid()
    {
        try
        {
            // Retrieve the value associated with the "RecordGuid (ParentDataObjectReference)" key
            // when loading a DynamicGrid
            if (DetailPageParameters.TryGetValue("RecordGuid", out var parentGuid))
                return parentGuid?.ToString();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to get the parent guid.");
            ex.Data.Add("PageMethod", "ButtonMenu/GetParentGuid()");
            _ = OnError.InvokeAsync(ex);
        }

        // If the key is not found, you can return a default value or handle it as needed
        return Guid.Empty.ToString();
    }

    private async Task HandleItemDoubleClick(DriveListItem clickedItem)
    {
        try
        {
            // Handle the details received from the child component
            Console.WriteLine($"Received details from child: Item ID: {clickedItem.Id}, Name: {clickedItem.Name}");
            await RecieveItemDoubleClick.InvokeAsync(clickedItem);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to handle the item double-click.");
            ex.Data.Add("PageMethod", "ButtonMenu/HandleItemDoubleClick()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private async Task RefreshComponent()
    {
        try
        {
            await OnInitializedAsync(); // Re-fetch the menu items
            StateHasChanged(); // Notify Blazor that the component needs to re-render
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to refresh the component.");
            ex.Data.Add("PageMethod", "ButtonMenu/RefreshComponent()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private void VisibleChangedHandler(bool currVisible) // this will always come in as false
    {
        ModalWindowIsVisible = currVisible; // if you don't do this, the window won't close because of the user action
    }
}