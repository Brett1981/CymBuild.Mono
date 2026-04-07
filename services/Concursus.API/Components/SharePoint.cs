using Concursus.API.Classes;
using Concursus.API.Core;
using Concursus.API.Interfaces;
using Concursus.API.Services;
using Concursus.API.Types;
using Concursus.Common.Shared.Helpers;
using Concursus.EF.Types;
using Google.Api.Gax.ResourceNames;
using Google.Protobuf;
using Google.Protobuf.WellKnownTypes;
using Microsoft.Graph;
using Microsoft.Graph.DirectoryObjects.GetByIds;
using Microsoft.Graph.Drives.Item.Items.Item.CreateLink;
using Microsoft.Graph.Drives.Item.Items.Item.Invite;
using Microsoft.Graph.Models;
using Microsoft.Graph.Models.ODataErrors;
using Microsoft.Graph.Shares.Item.Permission.Grant;
using Polly;
using System.Net.Mime;
using DataObject = Concursus.EF.Types.DataObject;
using DataObjectUpsertResponse = Concursus.EF.Types.DataObjectUpsertResponse;

using DriveItem = Microsoft.Graph.Models.DriveItem;
using ObjectSecurity = Concursus.EF.Types.ObjectSecurity;
using OrganisationalUnitEnum = Concursus.Common.Shared.Enums.OrganisationalUnits;

namespace Concursus.API.Components;

public class SharePoint : MSGraphBase, IDisposable
{
    #region Private Fields

