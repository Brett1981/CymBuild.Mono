using Concursus.API.Client;
using Concursus.API.Client.Classes;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.PWA.Shared;
using Google.Protobuf;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Forms;
using Microsoft.JSInterop;
using Newtonsoft.Json;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Classes;

public enum WellKnownType
{
    Double,
    String,
    Int32,
    Int64,
    Timestamp,
    Bool,
    Byte,
    Char,
    DateTime,
    Decimal,
    Single,
    Int16,
    Object
}

public static class PWAFunctions
{
    #region Public Properties

    [Parameter] public static EventCallback<Exception> OnError { get; set; }

    // EventCallback for when MyDataObjectReference changes
    [Parameter]
    public static EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }

    // Ensure this is unique for each modal instance
    private static string modalId = Guid.Empty.ToString();

    #endregion Public Properties

    #region Public Methods
    /// <summary>
    /// Sets the browser tab title in a safe reusable way.
    /// Falls back to the application name when no suffix is supplied.
    /// </summary>
    public static async Task SetBrowserTabTitleAsync(
        IJSRuntime jsRuntime,
        string applicationName,
        string? recordType = null,
        string? recordNumber = null)
    {
        if (jsRuntime == null)
        {
            return;
        }

        var safeApplicationName = string.IsNullOrWhiteSpace(applicationName)
            ? "CymBuild"
            : applicationName.Trim();

        string title;

        if (string.IsNullOrWhiteSpace(recordType) || string.IsNullOrWhiteSpace(recordNumber))
        {
            title = safeApplicationName;
        }
        else
        {
            title = $"{safeApplicationName} - {recordType.Trim()} {recordNumber.Trim()}";
        }

        await jsRuntime.InvokeVoidAsync("cymBuild.setDocumentTitle", title);
    }
    public static string BuildEntityNavigationUrl(
            string baseUri,
            string detailPageUri,
            Guid recordGuid,
            Guid entityTypeGuid,
            string? currentUrl = null,
            string? inheritedReturnUrl = null)
    {
        if (string.IsNullOrWhiteSpace(baseUri))
        {
            throw new ArgumentException("BaseUri cannot be null or empty.", nameof(baseUri));
        }

        if (string.IsNullOrWhiteSpace(detailPageUri))
        {
            throw new ArgumentException("DetailPageUri cannot be null or empty.", nameof(detailPageUri));
        }

        if (recordGuid == Guid.Empty)
        {
            throw new ArgumentException("RecordGuid cannot be empty.", nameof(recordGuid));
        }

        if (entityTypeGuid == Guid.Empty)
        {
            throw new ArgumentException("EntityTypeGuid cannot be empty.", nameof(entityTypeGuid));
        }

        var normalizedBaseUri = baseUri.TrimEnd('/');

        var dataObjectReference = new DataObjectReference(
            recordGuid.ToString(),
            entityTypeGuid.ToString());

        var serializedDataObjectReference =
            HttpUtility.UrlEncode(JsonConvert.SerializeObject(dataObjectReference));

        var resolvedReturnUrl = ResolveReturnUrl(
            baseUri: normalizedBaseUri,
            currentUrl: currentUrl,
            inheritedReturnUrl: inheritedReturnUrl,
            targetDetailPageUri: detailPageUri);

        var encodedReturnUrl = HttpUtility.UrlEncode(resolvedReturnUrl);

        return detailPageUri.Equals("DynamicEdit", StringComparison.OrdinalIgnoreCase)
            ? $"{detailPageUri}/{entityTypeGuid}/{recordGuid}/{serializedDataObjectReference}/{encodedReturnUrl}"
            : $"{detailPageUri}/{recordGuid}/{serializedDataObjectReference}/{encodedReturnUrl}";
    }

    public static string ResolveReturnUrl(
        string baseUri,
        string? currentUrl,
        string? inheritedReturnUrl,
        string targetDetailPageUri)
    {
        if (!string.IsNullOrWhiteSpace(inheritedReturnUrl))
        {
            return NormalizeReturnUrl(baseUri, inheritedReturnUrl, targetDetailPageUri);
        }

        if (!string.IsNullOrWhiteSpace(currentUrl))
        {
            return NormalizeReturnUrl(baseUri, currentUrl, targetDetailPageUri);
        }

        return BuildDefaultReturnUrl(baseUri, targetDetailPageUri);
    }

    public static string NormalizeReturnUrl(
    string baseUri,
    string candidateUrl,
    string targetDetailPageUri)
    {
        if (string.IsNullOrWhiteSpace(candidateUrl))
        {
            return BuildDefaultReturnUrl(baseUri, targetDetailPageUri);
        }

        var decoded = HttpUtility.UrlDecode(candidateUrl) ?? candidateUrl;
        var normalizedBaseUri = baseUri.TrimEnd('/');

        if (!Uri.TryCreate(decoded, UriKind.Absolute, out var absoluteUri))
        {
            return BuildDefaultReturnUrl(normalizedBaseUri, targetDetailPageUri);
        }

        var path = absoluteUri.AbsolutePath.Trim('/');

        if (string.IsNullOrWhiteSpace(path))
        {
            return absoluteUri.GetLeftPart(UriPartial.Authority) + "/";
        }

        var segments = path.Split('/', StringSplitOptions.RemoveEmptyEntries);

        if (segments.Length == 0)
        {
            return absoluteUri.GetLeftPart(UriPartial.Authority) + "/";
        }

        var firstSegment = segments[0];

        var isDetailPage =
            firstSegment.Equals("QuoteDetail", StringComparison.OrdinalIgnoreCase) ||
            firstSegment.Equals("EnquiryDetail", StringComparison.OrdinalIgnoreCase) ||
            firstSegment.Equals("JobDetail", StringComparison.OrdinalIgnoreCase) ||
            firstSegment.Equals("AssetDetail", StringComparison.OrdinalIgnoreCase) ||
            firstSegment.Equals("AccountDetail", StringComparison.OrdinalIgnoreCase) ||
            firstSegment.Equals("DynamicEdit", StringComparison.OrdinalIgnoreCase);

        if (isDetailPage)
        {
            // Standard detail route:
            //   DetailPage / RecordGuid / SerializedReference / ReturnUrl
            //
            // DynamicEdit route:
            //   DynamicEdit / EntityTypeGuid / RecordGuid / SerializedReference / ReturnUrl

            if (firstSegment.Equals("DynamicEdit", StringComparison.OrdinalIgnoreCase))
            {
                // Keep the first 5 segments where possible
                if (segments.Length >= 5)
                {
                    var cleanedPath = "/" + string.Join("/", segments[..5]);
                    return $"{absoluteUri.Scheme}://{absoluteUri.Authority}{cleanedPath}";
                }

                // If incomplete, fall back safely
                return BuildDefaultReturnUrl(normalizedBaseUri, targetDetailPageUri);
            }
            else
            {
                // Keep the first 4 segments where possible
                if (segments.Length >= 4)
                {
                    var cleanedPath = "/" + string.Join("/", segments[..4]);
                    return $"{absoluteUri.Scheme}://{absoluteUri.Authority}{cleanedPath}";
                }

                // If only 3 segments exist, rebuild with a safe trailing return URL
                if (segments.Length == 3)
                {
                    var fallbackReturnUrl = HttpUtility.UrlEncode(
                        BuildDefaultReturnUrl(normalizedBaseUri, firstSegment));

                    var cleanedPath = "/" + string.Join("/", segments) + "/" + fallbackReturnUrl;
                    return $"{absoluteUri.Scheme}://{absoluteUri.Authority}{cleanedPath}";
                }

                return BuildDefaultReturnUrl(normalizedBaseUri, targetDetailPageUri);
            }
        }

        // For non-detail routes like /quotes/... or /enquiries/... keep as-is
        return $"{absoluteUri.Scheme}://{absoluteUri.Authority}/{path}";
    }


    public static string BuildDefaultReturnUrl(string baseUri, string detailPageUri)
    {
        if (string.IsNullOrWhiteSpace(baseUri))
        {
            throw new ArgumentException("BaseUri cannot be null or empty.", nameof(baseUri));
        }

        if (string.IsNullOrWhiteSpace(detailPageUri))
        {
            return $"{baseUri}/";
        }

        return detailPageUri switch
        {
            "QuoteDetail" => $"{baseUri}/quotes/00000000-0000-0000-0000-000000000000",
            "JobDetail" => $"{baseUri}/jobs/00000000-0000-0000-0000-000000000000",
            "EnquiryDetail" => $"{baseUri}/enquiries/00000000-0000-0000-0000-000000000000",
            "AssetDetail" => $"{baseUri}/assets/00000000-0000-0000-0000-000000000000",
            "AccountDetail" => $"{baseUri}/accounts/00000000-0000-0000-0000-000000000000",
            _ => $"{baseUri}/"
        };
    }
    // Method to ensure MyDataObjectReference is valid and notify if changes occur
    public static async Task<DataObjectReference> EnsureDataObjectReferenceAsync(DataObject? dataObject, DataObjectReference? MyDataObjectReference, string DataObjectGuid = "", string EntityTypeGuid = "", ModalService modalService = null)
    {
        //if (MyDataObjectReference == null || (MyDataObjectReference.EntityTypeGuid == Guid.Empty ||
        //                                      MyDataObjectReference.DataObjectGuid == Guid.Empty))
        //{
        MyDataObjectReference = dataObject != null ?
            new DataObjectReference(dataObject.Guid, dataObject.EntityTypeGuid) :
            new DataObjectReference(ParseAndReturnEmptyGuidIfInvalid(DataObjectGuid).ToString(),
                ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString());

        //await ParentDataObjectReferenceChanged.InvokeAsync(MyDataObjectReference);
        //}
        //Ensure newly created records are updated
        if ((MyDataObjectReference != null && modalService != null) &&
            MyDataObjectReference.EntityTypeGuid.ToString() != dataObject.EntityTypeGuid)
        {
            //Get new ModalId, add it to Parameter and register it
            modalId = Guid.NewGuid().ToString();
            MyDataObjectReference = dataObject != null ?
                new DataObjectReference(dataObject.Guid, dataObject.EntityTypeGuid) :
                new DataObjectReference(ParseAndReturnEmptyGuidIfInvalid(DataObjectGuid).ToString(),
                    ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString());

            modalService.RegisterModal(modalId, MyDataObjectReference);
        }
        return MyDataObjectReference;
    }

    public static async Task DisplayMessageAsync(string message, ShowMessageType messageType)
    {
        var ex = new Exception(message);
        ex.Data.Add("MessageType", messageType);
        ex.Data.Add("PageMethod", "PWAFunctions/DisplayMessageAsync()");
        ex.Data.Add("AdditionalInfo", "This message originates from the ButtonMenu");
        await OnError.InvokeAsync(ex);
    }

    // Helper method to check if a value is numeric
    public static bool IsNumeric(string value)
    {
        return double.TryParse(value, out _);
    }

    public static string GetFirstUrlSegment(string url)
    {
        var uri = new Uri(url);
        var segments = uri.AbsolutePath.Split(new[] { '/' }, StringSplitOptions.RemoveEmptyEntries);
        return segments.Length > 0 ? segments[0] : string.Empty;
    }

    public static async Task GenerateCsvDownload(string csvContent, IJSRuntime jsRuntime, string fileName = "Export")
    {
        try
        {
            var downloadUrl = ConvertToCsvDownloadString(csvContent);
            await StartDownload(jsRuntime, downloadUrl, fileName);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to generate and download the CSV file.");
            ex.Data.Add("PageMethod", "PWAFunctions/GenerateCsvDownload()");
            await OnError.InvokeAsync(ex);
        }
    }

    //CBLD-265
    public static Exception GetMessageDisplayFromGridViewAction(GridActionMenuItem item, Exception? infoMessage, ShowMessageType type)
    {
        try
        {
            switch (item.Text)
            {
                case "Create Invoice":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Preparing to generate invoice(s), Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to generate invoice(s), Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions GetMessageDisplayFromGridViewAction()\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Invoice(s) Successfully Created");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Invoice(s) Successfully Created");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem()\r\n");
                    }

                    break;

                //CBLD-253
                case "Invoice Request → Create Invoice (Batch)":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Generating Invoice(s) from Invoice Request(s), Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Generating Invoice(s) from Invoice Request(s), Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions GetMessageDisplayFromGridViewAction()\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Invoice(s) Successfully Created");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Invoice(s) Successfully Created");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem()\r\n");
                    }
                    break;
                case "Batch Delete":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Deleting batch transactions, Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Deleting batch transactions, Please wait, Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions GetMessageDisplayFromGridViewAction()\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Transactions deleted succesfully.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Transactions deleted succesfully.");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem()\r\n");
                    }
                    break;
                case "Approve Invoice(s)":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Approving Invoice(s), Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Approving Invoice(s), Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions GetMessageDisplayFromGridViewAction()\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Approved Invoice(s) succesfully.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Approved Invoice(s) succesfully.");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem()\r\n");
                    }
                    break;
                default:
                    infoMessage = new Exception(item.Text);
                    infoMessage.Data.Add("MessageType", ShowMessageType.Information);
                    infoMessage.Data.Add("AdditionalInfo", "Preparing to generate invoice(s), Please wait");
                    infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Default)\r\n");
                    break;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Unable to get message display from GridViewAction");
            ex.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem()");
            _ = OnError.InvokeAsync(ex);
            return ex;
        }

        return infoMessage;
    }

    public static Exception GetMessageDisplayFromActionMenuItem(API.Client.MenuItem item, Exception? infoMessage,
        ShowMessageType type)
    {
        try
        {
            switch (item.Text)
            {
                case "Create Jobs":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Preparing to create the jobs from the quote, Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to create the jobs from the quote, Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Create Jobs)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Jobs Successfully Created");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Jobs Successfully Created");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Create Jobs)\r\n");
                    }

                    break;

                case "Create Quote(s) from enquiry":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Preparing to create the quote from the enquiry, Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to create the quote from the enquiry, Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Create Quote(s) from enquiry)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Quote has been Successfully Created");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Quote has been Successfully Created");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Create Quote(s) from enquiry)\r\n");
                    }

                    break;

                case "Duplicate Quote":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Preparing to duplicate the quote, Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to duplicate the quote, Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Duplicate Quote)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Duplicate Quote successfully created, Please wait whilst we prepare the new Quote.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Duplicate Quote successfully created, Please wait whilst we prepare the new Quote.");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Duplicate Quote)\r\n");
                    }
                    break;

                case "Generate CSV Download":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Preparing to download the CSV file, Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to download the CSV file, Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Generate CSV Download)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("CSV file successfully downloaded");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "CSV file successfully downloaded");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Generate CSV Download)\r\n");
                    }

                    break;

                case "Delete":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Preparing to delete the record, Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to delete the record, Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Delete)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Record successfully deleted. You can now close this window.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Record successfully deleted");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Delete)\r\n");
                    }
                    else if (type == ShowMessageType.Warning)
                    {
                        var message = infoMessage?.Message;

                        infoMessage = new Exception(message);
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Delete)\r\n");
                    }

                    break;

                case "Duplicate Enquiry":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Preparing to duplicate the enquiry, Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to duplicate the enquiry, Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Duplicate Enquiry)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Duplicate Enquiry successfully created, Please wait whilst we prepare the new Enquiry.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Duplicate Enquiry successfully created, Please wait whilst we prepare the new Enquiry.");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Duplicate Enquiry)\r\n");
                    }

                    break;

                case "Revise Quote":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Preparing to revise the quote. Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to revise the quote. Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Revise Quote)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Quote Revised succesfully. Please wait whilst we prepare the new quote.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Quote Revised succesfully. Please wait whilst we prepare the new quote.");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Revise Quote)\r\n");
                    }

                    break;

                case "Revise Enquiry":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Preparing to revise the enquiry. Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to revise the enquiry. Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Revise Quote)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Enquiry Revised succesfully. Please wait whilst we prepare the new enquiry.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Enquiry Revised succesfully. Please wait whilst we prepare the new enquiry.");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Revise enquiry)\r\n");
                    }
                    break;

                case "Re-open Job":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Re-opening completed job. Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to re-open closed job. Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Re-open Job)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Job re-opened succesfully.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Job re-opened succesfully.");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Re-open Job)\r\n");
                    }
                    break;

                case "Re-open Cancelled Job":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Re-opening cancelled job. Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to re-open cancelled job. Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Re-open Cancelled Job)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Cancelled Job re-opened succesfully.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Cancelled Job re-opened succesfully.");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Re-open Cancelled Job)\r\n");
                    }
                    break;

                case "Re-open Dead Job":
                    if (type == ShowMessageType.Information)
                    {
                        infoMessage = new Exception("Re-opening dead job. Please wait");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Preparing to re-open dead job. Please wait");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Re-open dead Job)\r\n");
                    }
                    else if (type == ShowMessageType.Success)
                    {
                        infoMessage = new Exception("Dead Job re-opened succesfully.");
                        infoMessage.Data.Add("MessageType", type);
                        infoMessage.Data.Add("AdditionalInfo", "Dead Job re-opened succesfully.");
                        infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Re-open Dead Job)\r\n");
                    }
                    break;

                default:
                    infoMessage = new Exception(item.Text);
                    infoMessage.Data.Add("MessageType", type);
                    infoMessage.Data.Add("AdditionalInfo", infoMessage);
                    infoMessage.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem(Default)\r\n");
                    break;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Unable to get message display from ActionMenuItem");
            ex.Data.Add("PageMethod", "PWAFunctions/GetMessageDisplayFromActionMenuItem()");
            _ = OnError.InvokeAsync(ex);
            return ex;
        }

        return infoMessage;
    }

    public static string GetSharePointSiteDropDownNameFromGuid(string sharePointSiteId)
    {
        try
        {
            var sharePointSiteName = sharePointSiteId switch
            {
                "9f0db80e-a96a-4273-b23e-15fc9f2e4a01" => "Account Folders",
                "d42eac7e-705c-4d17-bf6b-28d7fde1fe4f" => "Enquiry Folders",
                "3e4137a6-926b-4859-9e4e-f1d31173abd7" => "Job Folders",
                "26111cac-ce36-453b-ae81-791883ff02bd" => "Property Folders",
                "9a136463-0885-4480-b425-6f034a6930ae" => "Quote Folders",
                "93b83dac-1f4a-4898-8b9f-15f2ebfacd95" => "System Folders",
                _ => ""
            };
            return sharePointSiteName;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to get the SharePoint site name from the GUID.");
            ex.Data.Add("PageMethod", "PWAFunctions/GetSharePointSiteDropDownNameFromGuid()");
            _ = OnError.InvokeAsync(ex);
        }

        return "";
    }

    public static dynamic UnPackGoogleProtoBufTypes(Any ValueType)
    {
        try
        {
            if (ValueType is Any packedValue)
            {
                if (packedValue.Is(StringValue.Descriptor))
                {
                    packedValue.TryUnpack(out StringValue stringValue);
                    return stringValue?.Value ?? "";
                }
                else if (packedValue.Is(Int32Value.Descriptor))
                {
                    packedValue.TryUnpack(out Int32Value intValue);
                    return intValue?.Value ?? 0;
                }
                else if (packedValue.Is(Int64Value.Descriptor))
                {
                    packedValue.TryUnpack(out Int64Value intValue);
                    return intValue?.Value ?? 0;
                }
                else if (packedValue.Is(BoolValue.Descriptor))
                {
                    packedValue.TryUnpack(out BoolValue boolValue);
                    return boolValue?.Value ?? false;
                }
                else if (packedValue.Is(DoubleValue.Descriptor))
                {
                    packedValue.TryUnpack(out DoubleValue doubleValue);
                    return doubleValue?.Value ?? 0.0;
                }
                else if (packedValue.Is(FloatValue.Descriptor))
                {
                    packedValue.TryUnpack(out FloatValue floatValue);
                    return floatValue?.Value ?? 0.0f;
                }
                else if (packedValue.Is(BytesValue.Descriptor))
                {
                    packedValue.TryUnpack(out BytesValue bytesValue);
                    return bytesValue?.Value.ToByteArray() ?? new byte[0];
                }
                else if (packedValue.Is(UInt32Value.Descriptor))
                {
                    packedValue.TryUnpack(out UInt32Value uint32Value);
                    return uint32Value?.Value ?? 0;
                }
                else
                {
                    // Handle unsupported types or fallback to a default value
                    return "Unsupported type";
                }
            }
            else
            {
                return null;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to unpack the Google Protobuf types.");
            ex.Data.Add("PageMethod", "PWAFunctions/UnPackGoogleProtoBufTypes()");
            _ = OnError.InvokeAsync(ex);
        }

        return null;
    }

    public static object GetValueByEntityPropertyGuid(EditPage editPage, string entityPropertyGuid,
        WellKnownType wellKnownType)
    {
        try
        {
            var property = editPage.dataObject.DataProperties.FirstOrDefault(p =>
                p.EntityPropertyGuid == ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(entityPropertyGuid).ToString());

            if (property != null && property.Value is Any packedValue)
                switch (wellKnownType)
                {
                    case WellKnownType.Double:
                        return UnpackDouble(packedValue);

                    case WellKnownType.String:
                        return UnpackString(packedValue);

                    case WellKnownType.Int32:
                        return UnpackInt32(packedValue);

                    case WellKnownType.Int64:
                        return UnpackInt64(packedValue);

                    case WellKnownType.Timestamp:
                        return UnpackTimestamp(packedValue);

                    case WellKnownType.Bool:
                        return UnpackBool(packedValue);

                    default:
                        // Handle other types if needed
                        return null;
                }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to get the value by entity property GUID.");
            ex.Data.Add("PageMethod", "PWAFunctions/GetValueByEntityPropertyGuid()");
            _ = OnError.InvokeAsync(ex);
        }

        // Return a default value or handle the case when the property is not found
        return null;
    }

    // Function to check if a string is a Guid
    public static bool IsGuid(string value)
    {
        Guid result;
        return Guid.TryParse(value, out result);
    }

    // Function to check if a string is a Number
    public static bool IsNumber(string value)
    {
        return double.TryParse(value, out _);
    }

    public static Guid ParseAndReturnEmptyGuidIfInvalid(string inputGuid)
    {
        if (Guid.TryParse(inputGuid, out var parsedGuid))
            return parsedGuid;
        // Return an empty Guid if the inputGuid is not a valid Guid
        return Guid.Empty;
    }

    public static void PrepareStateChanges(EditContext editContext, StateService stateService, string parentRecordGuid)
    {
        try
        {
            dynamic recordItem = editContext.Model; //Guid = recordItem, EntityTypeGuid = EntityTypeGuid,
            if (ParseAndReturnEmptyGuidIfInvalid(stateService.OriginalRecordGuid) == Guid.Empty &&
                ParseAndReturnEmptyGuidIfInvalid(parentRecordGuid) == Guid.Empty)
            {
                stateService.OriginalRecordType = recordItem.EntityTypeGuid;
                stateService.OriginalRecordGuid = recordItem.Guid;
            }
            else if (parentRecordGuid != ParseAndReturnEmptyGuidIfInvalid(stateService.OriginalRecordGuid).ToString())
            {
                stateService.ChildRecordType = recordItem.EntityTypeGuid;
                stateService.ChildRecordGuid = recordItem.Guid;

                //Assign the parent guid to the state service.
                //This ensures that the dropdown actually utilises the correct guid
                //when getting data from the database.
                if (stateService.OriginalRecordGuid == Guid.Empty.ToString())
                {
                    stateService.OriginalRecordGuid = parentRecordGuid;
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to prepare the state changes.");
            ex.Data.Add("PageMethod", "PWAFunctions/PrepareStateChanges()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    public static void ResetStateService(StateService stateService)
    {
        stateService.OriginalRecordItem = Guid.Empty.ToString();
        stateService.OriginalRecordType = Guid.Empty.ToString();
        stateService.OriginalRecordGuid = Guid.Empty.ToString();
        stateService.ChildRecordItem = Guid.Empty.ToString();
        stateService.ChildRecordType = Guid.Empty.ToString();
        stateService.ChildRecordGuid = Guid.Empty.ToString();
    }

    public static string SanitizeFileName(string fileName)
    {
        // Define a regex pattern to match illegal characters
        var pattern = "[\\\\/:*?\"<>|#%]+";

        // Replace illegal characters with an empty string
        var sanitizedFileName = Regex.Replace(fileName, pattern, "");

        // Trim any leading or trailing dots or spaces
        sanitizedFileName = sanitizedFileName.Trim('.', ' ');

        return sanitizedFileName;
    }

    public static void SetDataPropertyValue(string entityPropertyGuid, WellKnownType wellKnownType, object value,
        EditPage editPage)
    {
        try
        {
            var dataProperty = editPage.dataObject.DataProperties.FirstOrDefault(p =>
                p.EntityPropertyGuid == ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(entityPropertyGuid).ToString());
            // Use the WellKnownType enum to determine the type
            if (dataProperty?.Value is not object unpackedValue) return;
            // Sanitize the value
            value = SanitizeValue(value);
            switch (wellKnownType)
            {
                case WellKnownType.Bool:
                    dataProperty.Value = Any.Pack(new BoolValue { Value = (bool)value });
                    break;

                case WellKnownType.Byte:
                    dataProperty.Value = Any.Pack(new UInt32Value { Value = (byte)value });
                    break;

                case WellKnownType.Char:
                    dataProperty.Value = Any.Pack((IMessage)value);
                    break;

                case WellKnownType.DateTime:
                    dataProperty.Value =
                        Any.Pack(Timestamp.FromDateTime(new DateTime(((DateTime)value).Ticks, DateTimeKind.Utc)));
                    break;

                case WellKnownType.Decimal:
                case WellKnownType.Double:
                case WellKnownType.Single:
                    dataProperty.Value = Any.Pack(new DoubleValue { Value = Convert.ToDouble(value) });
                    break;

                case WellKnownType.Int16:
                case WellKnownType.Int32:
                case WellKnownType.Int64:
                    dataProperty.Value = Any.Pack(new Int64Value { Value = Convert.ToInt64(value) });
                    break;

                case WellKnownType.String:
                    dataProperty.Value = Any.Pack((IMessage)value);
                    break;

                case WellKnownType.Object when value is Guid:
                    dataProperty.Value = Any.Pack((IMessage)value);
                    break;

                case WellKnownType.Timestamp:
                default:
                    dataProperty.Value = Any.Pack(new StringValue { Value = "Unknown type" });
                    break;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to set the data property value.");
            ex.Data.Add("PageMethod", "PWAFunctions/SetDataPropertyValue()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    public static async Task SetDropDownListValueAsync(
        string itemGuid,
        string dropDownListDefinitionGuid,
        string parentRecordGuid,
        string recordGuid,
        string listValueToFind,
        EditPage editPage,
        Core.CoreClient CoreClient)
    {
        try
        {
            var DropDownList = editPage.entityProperties.FirstOrDefault(p =>
                p.Guid == ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(itemGuid).ToString());
            if (string.IsNullOrEmpty(listValueToFind)) return;
            if (DropDownList?.DropDownListDefinitionGuid != Guid.Empty.ToString())
            {
                // get available data
                var dropDownDataListReply = await CoreClient.DropDownDataListAsync(new DropDownDataListRequest
                {
                    Guid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dropDownListDefinitionGuid).ToString(),
                    ParentGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(parentRecordGuid).ToString(),
                    RecordGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(recordGuid).ToString()
                });

                // return the formatted list Name, Value
                var comboData = dropDownDataListReply.Items
                    .Select(item => new ComboDataItem(item))
                    .ToList();
                if (comboData?.Count > 0)
                {
                    // return Value in comboData where Name = listValueToFind
                    var retunValue = comboData.FirstOrDefault(p => p.Name == listValueToFind)!.Value;

                    // Convert to WellKnownType
                    StringValue _value = new()
                    { Value = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(retunValue.ToString()).ToString() };

                    // Set the value to be selected
                    SetDataPropertyValue(ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(itemGuid).ToString(),
                        WellKnownType.String, _value, editPage);
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to set the drop-down list value.");
            ex.Data.Add("PageMethod", "PWAFunctions/SetDropDownListValueAsync()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    // Helper method for upserting data object and displaying messages
    public static async Task<(string, DataObject)?> TryUpsertDataObjectAsync(FormHelper formHelper,
        DataObject dataObject, API.Client.MenuItem item, bool validateOnly = false)
    {
        Exception? infoMessage = null;

        try
        {
            var informationMessage = new Exception("Firstly let's save the record...");
            informationMessage.Data.Add("MessageType", ShowMessageType.Information);
            informationMessage.Data.Add("PageMethod", "PWAFunctions/TryUpsertDataObjectAsync()");
            informationMessage.Data.Add("AdditionalInfo", "Trying to upsert the DataObject.. Please wait");
            _ = OnError.InvokeAsync(informationMessage);

            var saveResponse = await formHelper.UpsertDataObject(dataObject, null, validateOnly);
            if (!string.IsNullOrEmpty(saveResponse.Item1)) throw new Exception(saveResponse.Item1);
            dataObject = saveResponse.Item2;

            if (dataObject.ValidationResults.Count > 0)
            {
                infoMessage = GetMessageDisplayFromActionMenuItem(item, infoMessage, ShowMessageType.Error);
                await OnError.InvokeAsync(infoMessage);
                return null;
            }

            return (saveResponse.Item1, dataObject);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to upsert the data object.");
            ex.Data.Add("PageMethod", "PWAFunctions/TryUpsertDataObjectAsync()");
            _ = OnError.InvokeAsync(ex);
            return (ex.Message, dataObject);
        }
    }

    public static bool UnpackBool(Any packedValue)
    {
        return packedValue.Unpack<BoolValue>().Value;
    }

    public static double UnpackDouble(Any packedValue)
    {
        return packedValue.Unpack<DoubleValue>().Value;
    }

    public static int UnpackInt32(Any packedValue)
    {
        return packedValue.Unpack<Int32Value>().Value;
    }

    public static long UnpackInt64(Any packedValue)
    {
        return packedValue.Unpack<Int64Value>().Value;
    }

    public static string UnpackString(Any packedValue)
    {
        return packedValue.Unpack<StringValue>().Value;
    }

    public static DateTime UnpackTimestamp(Any packedValue)
    {
        return packedValue.Unpack<Timestamp>().ToDateTimeOffset().UtcDateTime;
    }

    #endregion Public Methods

    #region Private Methods

    private static string ConvertToCsvDownloadString(string csvContent)
    {
        var bytes = Encoding.UTF8.GetBytes(csvContent);
        return $"data:text/csv;base64,{Convert.ToBase64String(bytes)}";
    }

    // Separate method to sanitize the value
    private static object SanitizeValue(object value)
    {
        // Remove double quotes from the string value
        if (value is string stringValue) return stringValue.Replace("\"", "");

        // Convert Guid to string and remove double quotes
        if (value is Guid guidValue) return guidValue.ToString().Replace("\"", "");

        // For other types, return the original value
        return value;
    }

    public static System.Type DetermineFieldType(string displayFormat)
    {
        if (string.IsNullOrEmpty(displayFormat))
        {
            return typeof(string); // Default to string if no format is specified
        }

        // Check for decimal or numeric types
        //if (displayFormat.Contains("F") || displayFormat.Contains("N"))
        //{
        //    return typeof(decimal); // Use typeof(double) if you prefer
        //}

        if (displayFormat.Equals("F") || displayFormat.Equals("N"))
        {
            return typeof(decimal); // Use typeof(double) if you prefer
        }

        // Check for integer formatting
        if (displayFormat.Equals("D"))
        {
            return typeof(int);
        }

        // Check for currency format
        if (displayFormat.Equals("C"))
        {
            return typeof(decimal);
        }

        // Check for percentage format
        if (displayFormat.Equals("P"))
        {
            return typeof(double); // Percent format is often represented by a double
        }

        // Check for DateTime formats
        if (displayFormat.Equals("dd") || displayFormat.Equals("MM") || displayFormat.Equals("yyyy"))
        {
            return typeof(DateTime);
        }

        // Check for Boolean or yes/no indicators
        if (displayFormat.Equals("{0:Yes;No}", StringComparison.OrdinalIgnoreCase) ||
            displayFormat.Equals("{0:True;False}", StringComparison.OrdinalIgnoreCase))
        {
            return typeof(string);
        }

        return typeof(string); // Default to string if no known format is found
    }

    public static async Task<string> GetStorageUrlAsync(DataObject dataObject, FormHelper formHelper, string sharePointUrl, bool IsBulkUpdate = false, bool UpdateSharePoint = false)
    {
        if (IsBulkUpdate) return sharePointUrl;
        try
        {
            if (!UpdateSharePoint && !string.IsNullOrEmpty(sharePointUrl ?? dataObject?.SharePointUrl))
            {
                // Use existing SharePoint URL if present
                sharePointUrl ??= dataObject?.SharePointUrl ?? "";
                return sharePointUrl;
            }

            // Create SharePoint resource if URL is missing or UpdateSharePoint is true
            var response = await formHelper.SharePointCreate(new SharePointCreateRequest
            {
                DataObject = dataObject,
                DataObjectUpsertRequest = new DataObjectUpsertRequest
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

            // Update data object and URL
            dataObject = response.DataObject;
            sharePointUrl = response.DataObject.SharePointUrl;

            return sharePointUrl;
        }
        catch (Exception ex)
        {
            return "";
        }
    }

    public static async Task StartDownload(IJSRuntime jsRuntime, string downloadUrl, string fileName)
    {
        try
        {
            // Wait for the state to update
            await Task.Delay(1);
            // Trigger the download
            await jsRuntime.InvokeVoidAsync("triggerFileDownload", fileName, downloadUrl);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to start the download.");
            ex.Data.Add("PageMethod", "PWAFunctions/StartDownload()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    public static (DataObjectReference ParentDataObjectReference, string SerializedParentDataObjectReference) ProcessDataObjectReference(ModalService modalService, DataObjectReference ParentDataObjectReference, string parentGuid, string entityTypeGuid)
    {
        DataObjectReference parentDataObjectReference = ParentDataObjectReference;
        string serializedParentDataObjectReference = HttpUtility.UrlEncode(JsonConvert.SerializeObject(parentDataObjectReference ?? new DataObjectReference("", "")));

        try
        {
            if (parentDataObjectReference == null || (parentDataObjectReference.EntityTypeGuid == Guid.Empty && parentDataObjectReference.DataObjectGuid == Guid.Empty))
            {
                try
                {
                    parentDataObjectReference = new DataObjectReference(parentGuid, entityTypeGuid);
                    serializedParentDataObjectReference = HttpUtility.UrlEncode(JsonConvert.SerializeObject(parentDataObjectReference));
                }
                catch (Exception ex)
                {
                    Console.WriteLine(ex);
                }
            }
            //CBLD-462: SB - Check to see if the Entity Guid has changed if so update the parentDataObjectReference
            else if (parentDataObjectReference.EntityTypeGuid.ToString() != entityTypeGuid)
            {
                try
                {
                    parentDataObjectReference = new DataObjectReference(parentGuid, entityTypeGuid);
                    serializedParentDataObjectReference = HttpUtility.UrlEncode(JsonConvert.SerializeObject(parentDataObjectReference));
                }
                catch (Exception ex)
                {
                    Console.WriteLine(ex);
                }
            }
            // Check to see if there are any open modals that match the parentDataObjectReference if
            // so ensure the values are updated correctly
            var listOfModals = modalService.GetOpenModals();
            foreach (var modal in listOfModals)
            {
                if (modal.Value.DataObjectReference.EntityTypeGuid == parentDataObjectReference.EntityTypeGuid && parentDataObjectReference.DataObjectGuid == Guid.Empty)
                {
                    try
                    {
                        parentDataObjectReference = new DataObjectReference(modal.Value.DataObjectReference.DataObjectGuid.ToString(), modal.Value.DataObjectReference.EntityTypeGuid.ToString());
                        serializedParentDataObjectReference = HttpUtility.UrlEncode(JsonConvert.SerializeObject(parentDataObjectReference));
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine(ex);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to process the DataObjectReference.");
            ex.Data.Add("PageMethod", "PWAFunctions/ProcessDataObjectReference()");
            _ = OnError.InvokeAsync(ex);
        }

        return (parentDataObjectReference, serializedParentDataObjectReference);
    }

    public static bool IsFirstGuidEmpty(string input)
    {
        // Regular expression to match a GUID
        var guidRegex = new Regex(@"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", RegexOptions.Compiled);

        // Find the first match in the input string
        var match = guidRegex.Match(input);

        if (match.Success)
        {
            // Parse the matched GUID
            Guid guid = Guid.Parse(match.Value);

            // Check if it's an Empty GUID
            return guid == Guid.Empty;
        }

        // Return false if no GUID is found or if the first GUID is not an Empty GUID
        return false;
    }

    public static void NavigateToNewlyCreatedRecordPage(
    NavigationManager NavManager,
    DataObjectReference myDataObjectReference,
    string returnUrl)
    {
        // Safety: ensure we always have a reference object
        myDataObjectReference ??= new DataObjectReference(string.Empty, string.Empty);

        // This helper is for the “new record from grid/dev” flow. We want to:
        // - Stay on the current detail page (JobDetail / QuoteDetail / DynamicEdit)
        // - Swap in the new Guid
        // - Preserve the original ReturnUrl (grid or /dev) as the encoded tail segment.

        var firstSegment = GetFirstUrlSegment(NavManager.Uri) ?? string.Empty;

        // Serialize the parent reference (same as the old behaviour)
        var serializedParentRef = System.Web.HttpUtility.UrlEncode(
            JsonConvert.SerializeObject(myDataObjectReference));

        // Decode the ReturnUrl once, then extract the LAST https:// if present, so we don’t
        // accumulate nested URLs.
        var decodedReturnUrl = System.Web.HttpUtility.UrlDecode(returnUrl) ?? string.Empty;
        var flattened = ExtractLastHttps(decodedReturnUrl);

        if (string.IsNullOrWhiteSpace(flattened))
        {
            flattened = decodedReturnUrl;
        }

        var encodedReturnUrl = System.Web.HttpUtility.UrlEncode(flattened);

        string newUrl;

        if (firstSegment.Equals("DynamicEdit", StringComparison.OrdinalIgnoreCase))
        {
            // DynamicEdit has the {EntityTypeGuid}/{DataObjectGuid}/ pattern
            newUrl = $"{firstSegment}/" +
                     $"{myDataObjectReference.EntityTypeGuid}/" +
                     $"{myDataObjectReference.DataObjectGuid}/" +
                     $"{serializedParentRef}/" +
                     $"{encodedReturnUrl}";
        }
        else
        {
            // Standard detail pages: JobDetail / QuoteDetail / etc.
            newUrl = $"{firstSegment}/" +
                     $"{myDataObjectReference.DataObjectGuid}/" +
                     $"{serializedParentRef}/" +
                     $"{encodedReturnUrl}";
        }

        NavManager.NavigateTo(newUrl, forceLoad: false);
    }

    public static void NavigateToCorrectPage(
    NavigationManager NavManager,
    DataObjectReference MyDataObjectReference,
    string ReturnUrl,
    bool IsWindowed)
    {
        // If we have a ReturnUrl, use it as the source of truth.
        if (!string.IsNullOrWhiteSpace(ReturnUrl))
        {
            // 1) Decode once (it came from a route segment)
            var decoded = System.Web.HttpUtility.UrlDecode(ReturnUrl) ?? string.Empty;

            // 2) Extract the LAST https://... in case there is any wrapper noise Example:
            // - B's ReturnUrl = encoded(Job A URL with encoded grid inside)
            // - A's ReturnUrl = encoded(grid URL) In both cases ExtractLastHttps gives the correct target.
            var target = ExtractLastHttps(decoded);

            if (string.IsNullOrWhiteSpace(target))
            {
                // If ExtractLastHttps finds nothing, just use the decoded string as-is.
                target = decoded;
            }

            NavManager.NavigateTo(target, forceLoad: false);
            return;
        }

        // From here down is only used when ReturnUrl is *empty*. We keep a minimal, safe fallback
        // so existing code doesn't blow up.

        var firstSegment = GetFirstUrlSegment(NavManager.Uri) ?? string.Empty;

        // No ReturnUrl and we're in a window? Best fallback is just home.
        if (IsWindowed)
        {
            NavManager.NavigateTo(NavManager.BaseUri, forceLoad: false);
            return;
        }

        // If we don't know where to go, also fall back to home.
        if (MyDataObjectReference == null || string.IsNullOrWhiteSpace(firstSegment))
        {
            NavManager.NavigateTo(NavManager.BaseUri, forceLoad: false);
            return;
        }

        // Fallback: rebuild the detail page URL from the current segment + object reference.
        string serializeParentDataObjectReferenced =
            System.Web.HttpUtility.UrlEncode(
                JsonConvert.SerializeObject(MyDataObjectReference));

        if (firstSegment.Equals("DynamicEdit", StringComparison.OrdinalIgnoreCase))
        {
            var newUrl = $"{firstSegment}/" +
                         $"{MyDataObjectReference.EntityTypeGuid}/" +
                         $"{MyDataObjectReference.DataObjectGuid}/" +
                         $"{serializeParentDataObjectReferenced}/";

            NavManager.NavigateTo(newUrl, forceLoad: false);
        }
        else
        {
            var newUrl = $"{firstSegment}/" +
                         $"{MyDataObjectReference.DataObjectGuid}/" +
                         $"{serializeParentDataObjectReferenced}/";

            NavManager.NavigateTo(newUrl, forceLoad: false);
        }
    }

    public static string ExtractLastHttps(string input)
    {
        // Find the last occurrence of "https://"
        int lastIndex = input.LastIndexOf("https://");

        // If "https://" is not found, return the input string as-is
        if (lastIndex == -1)
        {
            return input;
        }

        // Extract the substring from the last occurrence of "https://" to the end
        string extracted = input.Substring(lastIndex);

        return extracted;
    }

    public static string GetRecordGuidFromReturnUrl(string returnUrl)
    {
        // Regular expression to match a GUID
        var guidRegex = new Regex(@"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", RegexOptions.Compiled);

        // Find all GUID matches in the string
        var matches = guidRegex.Matches(returnUrl);

        // Return the first GUID if found
        if (matches.Count > 0)
        {
            return matches[0].Value;
        }

        // Return empty string if no GUIDs are found
        return string.Empty;
    }

    public static string GetEntityTypeGuidFromReturnUrl(string returnUrl)
    {
        // Regular expression to match GUIDs and look for "EntityTypeGuid" key
        var guidRegex = new Regex(@"EntityTypeGuid.*?([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})", RegexOptions.Compiled);

        // Find the GUID that comes after "EntityTypeGuid"
        var match = guidRegex.Match(returnUrl);

        if (match.Success && match.Groups.Count > 1)
        {
            return match.Groups[1].Value;
        }

        // Return empty string if no match is found
        return string.Empty;
    }

    #endregion Private Methods
}