    // Define supported photo file extensions using HashSet for faster lookups
    private static readonly HashSet<string> photoFileExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".gif", ".tiff", ".tif",
        ".bmp", ".svg", ".webp", ".heic", ".heif",
        ".raw", ".cr2", ".nef", ".arw", ".dng",
        ".ico", ".jfif"
    };

    private readonly GraphServiceClient graphClient;
    private bool _disposed;
    private MainError mainError;
    private readonly ISharepointService sharepointService;

    #endregion Private Fields

    #region Public Constructors

    public SharePoint(IConfiguration configuration, ISharepointService _sharepointService) : base(configuration)
    {
        sharepointService = _sharepointService;
    }

    #endregion Public Constructors

    #region Private Properties

    private Drive? drive { get; set; }

    #endregion Private Properties

    #region Public Methods

    public async Task<int> CheckForPhotosAsync(string sharePointUrl)
    {
        try
        {
            if (string.IsNullOrEmpty(sharePointUrl))
            {
                Console.Error.WriteLine("SharePoint URL is required.");
                return 0;
            }
            var SiteId = "";
            var _AppConfig = new AppConfiguration(_config);
            switch (_AppConfig.EnvironmentType)
            {
                case "DEV":
                    SiteId = _AppConfig.DevSharepointIdentifier;
                    break;

                case "TEST":
                    SiteId = _AppConfig.DevSharepointIdentifier;
                    break;

                default:
                    SiteId = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";
                    break;
            }

            var result = Functions.ExtractLastFourSegmentsFromUrl(sharePointUrl);
            var parentFolder = result.Item1;
            var mainFolder = result.Item2;
            var subfolder = result.Item3;
            var subsubfolder = result.Item4;

            // Construct the relative path without including the parentFolder twice
            var relativePath = $"{mainFolder}/{subfolder}/{subsubfolder}";

            Console.WriteLine($"Relative Path: {relativePath}");
            // Get the SharePoint drives
            var drives = await _graphServiceClient.Sites[SiteId].Drives.GetAsync();

            // Assume the drive ID is the one associated with the first drive
            var driveItem = drives.Value.FirstOrDefault(d => d.Name == parentFolder);
            Console.WriteLine($"Drive ID: {driveItem?.Id}");

            if (driveItem != null)
            {
                // Fetch folder contents
                var folderContents = await _graphServiceClient
                    .Drives[driveItem.Id]
                    .Root
                    .ItemWithPath($"{relativePath}")
                    .Children
                    .GetAsync();

                // Check if folderContents or Value is null
                if (folderContents?.Value == null)
                {
                    return 0; // Return 0 if there are no items or the folder couldn't be accessed
                }

                // Count the items with photo file extensions, ensuring each item is not null
                var photoFileCount = folderContents.Value
                    .Count(item => item != null && photoFileExtensions.Contains(Path.GetExtension(item?.Name ?? string.Empty)));

                return photoFileCount;
            }
            else
            {
                Console.WriteLine($"Drive not found for parent folder: {parentFolder}");
                return 0;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error checking for photos at {sharePointUrl}: {ex.Message}");
            throw;
        }
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    public async Task<List<DriveListItem>> GetSharePointDocumentDetails(string siteId, string folderName,
        string TemplateFolderName)
    {
        List<DriveListItem> documents = new();

        try
        {
            var parentDrive = await _graphServiceClient
                .Sites[siteId]
                .Drive
                .GetAsync(
                    requestConfiguration =>
                    {
                        requestConfiguration.QueryParameters.Expand = new[] { "list($select=id)" };
                    }
                );

            //Get the root folder from parent above to obtain the Items driveItem.Id
            var getRouteFolderFromParent = await _graphServiceClient
                                               .Drives[parentDrive.Id]
                                               .Root
                                               .GetAsync()
                                           ?? throw new Exception("Failed to obtain root folder.");

            if (getRouteFolderFromParent?.Folder?.ChildCount == 0)
            {
                //If no items create default Folder Form Templates
                var requestBody = new DriveItem
                {
                    Name = folderName,
                    Folder = new Folder()
                    //AdditionalData = new Dictionary<string, object>
                    //{
                    //    {
                    //        "@microsoft.graph.conflictBehavior" , "rename"
                    //    },
                    //},
                };

                var result = await _graphServiceClient.Drives[parentDrive.Id].Items[getRouteFolderFromParent.Id]
                    .Children.PostAsync(requestBody);
                var userEmail = "stephen.brett@socotec.co.uk";

                var request_Body = new InvitePostRequestBody
                {
                    Recipients = new List<DriveRecipient>
                    {
                        new()
                        {
                            Email = userEmail
                        }
                    },
                    RequireSignIn = true,
                    Roles = new List<string>
                    {
                        "write"
                    }
                };
                try
                {
                    // Using the newer PostAsInvitePostResponseAsync method
                    var folderPermissionsResult = await _graphServiceClient
                        .Drives[parentDrive.Id]
                        .Items[result.Id]
                        .Invite
                        .PostAsInvitePostResponseAsync(request_Body);

                    Console.WriteLine("Folder permissions set successfully.");
                }
                catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
                {
                    Console.Error.WriteLine($"OData Error (Invite): {odataError.Error?.Message ?? "Unknown error"}");
                    throw;
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
                    throw;
                }
            }
            else
            {
                var rootFolder = await _graphServiceClient
                                     .Drives[parentDrive.Id]
                                     .Root
                                     .GetAsync()
                                 ?? throw new Exception("Failed to obtain root folder.");
                //get the FormTemplates Folder
                var itemCollection = await _graphServiceClient
                    .Drives[parentDrive.Id]
                    .Items[rootFolder.Id]
                    .Children
                    .GetAsync(
                    //requestConfig =>
                    //{
                    //    requestConfig.QueryParameters.Filter = $"(name eq '{folderNumber}')";
                    //}
                    );

                if (itemCollection != null)
                {
                    foreach (var item in itemCollection.Value)
                    {
                        if (item.Name == "Form Templates")
                        {
                            var subfolderId = item.Id ?? "";
                            var subItemCollection = await _graphServiceClient
                                .Drives[parentDrive.Id]
                                .Items[subfolderId]
                                .Children
                                .GetAsync(
                                );
                            if (subItemCollection != null)
                            {
                                // Find the item with the specified Name
                                var jobFoldersItem =
                                    subItemCollection.Value.FirstOrDefault(item => item.Name == TemplateFolderName);

                                // Check if the item was found
                                if (jobFoldersItem != null)
                                {
                                    var subFolderResponse = await _graphServiceClient.Drives[parentDrive.Id]
                                        .Items[jobFoldersItem.Id].Children
                                        .GetAsync(
                                        );
                                    // Iterate through files in the "Job Folders" subfolder
                                    var _pageIterator = PageIterator<DriveItem, DriveItemCollectionResponse>
                                        .CreatePageIterator(
                                            _graphServiceClient,
                                            subFolderResponse,
                                            driveItem =>
                                            {
                                                // Check if it's a file before adding to the list
                                                if (driveItem.File != null)
                                                    documents.Add(new DriveListItem
                                                    {
                                                        Id = driveItem.Id ?? "",
                                                        Name = driveItem.Name ?? "",
                                                        WebUrl = driveItem.WebUrl ?? "",
                                                        CreatedDateTime =
                                                            Timestamp.FromDateTimeOffset(
                                                                (DateTimeOffset)driveItem.CreatedDateTime),
                                                        LastModifiedDateTime =
                                                            Timestamp.FromDateTimeOffset(
                                                                (DateTimeOffset)driveItem.LastModifiedDateTime),
                                                        Size = driveItem.Size ?? 0
                                                    });
                                                return true;
                                            });

                                    await _pageIterator.IterateAsync();

                                    // Now 'documents' contains information about each file in the
                                    // "Job Folders" subfolder You can further process or use this
                                    // list as needed
                                }
                                // The item with Name "Job Folders" was not found Handle accordingly
                            }
                        }
                    }
                }
            }
        }
        catch (ODataError odataError)
        {
            // Create a new DriveListItem object
            var driveItem = new DriveListItem
            {
                // Set the error message
                ErrorReturned = odataError.Error.Message
            };
            return new List<DriveListItem> { driveItem };
        }

        return documents;
    }

    public async Task<SharepointDocumentsGetResponse> GetSharePointDocumentsWithMergeDocument(EF.Core efCore, string RecordGuid, string siteId,
        string filenameTemplate, string sharePointUrl, string documentId, List<Dictionary<string, string>> mergeData,
        Core.MergeDocument mergeDocument, string outputType = "Word", int userId = -1, bool isIncludedDocument = false, ServiceBase? serviceBase = null,
        string RecordTypeGuid = "00000000-0000-0000-0000-000000000000")
    {
        var sharepointDocumentsGetResponse = new SharepointDocumentsGetResponse();
        try
        {
            var parentDrive = await _graphServiceClient
                .Sites[siteId]
                .Drive
                .GetAsync(
                    requestConfiguration => { requestConfiguration.QueryParameters.Expand = ["list($select=id)"]; }
                );

            if (parentDrive != null)
            {
                //Perform MailMerge
                var wordDocumentService = new WordDocumentService(_graphServiceClient);
                var response = await wordDocumentService.DownloadAndModifyDocumentWithMergeDocument(efCore, RecordGuid, siteId, parentDrive.Id, filenameTemplate,
                    sharePointUrl, documentId, mergeData, _config, mergeDocument, outputType, userId, isIncludedDocument, serviceBase, RecordTypeGuid);

                //ToDo: we might need to store these results in another Memorystream to place the Included Documents in the main document.
                return response;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error processing DownloadAndModifyDocumentWithMergeDocument {sharePointUrl}: {ex.Message}");
            sharepointDocumentsGetResponse.ErrorReturned = ex.Message;
            return sharepointDocumentsGetResponse;
        }

        return sharepointDocumentsGetResponse;
    }

    public async Task<SharepointDocumentsGetResponse> GetSharePointDocumentsWithMergeDocumentExcel(
    EF.Core efCore,
    string RecordGuid,
    string siteId,
    string filenameTemplate,
    string sharePointUrl,
    string documentId,
    List<Dictionary<string, string>> mergeData,
    Core.MergeDocument mergeDocument,
    string outputType = "Excel",
    int userId = -1,
    bool isIncludedDocument = false,
    ServiceBase? serviceBase = null,
    string RecordTypeGuid = "00000000-0000-0000-0000-000000000000")
    {
        var sharepointDocumentsGetResponse = new SharepointDocumentsGetResponse();
        try
        {
            // Retrieve the parent drive from SharePoint.
            var parentDrive = await _graphServiceClient
                .Sites[siteId]
                .Drive
                .GetAsync(requestConfiguration =>
                {
                    requestConfiguration.QueryParameters.Expand = new string[] { "list($select=id)" };
                });

            if (parentDrive != null)
            {
                // Instantiate the ExcelDocumentService.
                var excelDocumentService = new ExcelDocumentService(_graphServiceClient);

                // Call the Excel service to download, process merge data, and upload the modified
                // Excel file.
                // Note: We now pass siteId as the first parameter, followed by the driveId (from parentDrive.Id)
                var response = await excelDocumentService.DownloadAndModifyExcelDocumentWithMergeData(
                    siteId,
                    parentDrive.Id,
                    documentId,
                    mergeData,
                    _config,
                    sharePointUrl,
                    filenameTemplate);

                return response;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error processing DownloadAndModifyExcelDocumentWithMergeData {sharePointUrl}: {ex.Message}");
            sharepointDocumentsGetResponse.ErrorReturned = ex.Message;
            return sharepointDocumentsGetResponse;
        }

        return sharepointDocumentsGetResponse;
    }

    //CBLD-405: Added param organisationUnit
    public async Task<DataObjectUpsertResponse> GetSharePointLocation(string EntityTypeGuid, DataObject dataObject,
        EF.Core _efCore, ServiceBase serviceBase, Core.DataObjectUpsertRequest? request = null, API.Core.OrganisationalUnit? organisationalUnit = null)
    {
        var siteUrl = "";
        var siteId = "";
        var useLibraryPerSplit = false;
        var primaryKeySplitInterval = 0;
        var name = "";
        var parentUseLibraryPerSplit = false;
        var parentPrimaryKeySplitInterval = 0;
        var parentName = "";
        var parentStructureId = -1;
        var quoteId = "";
        var quoteURL = "";
        long parentObjectId = -1;

        var _ListOfSharepointDetail = await _efCore.GetSharePointDetailsForObject(dataObject);
        //if (_ListOfSharepointDetail.Count == 0) SharePointDocumentDetailsGet;
        if (_ListOfSharepointDetail.Count == 0) return new DataObjectUpsertResponse { DataObject = dataObject };
        drive = new Drive();
        DriveItem folder;

        var Quotedrive = new Drive();
        DriveItem Quotefolder = new DriveItem();
        //Find the value of the dataObject.DataProperties where the EntityPropertyGuid = "b5d2e1d9-6133-4ab2-b28a-827ab24103cf"
        //if found return the first result and unpack the value into the quoteId
        var result = dataObject.DataProperties.Where(d =>
                d.EntityPropertyGuid ==
                Functions.ParseAndReturnEmptyGuidIfInvalid("b5d2e1d9-6133-4ab2-b28a-827ab24103cf"))
            .FirstOrDefault();

        if (result != null)
        {
            quoteId = result.Value.Unpack<StringValue>().ToString(); //Guid of the Quote - we should be able to get the number and link from here onwards.
        }
        var _AppConfig = new AppConfiguration(_config);

        foreach (var sharePointDetail in _ListOfSharepointDetail)
        {
            switch (_AppConfig.EnvironmentType)
            {
                case "DEV":
                    siteId = _AppConfig.DevSharepointIdentifier;
                    break;

                case "TEST":
                    siteId = _AppConfig.DevSharepointIdentifier;
                    break;

                default:
                    siteId = sharePointDetail.SiteIdentifier;
                    break;
            }
            useLibraryPerSplit = sharePointDetail.UseLibraryPerSplit;
            primaryKeySplitInterval = sharePointDetail.PrimaryKeySplitInterval;
            name = sharePointDetail.Name;
            parentUseLibraryPerSplit = sharePointDetail.ParentUseLibraryPerSplit;
            parentPrimaryKeySplitInterval = sharePointDetail.ParentPrimaryKeySplitInterval;
            parentName = sharePointDetail.ParentName;
            parentStructureId = sharePointDetail.ParentStructureId;
            parentObjectId = sharePointDetail.ParentObjectId;

            if (siteId != "")//&& dataObject.SharePointSiteIdentifier == "")
            {
                if (parentStructureId > -1)
                    drive = await GetCreateLibrary(siteId, parentUseLibraryPerSplit, parentObjectId,
                        parentPrimaryKeySplitInterval, dataObject, sharePointDetail);
                else if (parentStructureId == -1 && useLibraryPerSplit)
                    drive = await GetCreateLibrary(siteId, useLibraryPerSplit, dataObject.DatabaseId,
                        primaryKeySplitInterval, dataObject, sharePointDetail);
                else
                    drive = await _graphServiceClient
                        .Sites[siteId]
                        .Drive
                        .GetAsync(
                            requestConfiguration =>
                            {
                                requestConfiguration.QueryParameters.Expand = new[] { "list($select=id)" };
                            });
            }

            if (dataObject.SharePointSiteIdentifier != "")
            {
                //Check for dev site and set siteId to the dev site
                switch (_AppConfig.EnvironmentType)
                {
                    case "DEV":
                        dataObject.SharePointSiteIdentifier = _AppConfig.DevSharepointIdentifier;
                        break;

                    case "TEST":
                        dataObject.SharePointSiteIdentifier = _AppConfig.DevSharepointIdentifier;
                        break;

                    default:
                        dataObject.SharePointSiteIdentifier = dataObject.SharePointSiteIdentifier;
                        break;
                }
                siteId = dataObject.SharePointSiteIdentifier;
                var NewFolderStructure = Functions.GetSeparatedNumberValues(dataObject.SharePointFolderPath);
                drive = await GetCreateLibrary(siteId, useLibraryPerSplit, NewFolderStructure,
                    primaryKeySplitInterval, drive);

                if (drive != null)
                {
                    if (parentStructureId > -1)
                    {
                        folder = await GetCreateFolder(siteId, dataObject.Label, parentObjectId,
                        parentStructureId > -1 ? primaryKeySplitInterval : 0, drive, dataObject, sharePointDetail);
                    }
                    else
                    {
                        folder = await GetCreateFolder(siteId, dataObject.Label, Convert.ToInt64(NewFolderStructure[1]),
                                                parentStructureId > -1 ? primaryKeySplitInterval : 0, drive);
                    }

                    dataObject.SharePointUrl = folder.WebUrl ?? "";
                    if (!string.IsNullOrEmpty(dataObject.SharePointUrl))
                    {
                        var response = await Functions.PrepareUpdateToEfDataObjectSharePoint(
                            dataObject,
                            _efCore,
                            siteId,
                            dataObject.SharePointUrl,
                            Functions.ParseAndReturnEmptyGuidIfInvalid(request?.EntityQueryGuid).ToString(),
                            request?.ValidateOnly);

                        response.DataObject.SharePointUrl = dataObject.SharePointUrl;
                        dataObject = response.DataObject;

                        SetSharePointPermission(siteId, dataObject, drive.Id, folder.Id ?? "");

                        await EnsureRecordFolderStructureAsync(
                                dataObject,
                                _efCore,
                                siteId,
                                drive,
                                folder,
                                organisationalUnit,
                                quoteId,
                                quoteURL)
                            .ConfigureAwait(false);

                        return response;
                    }
                }
            }
            else
            {
                if (drive != null)
                {
                    folder = await GetCreateFolder(siteId, dataObject.Label, dataObject.DatabaseId,
                        parentStructureId > -1 ? primaryKeySplitInterval : 0, drive, dataObject, sharePointDetail);

                    //// After creating or retrieving the folder
                    //if (folder != null && folder.WebUrl != null)
                    //{
                    //    // Step 1: Get the ListItem associated with the folder to retrieve ContentType
                    //    var listItem = await _graphServiceClient
                    //        .Drives[dataObject.DatabaseId]
                    //        .Items[folder.Id]
                    //        .ListItem
                    //        .GetAsync();

                    // // Step 2: Extract the FolderCTID if it exists string? folderCTID = listItem?.ContentType?.Id;

                    // if (string.IsNullOrEmpty(folderCTID)) { throw new Exception("Failed to
                    // retrieve FolderCTID for the specified folder."); }

                    // // Step 3: Extract the folder path from the folder's WebUrl string folderPath
                    // = folder.WebUrl.Split(new[] { "/sites/" }, StringSplitOptions.None)[1];

                    // // Step 4: Build the full navigation URL with the dynamically obtained
                    // FolderCTID string navigationUrl = $"{sharepointBaseUrl}/62/Forms/AllItems.aspx?FolderCTID={folderCTID}&id=%2Fsites%2F{Uri.EscapeDataString(folderPath)}";

                    //    // Step 5: Set the SharePoint URL with the navigation format
                    //    dataObject.SharePointUrl = navigationUrl;
                    //}

                    dataObject.SharePointUrl = folder.WebUrl ?? "";
                    if (!string.IsNullOrEmpty(dataObject.SharePointUrl))
                    {
                        var response = await Functions.PrepareUpdateToEfDataObjectSharePoint(
                            dataObject,
                            _efCore,
                            siteId,
                            dataObject.SharePointUrl,
                            Functions.ParseAndReturnEmptyGuidIfInvalid(request?.EntityQueryGuid).ToString(),
                            request?.ValidateOnly);

                        response.DataObject.SharePointUrl = dataObject.SharePointUrl;
                        dataObject = response.DataObject;

                        SetSharePointPermission(siteId, dataObject, drive.Id, folder.Id ?? "");

                        await EnsureRecordFolderStructureAsync(
                                dataObject,
                                _efCore,
                                siteId,
                                drive,
                                folder,
                                organisationalUnit,
                                quoteId,
                                quoteURL)
                            .ConfigureAwait(false);

                        return response;
                    }
                }
            }
        }

        return new DataObjectUpsertResponse() { DataObject = dataObject };
    }

    private static readonly Guid JobEntityTypeGuid =
    Guid.Parse("63542427-46ab-4078-abd1-1d583c24315c");

    private static readonly Guid QuoteEntityTypeGuid =
        Guid.Parse("1c4794c1-f956-4c32-b886-5500ac778a56");

    private static readonly Guid EnquiryEntityTypeGuid =
        Guid.Parse("3b4f2df9-b6cf-4a49-9eed-2206473867a1");

    private async Task EnsureRecordFolderStructureAsync(
    DataObject dataObject,
    EF.Core efCore,
    string siteId,
    Drive drive,
    DriveItem folder,
    API.Core.OrganisationalUnit? organisationalUnit,
    string quoteId,
    string quoteUrl)
    {
        if (dataObject == null) throw new ArgumentNullException(nameof(dataObject));
        if (efCore == null) throw new ArgumentNullException(nameof(efCore));
        if (drive == null) throw new ArgumentNullException(nameof(drive));
        if (folder == null) throw new ArgumentNullException(nameof(folder));

        if (dataObject.EntityTypeGuid == JobEntityTypeGuid)
        {
            var effectiveOrganisationalUnitGuid = ResolveJobOrganisationalUnitGuid(dataObject, organisationalUnit);

            var directory = BuildJobSharepointDirectory(effectiveOrganisationalUnitGuid);

            var resolvedQuoteLink = await ResolveQuoteLinkForJobAsync(
                    efCore,
                    quoteId,
                    quoteUrl)
                .ConfigureAwait(false);

            await sharepointService.EnsureFolderStructureExists(
                    _graphServiceClient,
                    siteId,
                    dataObject.SharePointUrl,
                    directory.FolderNames,
                    drive,
                    folder,
                    dataObject.Label,
                    resolvedQuoteLink.LinkNumber,
                    resolvedQuoteLink.LinkUrl,
                    false,
                    directory.SubFoldersToCreate)
                .ConfigureAwait(false);

            return;
        }

        if (dataObject.EntityTypeGuid == QuoteEntityTypeGuid)
        {
            var enquiryGuid = GetStringPropertyValue(
                dataObject,
                "9b2655e2-4696-4b1e-9013-da6afe6cb728");

            var enquiryNumber = string.Empty;
            var enquirySharePointUrl = string.Empty;

            // IMPORTANT: Quote uses its own OU only
            var effectiveOrganisationalUnitGuid = ResolveQuoteOrganisationalUnitGuid(dataObject, organisationalUnit);

            if (!string.IsNullOrWhiteSpace(enquiryGuid))
            {
                var enquiry = await efCore.DataObjectGet(
                        Functions.ParseAndReturnEmptyGuidIfInvalid(enquiryGuid),
                        Guid.Empty,
                        EnquiryEntityTypeGuid,
                        false)
                    .ConfigureAwait(false);

                if (enquiry != null && enquiry.Guid != Guid.Empty)
                {
                    enquiryNumber = enquiry.Label ?? string.Empty;
                    enquirySharePointUrl = enquiry.SharePointUrl ?? string.Empty;
                }
            }

            var directory = BuildQuoteSharepointDirectory(effectiveOrganisationalUnitGuid);

            await sharepointService.EnsureFolderStructureExists(
                    _graphServiceClient,
                    siteId,
                    dataObject.SharePointUrl,
                    directory.FolderNames,
                    drive,
                    folder,
                    dataObject.Label,
                    enquiryNumber,
                    enquirySharePointUrl,
                    true,
                    directory.SubFoldersToCreate)
                .ConfigureAwait(false);

            return;
        }

        if (dataObject.EntityTypeGuid == EnquiryEntityTypeGuid)
        {
            var effectiveOrganisationalUnitGuid = ResolveEnquiryOrganisationalUnitGuid(dataObject, organisationalUnit);

            var directory = BuildEnquirySharepointDirectory(effectiveOrganisationalUnitGuid);

            await sharepointService.EnsureFolderStructureExists(
                    _graphServiceClient,
                    siteId,
                    dataObject.SharePointUrl,
                    directory.FolderNames,
                    drive,
                    folder,
                    dataObject.Label,
                    string.Empty,
                    string.Empty,
                    true,
                    directory.SubFoldersToCreate)
                .ConfigureAwait(false);

            return;
        }

        await sharepointService.EnsureFolderStructureExists(
                _graphServiceClient,
                siteId,
                dataObject.SharePointUrl,
                new List<string>(),
                drive,
                folder,
                dataObject.Label,
                string.Empty,
                string.Empty,
                false,
                new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase))
            .ConfigureAwait(false);
    }

    private string ResolveJobOrganisationalUnitGuid(
    DataObject dataObject,
    API.Core.OrganisationalUnit? organisationalUnit)
    {
        if (organisationalUnit != null && !string.IsNullOrWhiteSpace(organisationalUnit.Guid))
        {
            return organisationalUnit.Guid;
        }

        return GetStringPropertyValue(
            dataObject,
            "01a848d9-15b6-486c-8e6d-08e891dfbe30");
    }

    private string ResolveEnquiryOrganisationalUnitGuid(
    DataObject dataObject,
    API.Core.OrganisationalUnit? organisationalUnit)
    {
        if (organisationalUnit != null && !string.IsNullOrWhiteSpace(organisationalUnit.Guid))
        {
            return organisationalUnit.Guid;
        }

        return GetStringPropertyValue(
            dataObject,
            "1c4b6562-a512-4fc9-85ee-f6a2193ebece");
    }

    private async Task<(string LinkNumber, string LinkUrl)> ResolveQuoteLinkForJobAsync(
    EF.Core efCore,
    string quoteId,
    string quoteUrl)
    {
        // If already supplied → use it
        if (!string.IsNullOrWhiteSpace(quoteId) && !string.IsNullOrWhiteSpace(quoteUrl))
        {
            return (quoteId, quoteUrl);
        }

        // If no quote info provided → nothing to link
        if (string.IsNullOrWhiteSpace(quoteId))
        {
            return (string.Empty, string.Empty);
        }

        try
        {
            var quoteGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(quoteId);

            if (quoteGuid == Guid.Empty)
            {
                return (string.Empty, string.Empty);
            }

            var quote = await efCore.DataObjectGet(
                    quoteGuid,
                    Guid.Empty,
                    QuoteEntityTypeGuid,
                    false)
                .ConfigureAwait(false);

            if (quote == null || quote.Guid == Guid.Empty)
            {
                return (string.Empty, string.Empty);
            }

            return (
                quote.Label ?? string.Empty,
                quote.SharePointUrl ?? string.Empty
            );
        }
        catch
        {
            // Fail safe — never break SharePoint creation because of link resolution
            return (string.Empty, string.Empty);
        }
    }
    private static bool HasResolvedOrganisationalUnit(API.Core.OrganisationalUnit? organisationalUnit)
    {
        return organisationalUnit != null &&
               !string.IsNullOrWhiteSpace(organisationalUnit.Guid);
    }

    private SharepointDirectory BuildJobSharepointDirectory(string? organisationalUnitGuid)
    {
        var defaultFolderStruct = new List<string>
    {
        "Admin",
        "Certs",
        "Design Information",
        "Design Risk",
        "Emails",
        "Finance",
        "Photos",
        "Reports"
    };

        var subFoldersToCreate = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);

        if (string.IsNullOrWhiteSpace(organisationalUnitGuid))
        {
            return new SharepointDirectory
            {
                FolderNames = defaultFolderStruct,
                SubFoldersToCreate = subFoldersToCreate
            };
        }

        try
        {
            switch (OrganisationalUnitHelper.GetById(organisationalUnitGuid.ToUpperInvariant()))
            {
                case OrganisationalUnitEnum.CDM:
                    subFoldersToCreate["Reports"] = new List<string> { "CPP", "PCI", "OMHS" };
                    return new SharepointDirectory
                    {
                        FolderNames = defaultFolderStruct,
                        SubFoldersToCreate = subFoldersToCreate
                    };

                case OrganisationalUnitEnum.BuildingControl:
                    subFoldersToCreate["Reports"] = new List<string> { "CPP", "PCI", "OMHS" };

                    subFoldersToCreate["Design Information"] = new List<string>
                {
                    "0-0 Reports & Specifications",
                    "1-0 Sub-structure & Groundworks",
                    "2-0 Superstructure & Façade",
                    "3-0 Mechanical, Electrical and Public Health",
                    "4-0 Landscaping and Civil Engineering",
                    "X-0 General"
                };

                    subFoldersToCreate["Design Information/0-0 Reports & Specifications"] = new List<string>
                {
                    "0-1 Geotechnical",
                    "0-2 Structures",
                    "0-3 Façade",
                    "0-4 Architectural",
                    "0-5 Mechanical, Electrical & Public Health",
                    "0-6 Fire & Specialist Smoke Control",
                    "0-7 Acoustics",
                    "0-8 Air Quality"
                };

                    subFoldersToCreate["Design Information/1-0 Sub-structure & Groundworks"] = new List<string>
                {
                    "1-1 Ground Investigation, Earthworks and Remediation",
                    "1-2 Piling",
                    "1-3 Sub-structure",
                    "1-4 Below Ground Drainage and Services"
                };

                    subFoldersToCreate["Design Information/2-0 Superstructure & Façade"] = new List<string>
                {
                    "2-1 Plans, Sections & Elevations",
                    "2-2 Concrete Frame",
                    "2-3 Roof Coverings",
                    "2-4 Specialist Roof Systems",
                    "2-5 Rooflights, AOV & Access Hatches",
                    "2-6 Stairs and Balustrades",
                    "2-7 Lifts",
                    "2-8 External Walls",
                    "2-9 SFS",
                    "2-10 Balcony",
                    "2-11 Metal Cladding - Curtain Walling",
                    "2-12 External Windows",
                    "2-13 External Doors & Louvres",
                    "2-14 Internal Wall, Floor and Ceiling",
                    "2-15 Internal Doors",
                    "2-16 Bathroom",
                    "2-17 Domestic Kitchens"
                };

                    subFoldersToCreate["Design Information/3-0 Mechanical, Electrical and Public Health"] = new List<string>
                {
                    "3-1 SAP - Part L Compliance",
                    "3-2 Electrical Designs",
                    "3-3 Mechanical and Public Health Designs"
                };

                    subFoldersToCreate["Design Information/4-0 Landscaping and Civil Engineering"] = new List<string>
                {
                    "4-1 Landscaping"
                };

                    subFoldersToCreate["Design Information/X-0 General"] = new List<string>
                {
                    "X-01 Documents and Plans",
                    "X-03 Competency Declaration",
                    "X-10",
                    "X-4 Construction Control Plan",
                    "X-5 Change Control Plan",
                    "X-6 Building Regulations Compliance Statement",
                    "X-7 Fire & Emergency File",
                    "X-8 Mandatory Occurrence Reporting Plan",
                    "X-9 Staged Work Statement - Partial Completion Strategy"
                };

                    return new SharepointDirectory
                    {
                        FolderNames = defaultFolderStruct,
                        SubFoldersToCreate = subFoldersToCreate
                    };

                case OrganisationalUnitEnum.FireSafety:
                    return new SharepointDirectory
                    {
                        FolderNames = defaultFolderStruct,
                        SubFoldersToCreate = subFoldersToCreate
                    };

                case OrganisationalUnitEnum.FireEngineering:
                case OrganisationalUnitEnum.StructuralEngineering:
                case OrganisationalUnitEnum.BuildingEnvelope:
                    return sharepointService.GetFoldersForFireStructuralBuildingInJobs();

                default:
                    return new SharepointDirectory
                    {
                        FolderNames = defaultFolderStruct,
                        SubFoldersToCreate = subFoldersToCreate
                    };
            }
        }
        catch
        {
            return new SharepointDirectory
            {
                FolderNames = defaultFolderStruct,
                SubFoldersToCreate = subFoldersToCreate
            };
        }
    }

    private SharepointDirectory BuildQuoteSharepointDirectory(string? organisationalUnitGuid)
    {
        if (string.IsNullOrWhiteSpace(organisationalUnitGuid))
        {
            return new SharepointDirectory();
        }

        try
        {
            switch (OrganisationalUnitHelper.GetById(organisationalUnitGuid.ToUpperInvariant()))
            {
                case OrganisationalUnitEnum.FireEngineering:
                case OrganisationalUnitEnum.StructuralEngineering:
                case OrganisationalUnitEnum.BuildingEnvelope:
                    return sharepointService.GetFoldersForFireStructuralBuildingInQuotes();

                default:
                    return new SharepointDirectory();
            }
        }
        catch
        {
            return new SharepointDirectory();
        }
    }

    private SharepointDirectory BuildEnquirySharepointDirectory(string? organisationalUnitGuid)
    {
        if (string.IsNullOrWhiteSpace(organisationalUnitGuid))
        {
            return new SharepointDirectory();
        }

        try
        {
            switch (OrganisationalUnitHelper.GetById(organisationalUnitGuid.ToUpperInvariant()))
            {
                case OrganisationalUnitEnum.FireEngineering:
                case OrganisationalUnitEnum.StructuralEngineering:
                case OrganisationalUnitEnum.BuildingEnvelope:
                    return sharepointService.GetFoldersForFireStructuralBuildingInEnquiry();

                default:
                    return new SharepointDirectory();
            }
        }
        catch
        {
            return new SharepointDirectory();
        }
    }

    private string ResolveQuoteOrganisationalUnitGuid(
    DataObject dataObject,
    API.Core.OrganisationalUnit? organisationalUnit)
    {
        // Quote must use its own OU, not enquiry OU
        if (organisationalUnit != null && !string.IsNullOrWhiteSpace(organisationalUnit.Guid))
        {
            return organisationalUnit.Guid;
        }

        return GetStringPropertyValue(
            dataObject,
            "07c15164-1d8b-452d-9cec-eef64056ab52");
    }


    private string GetStringPropertyValue(DataObject dataObject, string entityPropertyGuid)
    {
        if (dataObject == null || dataObject.DataProperties == null || string.IsNullOrWhiteSpace(entityPropertyGuid))
        {
            return string.Empty;
        }

        var property = dataObject.DataProperties
            .FirstOrDefault(x => x.EntityPropertyGuid.ToString().Equals(entityPropertyGuid, StringComparison.OrdinalIgnoreCase));

        if (property?.Value == null)
        {
            return string.Empty;
        }

        try
        {
            if (property.Value.TryUnpack<StringValue>(out var value))
            {
                return value?.Value ?? string.Empty;
            }

            return property.Value.Unpack<StringValue>().Value ?? string.Empty;
        }
        catch
        {
            return string.Empty;
        }
    }

    //CBLD-415: New method to get the SharePoint URL. Based on the previous one but a simplified version of that.
    public async Task<string> GetSharePointURL(DataObject dataObject, EF.Core _efCore)
    {
        var _ListOfSharepointDetail = await _efCore.GetSharePointDetailsForObject(dataObject);
        var _AppConfig = new AppConfiguration(_config);

        DriveItem folder;

        var siteUrl = "";
        var siteId = "";
        var useLibraryPerSplit = false;
        var primaryKeySplitInterval = 0;
        var name = "";
        var parentUseLibraryPerSplit = false;
        var parentPrimaryKeySplitInterval = 0;
        var parentName = "";
        var parentStructureId = -1;
        var quoteId = "";
        var quoteURL = "";
        long parentObjectId = -1;

        foreach (var sharePointDetail in _ListOfSharepointDetail)
        {
            switch (_AppConfig.EnvironmentType)
            {
                case "DEV":
                    siteId = _AppConfig.DevSharepointIdentifier;
                    break;

                case "TEST":
                    siteId = _AppConfig.DevSharepointIdentifier;
                    break;

                default:
                    siteId = sharePointDetail.SiteIdentifier;
                    break;
            }

            useLibraryPerSplit = sharePointDetail.UseLibraryPerSplit;
            primaryKeySplitInterval = sharePointDetail.PrimaryKeySplitInterval;
            name = sharePointDetail.Name;
            parentUseLibraryPerSplit = sharePointDetail.ParentUseLibraryPerSplit;
            parentPrimaryKeySplitInterval = sharePointDetail.ParentPrimaryKeySplitInterval;
            parentName = sharePointDetail.ParentName;
            parentStructureId = sharePointDetail.ParentStructureId;
            parentObjectId = sharePointDetail.ParentObjectId;

            if (siteId != "")//&& dataObject.SharePointSiteIdentifier == "")
            {
                if (parentStructureId > -1)
                    drive = await GetCreateLibrary(siteId, parentUseLibraryPerSplit, parentObjectId,
                        parentPrimaryKeySplitInterval, dataObject, sharePointDetail);
                else if (parentStructureId == -1 && useLibraryPerSplit)
                    drive = await GetCreateLibrary(siteId, useLibraryPerSplit, dataObject.DatabaseId,
                        primaryKeySplitInterval, dataObject, sharePointDetail);
                else
                    drive = await _graphServiceClient
                        .Sites[siteId]
                        .Drive
                        .GetAsync(
                            requestConfiguration =>
                            {
                                requestConfiguration.QueryParameters.Expand = new[] { "list($select=id)" };
                            });
            }
            dataObject.SharePointSiteIdentifier = siteId;
            if (dataObject.SharePointSiteIdentifier != "")
            {
                //Check for dev site and set siteId to the dev site
                switch (_AppConfig.EnvironmentType)
                {
                    case "DEV":
                        dataObject.SharePointSiteIdentifier = _AppConfig.DevSharepointIdentifier;
                        break;

                    case "TEST":
                        dataObject.SharePointSiteIdentifier = _AppConfig.DevSharepointIdentifier;
                        break;

                    default:
                        dataObject.SharePointSiteIdentifier = dataObject.SharePointSiteIdentifier;
                        break;
                }
                siteId = dataObject.SharePointSiteIdentifier;
                var NewFolderStructure = Functions.GetSeparatedNumberValues(dataObject.SharePointFolderPath);
                drive = await GetCreateLibrary(siteId, useLibraryPerSplit, NewFolderStructure,
                    primaryKeySplitInterval, drive);

                if (drive != null)
                {
                    if (parentStructureId > -1)
                    {
                        folder = await GetCreateFolder(siteId, dataObject.Label, parentObjectId,
                        parentStructureId > -1 ? primaryKeySplitInterval : 0, drive, dataObject, sharePointDetail);
                    }
                    else
                    {
                        folder = await GetCreateFolder(siteId, dataObject.Label, Convert.ToInt64(NewFolderStructure[1]),
                                                parentStructureId > -1 ? primaryKeySplitInterval : 0, drive);
                    }

                    if (dataObject.EntityTypeGuid == JobEntityTypeGuid)
                    {
                        await sharepointService.EnsureFolderStructureExists(
                                _graphServiceClient,
                                siteId,
                                dataObject.SharePointUrl,
                                new List<string>
                                {
                "Admin",
                "Certs",
                "Design Information",
                "Design Risk",
                "Emails",
                "Finance",
                "Photos",
                "Reports"
                                },
                                drive,
                                folder,
                                dataObject.Label,
                                Functions.SanitizeFileName(quoteId),
                                quoteURL,
                                false,
                                new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase))
                            .ConfigureAwait(false);
                    }
                    else
                    {
                        await sharepointService.EnsureFolderStructureExists(
                                _graphServiceClient,
                                siteId,
                                dataObject.SharePointUrl,
                                new List<string>(),
                                drive,
                                folder,
                                dataObject.Label,
                                Functions.SanitizeFileName(quoteId),
                                quoteURL,
                                false,
                                new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase))
                            .ConfigureAwait(false);
                    }
                    SetSharePointPermission(siteId, dataObject, drive.Id, folder.Id ?? "");
                    dataObject.SharePointUrl = folder.WebUrl ?? "";
                }
            }
        }

        return dataObject.SharePointUrl != "" ? dataObject.SharePointUrl : "";
    }

    public async Task<List<SharePointSite>> GetSitesAsync()
    {
        List<SharePointSite> sites = new();

        try
        {
            // Retrieve the site collection using the Graph API
            var siteCollection = await _graphServiceClient.Sites.GetAsync(requestConfiguration =>
            {
                requestConfiguration.QueryParameters.Select = new[] { "siteCollection", "webUrl" };
                requestConfiguration.QueryParameters.Filter = "siteCollection/root ne null";
            });

            if (siteCollection != null && siteCollection.Value != null)
            {
                // Create the page iterator to iterate through all pages
                var pageIterator = PageIterator<Site, SiteCollectionResponse>
                    .CreatePageIterator(
                        _graphServiceClient,
                        siteCollection,
                        s =>
                        {
                            // Add each site to the list after null checks
                            sites.Add(new SharePointSite
                            {
                                Id = s.Id ?? "",
                                DisplayName = s.DisplayName ?? "",
                                WebUrl = s.WebUrl ?? "",
                                CreatedDateTime = s.CreatedDateTime != null
                                    ? Timestamp.FromDateTimeOffset((DateTimeOffset)s.CreatedDateTime)
                                    : Timestamp.FromDateTime(DateTime.UtcNow),
                                Description = s.Description ?? "",
                                LastModifiedDateTime = s.LastModifiedDateTime != null
                                    ? Timestamp.FromDateTimeOffset((DateTimeOffset)s.LastModifiedDateTime)
                                    : Timestamp.FromDateTime(DateTime.UtcNow),
                                Name = s.Name ?? "",
                                Root = s.Root?.ToString() ?? ""
                            });

                            // Return true to continue iteration
                            return true;
                        });

                // Start iterating through the pages
                await pageIterator.IterateAsync();
            }
        }
        catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
        {
            // Log the OData error message
            Console.Error.WriteLine($"OData Error: {odataError.Error?.Message ?? "Unknown error"}");
            throw;
        }
        catch (Exception ex)
        {
            // Log any other unexpected errors
            Console.Error.WriteLine($"Unexpected error: {ex.Message}");
            throw;
        }

        return sites;
    }

    public async void SetSharePointPermission(string siteId, DataObject dataObject, string driveId, string itemId)
    {
        _ = Task.Run(async () =>
        {
            List<PerIdentitySecurity> dataObjectSecurities = new();
            Console.WriteLine("Starting SetSharePointPermission process...");

            try
            {
                Console.WriteLine("Retrieving existing permissions...");
                var permissionCollectionResponse = await _graphServiceClient
                    .Drives[driveId]
                    .Items[itemId]
                    .Permissions
                    .GetAsync();

                if (permissionCollectionResponse != null)
                {
                    Console.WriteLine("Permissions retrieved successfully.");
                    var existingPermissions = permissionCollectionResponse.Value ?? [];

                    foreach (var permission in existingPermissions)
                    {
                        PerIdentitySecurity? securityObject = null;
                        var roles = permission.Roles ?? [];

                        // Match with security objects in dataObject
                        if (permission.GrantedToV2 is not null)
                        {
                            if (permission.GrantedToV2.User is not null)
                            {
                                securityObject = dataObjectSecurities.FirstOrDefault(d => d.IdentityId == permission.GrantedToV2.User.Id);
                            }
                            else if (permission.GrantedToV2.Group is not null)
                            {
                                if (permission.GrantedToV2.Group.DisplayName != null && !permission.GrantedToV2.Group.DisplayName.Contains("Owners"))
                                {
                                    securityObject = dataObjectSecurities.FirstOrDefault(d => d.IdentityId == permission.GrantedToV2.Group.Id);
                                }
                            }
                        }

                        // Delete permissions if no matching security object
                        if (securityObject == null)
                        {
                            try
                            {
                                Console.WriteLine($"Deleting permission: {permission.Id}");
                                // Uncomment this line to enable deletion await _graphServiceClient.Drives[driveId].Items[itemId].Permissions[permission.Id].DeleteAsync();
                                Console.WriteLine($"Permission {permission.Id} deleted successfully.");
                            }
                            catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
                            {
                                Console.Error.WriteLine($"OData Error (Delete): {odataError.Error?.Message ?? "Unknown error"}");
                                throw;
                            }
                        }
                        // Update permissions if roles mismatch
                        else if (
                            (securityObject.Role == "read" && !roles.Contains("read")) ||
                            (securityObject.Role == "write" && roles.Contains("read")) ||
                            (securityObject.Role == "write" && !roles.Contains("write")) ||
                            (securityObject.Role == "read" && roles.Contains("write"))
                        )
                        {
                            try
                            {
                                var requestBody = new Permission { Roles = new List<string> { securityObject.Role } };
                                Console.WriteLine($"Updating permission {permission.Id} with role {securityObject.Role}");
                                await _graphServiceClient.Drives[driveId].Items[itemId].Permissions[permission.Id].PatchAsync(requestBody);
                                Console.WriteLine($"Permission {permission.Id} updated successfully with role {securityObject.Role}.");
                            }
                            catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
                            {
                                Console.Error.WriteLine($"OData Error (Patch): {odataError.Error?.Message ?? "Unknown error"}");
                                throw;
                            }
                        }

                        if (securityObject != null)
                        {
                            dataObjectSecurities.Remove(securityObject);
                        }
                    }

                    // Assign group permissions
                    Console.WriteLine("Assigning group permissions...");
                    _ = AssignGroupPermissionsAsync(_graphServiceClient, driveId, siteId, itemId, dataObject.ObjectSecurity);
                    Console.WriteLine("Group permissions assigned successfully.");

                    // Invite users by email
                    foreach (var userSecurity in dataObject.ObjectSecurity)
                    {
                        var userEmail = userSecurity.UserIdentity;
                        if (!string.IsNullOrEmpty(userEmail))
                        {
                            var requestBody = new InvitePostRequestBody
                            {
                                Recipients = new List<DriveRecipient> { new() { Email = userEmail } },
                                RequireSignIn = true,
                                Roles = new List<string> { userSecurity.CanWrite ? "write" : "read" }
                            };

                            try
                            {
                                Console.WriteLine($"Inviting user {userEmail} with role {requestBody.Roles[0]}.");
                                var result = await _graphServiceClient.Drives[driveId].Items[itemId].Invite.PostAsInvitePostResponseAsync(requestBody);
                                Console.WriteLine($"User {userEmail} invited successfully.");
                            }
                            catch (Exception ex)
                            {
                                Console.Error.WriteLine($"Unexpected error (Invite): {ex.Message}");
                                throw;
                            }
                        }
                        else
                        {
                            Console.WriteLine("Skipping invitation for an empty or null email.");
                        }
                    }
                }

                // Invite remaining unprocessed security objects
                Console.WriteLine("Inviting remaining unprocessed security objects...");
                foreach (var securityObject in dataObjectSecurities)
                {
                    var requestBody = new InvitePostRequestBody
                    {
                        Recipients = new List<DriveRecipient> { new() { ObjectId = securityObject.IdentityId } },
                        RequireSignIn = true,
                        SendInvitation = false,
                        Roles = new List<string> { securityObject.Role ?? "" }
                    };

                    try
                    {
                        Console.WriteLine($"Inviting security object {securityObject.IdentityId} with role {requestBody.Roles[0]}.");

                        // Using the newer PostAsInvitePostResponseAsync method to avoid obsolete warnings
                        var result = await _graphServiceClient
                            .Drives[driveId]
                            .Items[itemId]
                            .Invite
                            .PostAsInvitePostResponseAsync(requestBody);

                        Console.WriteLine($"Security object {securityObject.IdentityId} invited successfully.");
                    }
                    catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
                    {
                        Console.Error.WriteLine($"OData Error (Final Invite): {odataError.Error?.Message ?? "Unknown error"}");

                        throw;
                    }
                }
            }
            catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
            {
                Console.Error.WriteLine($"OData Error: {odataError.Error?.Message ?? "Unknown error"}");
                throw;
            }

            Console.WriteLine("SetSharePointPermission process completed successfully.");
        });
    }

    public async Task UploadFileToSharePoint(string storageUrl, string fileName, byte[] fileContent)
    {
        if (string.IsNullOrEmpty(storageUrl) || string.IsNullOrEmpty(fileName) || fileContent == null || fileContent.Length == 0)
        {
            throw new ArgumentException("Invalid parameters for uploading to SharePoint.");
        }

        try
        {
            // Extract the site ID and relative path from the storage URL
            //var siteId = ExtractSiteIdFromUrl(storageUrl);
            var siteId = "";
            //Check for dev site and set siteId to the dev site
            var _AppConfig = new AppConfiguration(_config);
            switch (_AppConfig.EnvironmentType)
            {
                case "DEV":
                    siteId = _AppConfig.DevSharepointIdentifier;
                    break;

                case "TEST":
                    siteId = _AppConfig.DevSharepointIdentifier;
                    break;

                default:
                    siteId = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";
                    break;
            }

            Console.WriteLine($"Site ID: {siteId}");
            var siteIdDetails = await _graphServiceClient.Sites[$"{siteId}"].GetAsync();
            Console.WriteLine($"Site WebUrl: {siteIdDetails.WebUrl}");

            var result = Functions.ExtractLastFourSegmentsFromUrl(storageUrl);
            var parentFolder = result.Item1;
            var mainFolder = result.Item2;
            var subfolder = result.Item3;
            var subsubfolder = result.Item4;

            // Construct the relative path without including the parentFolder twice
            var relativePath = $"{mainFolder}/{subfolder}/{subsubfolder}";

            Console.WriteLine($"Relative Path: {relativePath}");

            // Get the SharePoint drives
            var drives = await _graphServiceClient.Sites[siteId].Drives.GetAsync();

            // Assume the drive ID is the one associated with the first drive
            var driveItem = drives.Value.FirstOrDefault(d => d.Name == parentFolder);
            Console.WriteLine($"Drive ID: {driveItem?.Id}");

            if (driveItem != null)
            {
                using (var stream = new MemoryStream(fileContent))
                {
                    Console.WriteLine($"Uploading {fileName} to SharePoint at path: {relativePath}/{fileName}...");
                    // Upload the file to the specified path
                    var uploadedItem = await _graphServiceClient
                        .Drives[driveItem.Id]
                        .Root
                        .ItemWithPath($"{relativePath}/{fileName}")
                        .Content
                        .PutAsync(stream);

                    Console.WriteLine($"Successfully uploaded {fileName} to SharePoint. Item ID: {uploadedItem.Id}");
                }
            }
            else
            {
                Console.WriteLine($"Drive not found for parent folder: {parentFolder}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"An error occurred while uploading file to SharePoint: {ex.Message}");
            throw; // Rethrow or handle the exception as necessary
        }
    }

    #endregion Public Methods

    #region NEW: Documents.proto Support (Resolve/List/CRUD)

    ///// <summary>
    ///// Resolve a record's SharePoint "location" in a UI-friendly, API-friendly shape.
    ///// This does NOT change the existing GetSharePointLocation logic; it complements it
    ///// for the new documents.proto service calls.
    /////
    ///// - If the DataObject already has SharePointSiteIdentifier + SharePointUrl, we use those.
    ///// - If not, we attempt to calculate/ensure the location via existing EF metadata rules.
    ///// - We then resolve site/drive/rootFolderId via Graph so the client can list/upload/etc.
    ///// </summary>
    //public async Task<DocumentsResolveResponse> DocumentsResolveAsync(
    //    EF.Core efCore,
    //    DocumentsResolveRequest request,
    //    int userId = -1)
    //{
    //    var resp = new DocumentsResolveResponse();

    //    try
    //    {
    //        if (request == null)
    //        {
    //            resp.ErrorReturned = "Request was null";
    //            return resp;
    //        }

    //        var recordGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid);
    //        var entityQueryGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid);

    //        if (recordGuid == Guid.Empty)
    //        {
    //            resp.ErrorReturned = "Invalid recordGuid";
    //            return resp;
    //        }

    //        // Attempt to load the record so we can reuse your existing location building
    //        // NOTE: EntityTypeGuid is not provided in this proto, so we use EmptyGuid here.
    //        // If you later add EntityTypeGuid, replace the Guid.Empty.
    //        var dataObject = await efCore.DataObjectGet(recordGuid, entityQueryGuid, Guid.Empty, false);

    //        if (dataObject == null || dataObject.Guid == Guid.Empty)
    //        {
    //            resp.ErrorReturned = "Record not found";
    //            return resp;
    //        }

    //        // If we have no location yet, reuse your existing creation rules
    //        if (string.IsNullOrWhiteSpace(dataObject.SharePointSiteIdentifier) || string.IsNullOrWhiteSpace(dataObject.SharePointUrl))
    //        {
    //            // This uses your metadata-driven structure creation.
    //            // We pass ServiceBase as null here intentionally; if you require it,
    //            // wire it from the gRPC service layer (recommended).
    //            await GetSharePointLocation(
    //                EntityTypeGuid: dataObject.EntityTypeGuid.ToString(),
    //                dataObject: dataObject,
    //                _efCore: efCore,
    //                serviceBase: _serviceBase,
    //                request: null,
    //                organisationalUnit: null);
    //        }

    //        // Decide SiteId:
    //        var siteId = ResolveSiteIdForEnvironment(dataObject.SharePointSiteIdentifier);

    //        // Decide Drive + Folder:
    //        // We rely on your existing URL pattern and helper that extracts drive/library name + folder path segments.
    //        var sharePointUrl = !string.IsNullOrWhiteSpace(request.SharePointUrlHint)
    //            ? request.SharePointUrlHint
    //            : dataObject.SharePointUrl;

    //        if (string.IsNullOrWhiteSpace(sharePointUrl))
    //        {
    //            resp.ErrorReturned = "No SharePointUrl available for record";
    //            return resp;
    //        }

    //        var (driveName, relPath) = ExtractDriveNameAndRelativePathFromRecordUrl(sharePointUrl);

    //        // Resolve DriveId by name
    //        var drives = await _graphServiceClient.Sites[siteId].Drives.GetAsync();
    //        var driveItem = drives?.Value?.FirstOrDefault(d => string.Equals(d.Name, driveName, StringComparison.OrdinalIgnoreCase));

    //        if (driveItem == null || string.IsNullOrWhiteSpace(driveItem.Id))
    //        {
    //            resp.ErrorReturned = $"Drive not found: {driveName}";
    //            return resp;
    //        }

    //        // Resolve FolderId (root folder for the record)
    //        // We do this by querying the item with path.
    //        var folder = await _graphServiceClient
    //            .Drives[driveItem.Id]
    //            .Root
    //            .ItemWithPath(relPath)
    //            .GetAsync();

    //        if (folder == null || string.IsNullOrWhiteSpace(folder.Id))
    //        {
    //            resp.ErrorReturned = $"Folder not found at path: {relPath}";
    //            return resp;
    //        }

    //        // Build response
    //        resp.Location = new DocumentsLocation
    //        {
    //            RecordGuid = request.RecordGuid ?? "",
    //            EntityQueryGuid = request.EntityQueryGuid ?? "",
    //            SiteId = siteId,
    //            DriveId = driveItem.Id,
    //            RootFolderId = folder.Id ?? "",
    //            RootFolderName = folder.Name ?? "",
    //            SharePointWebUrl = folder.WebUrl ?? sharePointUrl,
    //            Capabilities = new DocumentCapabilities
    //            {
    //                CanDownload = true,
    //                CanUpload = true,
    //                CanDelete = true,
    //                CanCreateFolder = true
    //            }
    //        };

    //        return resp;
    //    }
    //    catch (Exception ex)
    //    {
    //        resp.ErrorReturned = ex.Message;
    //        return resp;
    //    }
    //}

    /// <summary>
    /// List items in a folder for the new Documents UI.
    /// Assumes documents.proto defines DocumentsListResponse with a repeated field called "items".
    /// If your generated property names differ, adjust the mapping section only.
    /// </summary>
    public async Task<DocumentsListResponse> DocumentsListAsync(DocumentsListRequest request)
    {
        var resp = new DocumentsListResponse();

        try
        {
            if (request == null)
            {
                resp.ErrorReturned = "Request was null";
                return resp;
            }

            if (string.IsNullOrWhiteSpace(request.SiteId) ||
                string.IsNullOrWhiteSpace(request.DriveId))
            {
                resp.ErrorReturned = "siteId and driveId are required";
                return resp;
            }

            // folderId optional: default to root
            // folderId optional: default to root
            DriveItemCollectionResponse? children;

            if (!string.IsNullOrWhiteSpace(request.FolderId))
            {
                children = await _graphServiceClient
                    .Drives[request.DriveId]
                    .Items[request.FolderId]
                    .Children
                    .GetAsync();
            }
            else
            {
                var root = await _graphServiceClient
                    .Drives[request.DriveId]
                    .Root
                    .GetAsync();

                if (root?.Id == null)
                {
                    resp.ErrorReturned = "Unable to resolve drive root.";
                    return resp;
                }

                children = await _graphServiceClient
                    .Drives[request.DriveId]
                    .Items[root.Id]
                    .Children
                    .GetAsync();
            }

            if (children?.Value == null)
            {
                return resp;
            }

            // If your proto has a repeated message field, map here.
            // This compiles only if your documents.proto has these members.
            foreach (var item in children.Value)
            {
                if (item == null) continue;

                var isFolder = item.Folder != null;

                // If your proto defines a DocumentsListItem message:
                // resp.Items.Add(new DocumentsListItem { ... });
                //
                // If not yet defined, you can still return "ids" and "names" by extending the proto.
                // For now, we try to populate dynamic-ish fields in a safe way.

                resp.Items.Add(new DocumentsListItem
                {
                    Id = item.Id ?? "",
                    Name = item.Name ?? "",
                    WebUrl = item.WebUrl ?? "",
                    Description = item.Description ?? "",
                    IsFolder = isFolder,
                    Size = item.Size.GetValueOrDefault(),
                    CreatedUtc = item.CreatedDateTime.HasValue
                        ? Timestamp.FromDateTimeOffset(item.CreatedDateTime.Value)
                        : Timestamp.FromDateTime(DateTime.UtcNow),

                    LastModifiedUtc = item.LastModifiedDateTime.HasValue
                        ? Timestamp.FromDateTimeOffset(item.LastModifiedDateTime.Value)
                        : Timestamp.FromDateTime(DateTime.UtcNow),
                    MimeType = item.File?.MimeType ?? ""
                });
            }

            return resp;
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
            return resp;
        }
    }


    public async Task<(Stream Stream, string? FileName, string? ContentType)> GetFileContentStreamDelegatedAsync(
    GraphServiceClient delegatedGraphClient,
    string driveId,
    string itemId,
    CancellationToken ct)
    {
        if (delegatedGraphClient is null) throw new ArgumentNullException(nameof(delegatedGraphClient));
        if (string.IsNullOrWhiteSpace(driveId)) throw new ArgumentException("driveId is required", nameof(driveId));
        if (string.IsNullOrWhiteSpace(itemId)) throw new ArgumentException("itemId is required", nameof(itemId));

        // 1) Get metadata (name + mimeType) – helps set response headers correctly.
        var meta = await delegatedGraphClient
            .Drives[driveId]
            .Items[itemId]
            .GetAsync(requestConfiguration =>
            {
                // Keep it minimal
                requestConfiguration.QueryParameters.Select = new[]
                {
                "id", "name", "file", "webUrl"
                };
            }, ct);

        var fileName = meta?.Name;
        var contentType = meta?.File?.MimeType;

        // If Graph doesn't return a mime type, fall back to octet-stream.
        if (string.IsNullOrWhiteSpace(contentType))
            contentType = MediaTypeNames.Application.Octet;

        // 2) Get the file content stream
        // NOTE: this returns a Stream; do NOT dispose here (controller will stream it out).
        var stream = await delegatedGraphClient
            .Drives[driveId]
            .Items[itemId]
            .Content
            .GetAsync(null, ct);

        if (stream is null)
            throw new InvalidOperationException("Graph returned no content stream for this item.");

        return (stream, fileName, contentType);
    }

    public sealed class ResolvedDocumentRoot
    {
        public string SiteId { get; init; } = "";
        public string DriveId { get; init; } = "";
        public string RootFolderId { get; init; } = "";
        public string? RootFolderName { get; init; }
        public string? WebUrl { get; init; }
    }

    public async Task<ResolvedDocumentRoot> ResolveRecordDocumentRootDelegatedAsync(
        EF.Types.DataObject dataObject,
        string entityQueryGuid,
        GraphServiceClient delegatedGraphClient,
        CancellationToken ct)
    {
        if (dataObject == null) throw new ArgumentNullException(nameof(dataObject));
        if (delegatedGraphClient == null) throw new ArgumentNullException(nameof(delegatedGraphClient));

        // CymBuild typically already stores these after SharePoint location setup:
        var siteId = dataObject.SharePointSiteIdentifier ?? "";
        var folderPath = dataObject.SharePointFolderPath ?? "";
        var webUrl = dataObject.SharePointUrl ?? "";

        // If SiteId missing, try resolve from URL (hint or stored)
        if (string.IsNullOrWhiteSpace(siteId))
        {
            var urlToUse = webUrl;

            if (string.IsNullOrWhiteSpace(urlToUse))
                throw new InvalidOperationException("Cannot resolve SharePoint location: SharePointSiteIdentifier and SharePointUrl are both empty.");

            if (!Uri.TryCreate(urlToUse, UriKind.Absolute, out var uri))
                throw new InvalidOperationException($"Invalid SharePointUrl: {urlToUse}");

            // GetByPath expects server-relative path
            // Use the /sites/{hostname}:{server-relative-path} pattern to get the site by path
            var serverRelativePath = uri.AbsolutePath;
            if (!serverRelativePath.StartsWith("/"))
                serverRelativePath = "/" + serverRelativePath;
            var site = await delegatedGraphClient.Sites[$"{uri.Host}:{serverRelativePath}"].GetAsync(cancellationToken: ct);
            siteId = site?.Id ?? "";

            if (string.IsNullOrWhiteSpace(siteId))
                throw new InvalidOperationException("Unable to resolve SiteId from SharePointUrl.");
        }

        // Resolve default drive for the site
        var drive = await delegatedGraphClient.Sites[siteId].Drive.GetAsync(cancellationToken: ct);
        var driveId = drive?.Id ?? "";

        if (string.IsNullOrWhiteSpace(driveId))
            throw new InvalidOperationException("Unable to resolve DriveId for site.");

        // Resolve root folder item:
        // If we have a stored folder path (recommended), use it.
        // Otherwise fall back to the drive root.
        DriveItem? folderItem;
        if (!string.IsNullOrWhiteSpace(folderPath))
        {
            // folderPath in CymBuild is often something like:
            // "Shared Documents/Jobs/ABC123"
            folderItem = await delegatedGraphClient
                .Drives[driveId]
                .Root
                .ItemWithPath(folderPath)
                .GetAsync(cancellationToken: ct);
        }
        else
        {
            folderItem = await delegatedGraphClient
                .Drives[driveId]
                .Root
                .GetAsync(cancellationToken: ct);
        }

        if (folderItem?.Id == null)
            throw new InvalidOperationException("Unable to resolve root folder item.");

        return new ResolvedDocumentRoot
        {
            SiteId = siteId,
            DriveId = driveId,
            RootFolderId = folderItem.Id,
            RootFolderName = folderItem.Name,
            WebUrl = folderItem.WebUrl ?? webUrl
        };
    }

    public async Task<(IReadOnlyList<DriveItem> Items, string? NextToken)> ListFolderChildrenDelegatedAsync(
    GraphServiceClient delegatedGraphClient,
    string driveId,
    string folderId,
    int pageSize,
    string? pageToken,
    CancellationToken ct)
    {
        if (delegatedGraphClient is null) throw new ArgumentNullException(nameof(delegatedGraphClient));
        if (string.IsNullOrWhiteSpace(driveId)) throw new ArgumentException("driveId is required", nameof(driveId));
        if (string.IsNullOrWhiteSpace(folderId)) throw new ArgumentException("folderId is required", nameof(folderId));
        if (pageSize <= 0) pageSize = 100;

        DriveItemCollectionResponse? result;

        // If we got a nextLink back previously, treat it as the page token.
        if (!string.IsNullOrWhiteSpace(pageToken))
        {
            // pageToken is the ODataNextLink URL
            var rb = new Microsoft.Graph.Drives.Item.Items.Item.Children.ChildrenRequestBuilder(
                pageToken,
                delegatedGraphClient.RequestAdapter);

            result = await rb.GetAsync(cancellationToken: ct);
        }
        else
        {
            result = await delegatedGraphClient
                .Drives[driveId]
                .Items[folderId]
                .Children
                .GetAsync(requestConfiguration =>
                {
                    requestConfiguration.QueryParameters.Top = pageSize;

                    // Keep payload smaller
                    requestConfiguration.QueryParameters.Select = new[]
                    {
                    "id","name","size","lastModifiedDateTime","webUrl","file","folder"
                    };
                }, ct);
        }

        var items = (IReadOnlyList<DriveItem>)(result?.Value ?? new List<DriveItem>());
        var next = result?.OdataNextLink;

        return (items, next);
    }
    /// <summary>
    /// Create a subfolder under a folder (Documents UI).
    /// </summary>
    public async Task<DocumentsCreateFolderResponse> DocumentsCreateFolderAsync(DocumentsCreateFolderRequest request)
    {
        var resp = new DocumentsCreateFolderResponse();

        try
        {
            if (request == null)
            {
                resp.ErrorReturned = "Request was null";
                return resp;
            }

            if (string.IsNullOrWhiteSpace(request.DriveId) ||
                string.IsNullOrWhiteSpace(request.ParentFolderId) ||
                string.IsNullOrWhiteSpace(request.FolderName))
            {
                resp.ErrorReturned = "driveId, parentFolderId and folderName are required";
                return resp;
            }

            var create = new DriveItem
            {
                Name = request.FolderName,
                Folder = new Folder(),
                AdditionalData = new Dictionary<string, object>
                {
                    { "@microsoft.graph.conflictBehavior", string.IsNullOrWhiteSpace(request.ConflictBehavior) ? "rename" : request.ConflictBehavior }
                }
            };

            var created = await _graphServiceClient
                .Drives[request.DriveId]
                .Items[request.ParentFolderId]
                .Children
                .PostAsync(create);

            if (created == null || string.IsNullOrWhiteSpace(created.Id))
            {
                resp.ErrorReturned = "Folder creation failed";
                return resp;
            }

            resp.FolderId = created.Id ?? "";
            resp.FolderName = created.Name ?? "";
            resp.WebUrl = created.WebUrl ?? "";
            return resp;
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
            return resp;
        }
    }

    /// <summary>
    /// Upload a small file to SharePoint (PUT content). For larger files, prefer upload sessions.
    /// </summary>
    public async Task<DocumentsUploadResponse> DocumentsUploadAsync(DocumentsUploadRequest request)
    {
        var resp = new DocumentsUploadResponse();

        try
        {
            if (request == null)
            {
                resp.ErrorReturned = "Request was null";
                return resp;
            }

            if (string.IsNullOrWhiteSpace(request.DriveId) ||
                string.IsNullOrWhiteSpace(request.FolderId) ||
                string.IsNullOrWhiteSpace(request.FileName) ||
                request.Content == null)
            {
                resp.ErrorReturned = "driveId, folderId, fileName and content are required";
                return resp;
            }

            var bytes = request.Content.ToByteArray();
            if (bytes.Length == 0)
            {
                resp.ErrorReturned = "content was empty";
                return resp;
            }

            using var ms = new MemoryStream(bytes);

            // Upload using itemWithPath under the folder
            var uploaded = await _graphServiceClient
                .Drives[request.DriveId]
                .Items[request.FolderId]
                .ItemWithPath(request.FileName)
                .Content
                .PutAsync(ms);

            if (uploaded == null || string.IsNullOrWhiteSpace(uploaded.Id))
            {
                resp.ErrorReturned = "Upload failed";
                return resp;
            }

            resp.ItemId = uploaded.Id ?? "";
            resp.WebUrl = uploaded.WebUrl ?? "";
            return resp;
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
            return resp;
        }
    }

    /// <summary>
    /// Download a file's content by DriveId + ItemId.
    /// </summary>
    public async Task<DocumentsDownloadResponse> DocumentsDownloadAsync(DocumentsDownloadRequest request)
    {
        var resp = new DocumentsDownloadResponse();

        try
        {
            if (request == null)
            {
                resp.ErrorReturned = "Request was null";
                return resp;
            }

            if (string.IsNullOrWhiteSpace(request.DriveId) || string.IsNullOrWhiteSpace(request.ItemId))
            {
                resp.ErrorReturned = "driveId and itemId are required";
                return resp;
            }

            var stream = await _graphServiceClient
                .Drives[request.DriveId]
                .Items[request.ItemId]
                .Content
                .GetAsync();

            if (stream == null)
            {
                resp.ErrorReturned = "No content returned";
                return resp;
            }

            using var ms = new MemoryStream();
            await stream.CopyToAsync(ms);
            resp.Content = ByteString.CopyFrom(ms.ToArray());
            return resp;
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
            return resp;
        }
    }

    /// <summary>
    /// Delete a DriveItem (file or folder).
    /// </summary>
    public async Task<DocumentsDeleteResponse> DocumentsDeleteAsync(DocumentsDeleteRequest request)
    {
        var resp = new DocumentsDeleteResponse();

        try
        {
            if (request == null)
            {
                resp.ErrorReturned = "Request was null";
                return resp;
            }

            if (string.IsNullOrWhiteSpace(request.DriveId) || string.IsNullOrWhiteSpace(request.ItemId))
            {
                resp.ErrorReturned = "driveId and itemId are required";
                return resp;
            }

            await _graphServiceClient
                .Drives[request.DriveId]
                .Items[request.ItemId]
                .DeleteAsync();

            resp.Success = true;
            return resp;
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
            resp.Success = false;
            return resp;
        }
    }

    #endregion NEW: Documents.proto Support (Resolve/List/CRUD)

    #region Protected Methods

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing)
            {
                _graphServiceClient?.Dispose();
            }

            _disposed = true;
        }
    }

    #endregion Protected Methods

    #region Private Methods

    private async Task AssignGroupPermissionsAsync(GraphServiceClient graphClient, string driveId, string siteId, string itemId, List<ObjectSecurity> objectSecurity)
    {
        // Retrieve group identities
        var groupIdsCheck = new List<string>();
        //Check if objectSecurity is not null and GroupIdentity Count is greater than 0,
        //If 1 then add the default Group for all Access Permissions
        if (objectSecurity != null && objectSecurity.Count > 0)
        {
            //if (objectSecurity.Count == 1)
            //{
            //    if (!string.IsNullOrEmpty(objectSecurity[0].DefaultGroupIdentity))
            //    {
            //        groupIdsCheck.Add(objectSecurity[0].DefaultGroupIdentity);
            //    }
            //}
            //else
            //{
            foreach (var security in objectSecurity)
            {
                if (!string.IsNullOrEmpty(security.GroupIdentity))
                {
                    groupIdsCheck.Add(security.GroupIdentity);
                }
            }
            //}
        }

        //foreach (var security in objectSecurity)
        //{
        //    if (!string.IsNullOrEmpty(security.GroupIdentity))
        //    {
        //        groupIdsCheck.Add(security.GroupIdentity);
        //    }
        //}

        // Prepare the request body for retrieving groups by IDs
        var requestBody = new GetByIdsPostRequestBody
        {
            Ids = groupIdsCheck,
            Types = new List<string> { "user", "group", "device" }
        };

        // Retrieve group objects from Microsoft Graph
        var group = await graphClient
        .DirectoryObjects
        .GetByIds
        .PostAsGetByIdsPostResponseAsync(requestBody);

        // Process retrieved groups
        var groupIds = new List<string>();
        var groupEmails = new List<string>();
        if (group != null)
        {
            foreach (var groupValues in group.Value)
            {
                groupIds.Add(groupValues.Id);
                groupEmails.Add(((Microsoft.Graph.Models.Group)groupValues).Mail);
            }
        }

        if (groupIds.Count == 0)
        {
            throw new Exception("No valid group IDs found.");
        }

        // Loop through groups and assign permissions
        for (int i = 0; i < groupIds.Count; i++)
        {
            var groupId = groupIds[i];
            var groupEmail = groupEmails[i];
            // Polly retry policy
            var retryPolicy = Policy
                .Handle<Microsoft.Graph.Models.ODataErrors.ODataError>()
                .Or<HttpRequestException>()
                .WaitAndRetryAsync(3, retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)), (exception, timeSpan) =>
                {
                    Console.Error.WriteLine($"Error: {exception.Message}. Retrying in {timeSpan.TotalSeconds} seconds...");
                });
            await retryPolicy.ExecuteAsync(async () =>
            {
                try
                {
                    // Prepare the CreateLink request
                    var request_Body = new CreateLinkPostRequestBody
                    {
                        Type = "edit",
                        Scope = "users",
                        RetainInheritedPermissions = true
                    };

                    // Create a sharing link
                    var result = await graphClient
                        .Drives[driveId]
                        .Items[itemId]
                        .CreateLink
                        .PostAsync(request_Body);

                    // Grant permissions to the group
                    var request = new GrantPostRequestBody
                    {
                        Recipients = new List<DriveRecipient> {
                        new() { ObjectId = groupId }
                    },
                        Roles = new List<string> { "write" }
                    };

                    var shareDriveId = result.ShareId;
                    try
                    {
                        // Using the newer PostAsGrantPostResponseAsync method
                        var grantResponse = await graphClient
                            .Shares[shareDriveId]
                            .Permission
                            .Grant
                            .PostAsGrantPostResponseAsync(request);

                        Console.WriteLine("Permissions granted successfully.");
                    }
                    catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
                    {
                        Console.Error.WriteLine($"OData Error (Grant): {odataError.Error?.Message ?? "Unknown error"}");
                        throw;
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine($"Unexpected error (Grant): {ex.Message}");
                        throw;
                    }
                }
                catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
                {
                    Console.Error.WriteLine($"OData Error: {odataError.Error?.Message ?? "Unknown error"}");
                    throw;
                }
                catch (HttpRequestException httpEx)
                {
                    Console.Error.WriteLine($"Network error: {httpEx.Message}");
                    throw;
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"Unexpected error: {ex.Message}");
                    throw;
                }
            });
        }
    }



    private string ExtractRelativePathFromUrl(string url)
    {
        if (string.IsNullOrEmpty(url))
        {
            throw new ArgumentException("URL cannot be null or empty", nameof(url));
        }

        try
        {
            Uri uri = new Uri(url);
            string[] segments = uri.AbsolutePath.Split(new char[] { '/' }, StringSplitOptions.RemoveEmptyEntries);

            // Check if the URL follows the expected format
            if (segments.Length < 3)
            {
                throw new ArgumentException("URL does not contain enough segments to extract a relative path.", nameof(url));
            }

            // Combine all segments after the first two to form the relative path
            string relativePath = string.Join("/", segments.Skip(2));

            return relativePath;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error extracting relative path from URL: {ex.Message}");
            throw;
        }
    }

    private string ExtractSiteIdFromUrl(string url)
    {
        if (string.IsNullOrEmpty(url))
        {
            throw new ArgumentException("URL cannot be null or empty", nameof(url));
        }

        // Example URL:
        // https://domain.sharepoint.com/sites/SiteName/Shared%20Documents/Folder/FileName.ext We
        // want to extract "sites/SiteName" as the Site ID

        try
        {
            Uri uri = new Uri(url);
            string[] segments = uri.AbsolutePath.Split(new char[] { '/' }, StringSplitOptions.RemoveEmptyEntries);

            // Check if the URL follows the expected format
            if (segments.Length < 2)
            {
                throw new ArgumentException("URL does not contain enough segments to extract a Site ID.", nameof(url));
            }

            // Combine the first two segments, which typically represent the site path (e.g., "sites/SiteName")
            string siteId = $"{segments[0]}/{segments[1]}";

            return siteId;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error extracting Site ID from URL: {ex.Message}");
            throw;
        }
    }

    /*
     * Customised the function to eliminate unnecessary API calls. Pertaining to CBLD-384.
     *
     * OE: CBLD-332 - Added extra flag "IsEnquiry" to the parameters to handel the creation of enquiry links for quotes.
     * **/

    private async Task<DriveItem> GetCreateFolder(string siteId, string dataObjectLabel, long dataObjectId, int primaryKeySplitInterval, Drive? parentDrive = null, DataObject dataObject = null, SharePointDetail sharePointDetail = null)
    {
        long folderNumber;
        if (sharePointDetail?.ParentObjectId > 0)
        {
            folderNumber = sharePointDetail.ParentObjectId;
        }
        else
        {
            folderNumber = dataObjectId;
        }
        //var folderNumber = dataObjectId;
        DriveItem? folder = null;
        string? mainError = null;

        if (parentDrive == null)
        {
            parentDrive = await _graphServiceClient
                .Sites[siteId]
                .Drive
                .GetAsync(
                    requestConfiguration =>
                    {
                        requestConfiguration.QueryParameters.Expand = new[] { "list($select=id)" };
                    }
                );

            if (parentDrive == null) throw new Exception("Failed to get or create the parent drive item.");
        }

        // Calculate folder number based on split interval
        if (primaryKeySplitInterval > 0)
        {
            folderNumber = long.Parse(Math.Floor((decimal)(dataObjectId / primaryKeySplitInterval)).ToString());
        }

        try
        {
            var rootFolder = await _graphServiceClient
                .Drives[parentDrive.Id]
                .Root
                .GetAsync()
                ?? throw new Exception("Failed to obtain root folder.");

            var itemCollection = await _graphServiceClient
                .Drives[parentDrive.Id]
                .Items[rootFolder.Id]
                .Children
                .GetAsync(
                    requestConfig =>
                    {
                        requestConfig.QueryParameters.Filter = $"(name eq '{folderNumber}')";
                    }
                );

            if (itemCollection?.Value != null)
            {
                folder = itemCollection.Value.FirstOrDefault(item => item.Folder != null);
            }

            if (folder == null)
            {
                var requestBody = new DriveItem
                {
                    Name = folderNumber.ToString(),
                    Folder = new Folder()
                };

                var item = await _graphServiceClient
                    .Drives[parentDrive.Id]
                    .Items[rootFolder.Id]
                    .Children
                    .PostAsync(requestBody);

                if (folderNumber == dataObjectId && item != null)
                {
                    item = await _graphServiceClient
                        .Drives[parentDrive.Id]
                        .Items[item.Id]
                        .GetAsync(
                            requestConfiguration =>
                            {
                                requestConfiguration.QueryParameters.Expand = new[] { "listItem($select=id)" };
                            }
                        );

                    if (item?.ListItem != null)
                    {
                        var patchRequestBody = new ListItem
                        {
                            Fields = new FieldValueSet
                            {
                                AdditionalData = new Dictionary<string, object>
                                {
                                    { "RecordTitle", dataObjectLabel }
                                }
                            }
                        };

                        try
                        {
                            if (parentDrive.List != null)
                            {
                                await _graphServiceClient
                                    .Sites[siteId]
                                    .Lists[parentDrive.List.Id]
                                    .Items[item.ListItem.Id]
                                    .PatchAsync(patchRequestBody);
                            }
                        }
                        catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
                        {
                            Console.Error.WriteLine($"OData Error: {odataError.Error?.Message ?? "Unknown error"}");
                            mainError = odataError.Error?.Message;
                            //throw;
                        }
                    }
                }

                folder = item;
            }
            // New code for adding subfolders
            if (sharePointDetail?.ParentStructureId > 0)
            {
                // Create or get the subfolder with sharePointDetail.Name
                folder = await GetOrCreateSubFolder(folder, sharePointDetail.Name, parentDrive.Id);

                // Create or get the subfolder with sharePointDetail.PrimaryId
                folder = await GetOrCreateSubFolder(folder, dataObject.DatabaseId.ToString(), parentDrive.Id);
            }
        }
        catch (Microsoft.Graph.Models.ODataErrors.ODataError odataError)
        {
            mainError = odataError.Error?.Message;
            Console.Error.WriteLine($"OData Error: {mainError ?? "Unknown error"}");
            throw;
        }

        if (folder == null) throw new Exception($"GetCreateFolder failed to return a folder. {mainError}");

        return folder;
    }

    private async Task<Drive?> GetCreateLibrary(string siteId, bool useLibraryPerSplit, List<string> newFolderStructure, int primaryKeySplitInterval, Drive drive)
    {
        AppConfiguration _AppConfig = new AppConfiguration(_config);
        string mainDriveNumber = "";
        switch (_AppConfig.EnvironmentType)
        {
            case "DEV":
                mainDriveNumber = "TestSite";
                break;

            case "TEST":
                mainDriveNumber = "TestSite";
                break;

            default:
                mainDriveNumber = newFolderStructure[0];
                break;
        }
        var driveNumber = newFolderStructure[1];
        drive = null;

        while (drive is null)
        {
            try
            {
                var driveCollection = await _graphServiceClient
                    .Sites[siteId]
                    .Drives
                    .GetAsync(requestConfiguration =>
                    {
                        requestConfiguration.QueryParameters.Expand = new[] { "list($select=id)" };
                    });

                var driveList1 = new List<Drive>();

                if (driveCollection != null)
                {
                    var pageIterator = PageIterator<Drive, DriveCollectionResponse>
                        .CreatePageIterator(
                            _graphServiceClient,
                            driveCollection,
                            d1 =>
                            {
                                driveList1.Add(d1);
                                return true;
                            });
                    await pageIterator.IterateAsync();

                    drive = driveList1.Where(d => d.Name == mainDriveNumber.ToString()).FirstOrDefault();
                }
            }
            catch (ODataError odataError)
            {
                if (odataError.Error != null)
                {
                    var mainError = odataError.Error;
                }

                throw;
            }

            if (drive is null)
                try
                {
                    var requestBody = new List
                    {
                        DisplayName = mainDriveNumber.ToString(),
                        Columns = new List<ColumnDefinition>
                        {
                            new()
                            {
                                Name = "RecordTitle",
                                DisplayName = "Record Title",
                                Text = new TextColumn
                                {
                                    AllowMultipleLines = false,
                                    AppendChangesToExistingText = false,
                                    LinesForEditing = 0,
                                    MaxLength = 255
                                }
                            }
                        },
                        ListProp = new ListInfo
                        {
                            Template = "documentLibrary"
                        }
                    };

                    var list = await _graphServiceClient
                        .Sites[siteId]
                        .Lists
                        .PostAsync(requestBody);

                    if (list != null) drive = list.Drive;
                }
                catch (ODataError odataError)
                {
                    if (odataError.Error != null)
                    {
                        var mainError = odataError.Error;
                    }

                    throw;
                }
        }

        return drive;
    }

    private async Task<Drive> GetCreateLibrary(string siteId, bool useLibraryPerSplit, long dataObjectId,
        int primaryKeySplitInterval, DataObject dataObject, SharePointDetail sharePointDetail)
    {
        AppConfiguration _AppConfig = new AppConfiguration(_config);
        var driveNumber = dataObjectId;
        var MainDrive = "";
        switch (_AppConfig.EnvironmentType)
        {
            case "DEV":
                MainDrive = "TestSite";
                break;

            case "TEST":
                MainDrive = "TestSite";
                break;

            default:
                MainDrive = dataObjectId.ToString();
                break;
        }
        drive = null;

        if (primaryKeySplitInterval > 0 && MainDrive != "TestSite")
        {
            driveNumber = long.Parse(Math.Floor((decimal)(dataObjectId / primaryKeySplitInterval)).ToString());
            MainDrive = driveNumber.ToString();
        }

        while (drive is null)
        {
            try
            {
                var driveCollection = await _graphServiceClient
                    .Sites[siteId]
                    .Drives
                    .GetAsync(requestConfiguration =>
                    {
                        requestConfiguration.QueryParameters.Expand = new[] { "list($select=id)" };
                    });

                var driveList1 = new List<Drive>();

                if (driveCollection != null)
                {
                    var pageIterator = PageIterator<Drive, DriveCollectionResponse>
                        .CreatePageIterator(
                            _graphServiceClient,
                            driveCollection,
                            d1 =>
                            {
                                driveList1.Add(d1);
                                return true;
                            });
                    await pageIterator.IterateAsync();

                    drive = driveList1.Where(d => d.Name == MainDrive.ToString()).FirstOrDefault();
                    if (drive != null && !string.IsNullOrEmpty(drive?.WebUrl))
                    {
                        var weburl = drive.WebUrl;
                    }
                }
            }
            catch (ODataError odataError)
            {
                if (odataError.Error != null)
                {
                    var mainError = odataError.Error;
                }

                throw;
            }

            if (drive is null)
                try
                {
                    var requestBody = new List
                    {
                        DisplayName = MainDrive.ToString(),
                        Columns = new List<ColumnDefinition>
                        {
                            new()
                            {
                                Name = "RecordTitle",
                                DisplayName = "Record Title",
                                Text = new TextColumn
                                {
                                    AllowMultipleLines = false,
                                    AppendChangesToExistingText = false,
                                    LinesForEditing = 0,
                                    MaxLength = 255
                                }
                            }
                        },
                        ListProp = new ListInfo
                        {
                            Template = "documentLibrary"
                        }
                    };

                    var list = await _graphServiceClient
                        .Sites[siteId]
                        .Lists
                        .PostAsync(requestBody);

                    if (list != null) drive = list.Drive;
                }
                catch (ODataError odataError)
                {
                    if (odataError.Error != null)
                    {
                        var mainError = odataError.Error;
                    }

                    throw;
                }
        }

        return drive;
    }

    private async Task<DriveItem> GetOrCreateSubFolder(DriveItem parentFolder, string subFolderName, string driveId)
    {
        DriveItem? subFolder = null;

        var itemCollection = await _graphServiceClient
            .Drives[driveId]
            .Items[parentFolder.Id]
            .Children
            .GetAsync(
                requestConfig =>
                {
                    requestConfig.QueryParameters.Filter = $"(name eq '{subFolderName}')";
                }
            );

        if (itemCollection?.Value != null)
        {
            subFolder = itemCollection.Value.FirstOrDefault(item => item.Folder != null);
        }

        if (subFolder == null)
        {
            var requestBody = new DriveItem
            {
                Name = subFolderName,
                Folder = new Folder()
            };

            subFolder = await _graphServiceClient
                .Drives[driveId]
                .Items[parentFolder.Id]
                .Children
                .PostAsync(requestBody);
        }

        return subFolder ?? throw new Exception($"Failed to create or get subfolder '{subFolderName}'.");
    }

    private void InitializeSharePointDetails(List<SharePointDetail> sharePointDetails, ref string siteId, ref bool useLibraryPerSplit, ref int primaryKeySplitInterval, ref string name, ref bool parentUseLibraryPerSplit, ref int parentPrimaryKeySplitInterval, ref string parentName, ref int parentStructureId, ref long parentObjectId)
    {
        foreach (var sharePointDetail in sharePointDetails)
        {
            siteId = sharePointDetail.SiteIdentifier;
            useLibraryPerSplit = sharePointDetail.UseLibraryPerSplit;
            primaryKeySplitInterval = sharePointDetail.PrimaryKeySplitInterval;
            name = sharePointDetail.Name;
            parentUseLibraryPerSplit = sharePointDetail.ParentUseLibraryPerSplit;
            parentPrimaryKeySplitInterval = sharePointDetail.ParentPrimaryKeySplitInterval;
            parentName = sharePointDetail.ParentName;
            parentStructureId = sharePointDetail.ParentStructureId;
            parentObjectId = sharePointDetail.ParentObjectId;
        }
    }

    #endregion Private Methods


    //await sharePoint.GetSharePointDocumentDetails(test, "form Templates", request.SharePointTemplateFolderName));
}