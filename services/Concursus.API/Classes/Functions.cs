using Concursus.API.Core;
using Concursus.API.Services;
using Google.Protobuf.Collections;
using Google.Protobuf.WellKnownTypes;
using Microsoft.Graph;
using Microsoft.Graph.Models;
using Microsoft.Kiota.Abstractions;
using System.Text.RegularExpressions;
using DataObject = Concursus.EF.Types.DataObject;
using DataObjectUpsertResponse = Concursus.EF.Types.DataObjectUpsertResponse;
using DriveItem = Microsoft.Graph.Models.DriveItem;
using EntityType = Concursus.EF.Types.EntityType;

//using Type = System.Type;

namespace Concursus.API.Classes;

public class Functions
{
    #region Private Fields

    private static readonly Dictionary<string, string> FilterTypeMappings = new()
    {
        { "Equals", "eq" },
        { "NotEquals", "ne" },
        { "LessThan", "lt" },
        { "LessThanOrEqual", "le" },
        { "GreaterThan", "gt" },
        { "GreaterThanOrEqual", "ge" },
        { "StartsWith", "startsWith" },
        { "EndsWith", "endsWith" },
        { "Contains", "contains" },
        { "DoesNotContain", "doesnotcontain" },
        { "IsNull", "isnull" },
        { "IsNotNull", "isnotnull" },
        { "IsEmpty", "isempty" },
        { "IsNotEmpty", "isnotempty" },
    };

    #endregion Private Fields

    #region Public Methods

    // Helper method to add event to user's calendar with immutable ID preference
    public static async Task<Event> AddEventToCalendarAsync(Event newEvent, string userName, BaseGraphServiceClient graphClient)
    {
        var action = new Action<RequestConfiguration<DefaultQueryParameters>>(x =>
        {
            x.Headers.Add("Prefer", "IdType=\"ImmutableId\"");
        });

        var calendarEvent = await graphClient.Users[userName].Calendar.Events.PostAsync(newEvent, action).ConfigureAwait(false);

        return (calendarEvent ?? null)!;
    }

    public static Any ConvertSystemTypeToGoogleProtobufWellknownTypes(object? systemTypeObject)
    {
        if (systemTypeObject == null)
            return new Any();

        switch (System.Type.GetTypeCode(systemTypeObject.GetType()))
        {
            case TypeCode.Boolean:
                return Any.Pack(new BoolValue { Value = (bool)systemTypeObject });

            case TypeCode.Byte:
                return Any.Pack(new UInt32Value { Value = (byte)systemTypeObject });

            case TypeCode.Char:
                return Any.Pack(new StringValue { Value = systemTypeObject.ToString() });

            case TypeCode.DateTime:
                return Any.Pack(Timestamp.FromDateTime(new DateTime(((DateTime)systemTypeObject).Ticks, DateTimeKind.Utc)));

            case TypeCode.Decimal:
            case TypeCode.Double:
            case TypeCode.Single:
                return Any.Pack(new DoubleValue { Value = Convert.ToDouble(systemTypeObject) });

            case TypeCode.Int16:
            case TypeCode.Int32:
            case TypeCode.Int64:
                return Any.Pack(new Int64Value { Value = Convert.ToInt64(systemTypeObject) });

            case TypeCode.String:
                return Any.Pack(new StringValue { Value = (string)systemTypeObject });

            case TypeCode.Object when systemTypeObject is Guid:
                return Any.Pack(new StringValue { Value = systemTypeObject.ToString() });

            default:
                return Any.Pack(new StringValue { Value = "Unknown type" });
        }
    }

    public static DataProperty ConvertToDataProperty(DataProperty newProperty, object? value, string entityDataTypeName)
    {
        if (value != null) return newProperty;
        switch (entityDataTypeName.ToLower())
        {
            case "nvarchar":
            case "nvarchar(max)":
                StringValue stringValue = new() { Value = "" };
                newProperty.Value = Any.Pack(stringValue);
                break;

            case "int":
            case "smallint":
            case "tinyint":
                Int32Value int32Value = new() { Value = 0 };
                newProperty.Value = Any.Pack(int32Value);
                break;

            case "bigint":
                Int64Value int64Value = new() { Value = 0 };
                newProperty.Value = Any.Pack(int64Value);
                break;

            case "double":
                DoubleValue doubleValue = new() { Value = 0 };
                newProperty.Value = Any.Pack(doubleValue);
                break;

            case "bit":
                BoolValue boolValue = new() { Value = false };
                newProperty.Value = Any.Pack(boolValue);
                break;

            case "uniqueidentifier":
                StringValue guidValue = new() { Value = Guid.Empty.ToString() };
                newProperty.Value = Any.Pack(guidValue);
                break;

            case "date":
            case "datetime2":
                newProperty.Value = Any.Pack(new Empty());
                break;
        }

        return newProperty;
    }

    // Helper method to create DateTimeTimeZone from Timestamp
    public static DateTimeTimeZone DateTimeTimeZoneFromTimestamp(Timestamp? timestamp) =>
    new()
    {
        DateTime = DateTime.SpecifyKind(timestamp.ToDateTime(), DateTimeKind.Utc).ToString()
    };

    public static (string, string, string, string) ExtractLastFourSegmentsFromUrl(string url)
    {
        Uri uri = new Uri(url);
        string[] segments = uri.Segments;

        // Remove trailing slash if present
        if (segments.Length > 0 && segments[segments.Length - 1] == "/")
        {
            Array.Resize(ref segments, segments.Length - 1);
        }

        // Get the last four segments, or empty string if not enough segments are present
        int lastIndex = segments.Length - 1;
        string fourthToLastSegment = lastIndex > 2 ? segments[lastIndex - 3] : "";
        string thirdToLastSegment = lastIndex > 1 ? segments[lastIndex - 2] : "";
        string secondToLastSegment = lastIndex > 0 ? segments[lastIndex - 1] : "";
        string lastSegment = segments[lastIndex];

        // Remove trailing slashes from segments
        fourthToLastSegment = fourthToLastSegment.TrimEnd('/');
        thirdToLastSegment = thirdToLastSegment.TrimEnd('/');
        secondToLastSegment = secondToLastSegment.TrimEnd('/');
        lastSegment = lastSegment.TrimEnd('/');

        return (fourthToLastSegment, thirdToLastSegment, secondToLastSegment, lastSegment);
    }

    public static (string, string) ExtractLastTwoSegmentsFromUrl(string url)
    {
        Uri uri = new Uri(url);
        string[] segments = uri.Segments;

        // Remove trailing slash if present
        if (segments.Length > 0 && segments[segments.Length - 1] == "/")
        {
            Array.Resize(ref segments, segments.Length - 1);
        }

        // Get the last two segments
        int lastIndex = segments.Length - 1;
        string secondToLastSegment = lastIndex > 0 ? segments[lastIndex - 1] : "";
        string lastSegment = segments[lastIndex];

        // Remove trailing slashes from segments
        secondToLastSegment = secondToLastSegment.TrimEnd('/');
        lastSegment = lastSegment.TrimEnd('/');

        return (secondToLastSegment, lastSegment);
    }

    // Extracts the relative path from the SharePoint URL
    public static string ExtractRelativePathFromUrl(string url)
    {
        if (string.IsNullOrEmpty(url))
            throw new ArgumentException("URL cannot be null or empty", nameof(url));

        Uri uri = new Uri(url);
        string[] segments = uri.AbsolutePath.Split(new char[] { '/' }, StringSplitOptions.RemoveEmptyEntries);

        if (segments.Length < 3)
            throw new ArgumentException("URL does not contain enough segments to extract a relative path.", nameof(url));

        return string.Join("/", segments.Skip(2));  // Constructs the relative path starting from the 3rd segment
    }

    // Extracts Site ID from the URL
    public static string ExtractSiteIdFromUrl(string url)
    {
        if (string.IsNullOrEmpty(url))
            throw new ArgumentException("URL cannot be null or empty", nameof(url));

        Uri uri = new Uri(url);
        string[] segments = uri.AbsolutePath.Split(new char[] { '/' }, StringSplitOptions.RemoveEmptyEntries);

        if (segments.Length < 2)
            throw new ArgumentException("URL does not contain enough segments to extract a Site ID.", nameof(url));

        return segments[0] + "/" + segments[1];  // e.g., "sites/YourSite"
    }

    public static ProgressData GenerateProgressData(EF.Types.ProgressData progressData)
    {
        var data = new ProgressData
        {
            FirstComplete = progressData.FirstComplete,
            FirstDescription = progressData.FirstDescription,
            FirstValue = progressData.FirstValue,
            LastComplete = progressData.LastComplete,
            LastDescription = progressData.LastDescription,
            LastValue = progressData.LastValue,
            MidComplete = progressData.MidComplete,
            MidDescription = progressData.MidDescription,
            MidValue = progressData.MidValue,
            NextComplete = progressData.NextComplete,
            NextDescription = progressData.NextDescription,
            NextValue = progressData.NextValue,
            PreviousComplete = progressData.PreviousComplete,
            PreviousDescription = progressData.PreviousDescription,
            PreviousValue = progressData.PreviousValue
        };
        return data;
    }

    public static async Task<FileStream> GetFileContentInformationAsync(DriveItem driveItemInfo, string fileContent, object downloadUrl)
    {
        const long DefaultChunkSize = 50 * 1024; // 50 KB, TODO: change chunk size to make it realistic for a large file.
        long ChunkSize = DefaultChunkSize;
        long offset = 0;
        byte[] bytesInStream;
        // Get the number of bytes to download. calculate the number of chunks and determine the
        // last chunk size.
        long size = (long)driveItemInfo.Size;
        int numberOfChunks = Convert.ToInt32(size / DefaultChunkSize);
        int lastChunkSize = Convert.ToInt32(size % DefaultChunkSize) - numberOfChunks - 1;
        if (lastChunkSize > 0) { numberOfChunks++; }

        // Create a file stream to contain the downloaded file.
        using FileStream fileStream = File.Create((@"C:\Temp\" + driveItemInfo.Name));
        for (int i = 0; i < numberOfChunks; i++)
        {
            // Setup the last chunk to request. This will be called at the end of this loop.
            if (i == numberOfChunks - 1)
            {
                ChunkSize = lastChunkSize;
            }

            // Create the request message with the download URL and Range header.
            HttpRequestMessage req = new HttpRequestMessage(HttpMethod.Get, (string)downloadUrl);
            req.Headers.Range = new System.Net.Http.Headers.RangeHeaderValue(offset, ChunkSize + offset);

            var client = new HttpClient();
            HttpResponseMessage response = await client.SendAsync(req);

            using (Stream responseStream = await response.Content.ReadAsStreamAsync())
            {
                bytesInStream = new byte[ChunkSize];
                int read;
                do
                {
                    read = responseStream.Read(bytesInStream, 0, (int)bytesInStream.Length);
                    if (read > 0)
                        fileStream.Write(bytesInStream, 0, bytesInStream.Length);
                }
                while (read > 0);
            }
            offset += ChunkSize + 1; // Move the offset cursor to the next chunk.
        }
        return fileStream;
    }

    public static string GetFileNameText(string input)
    {
        int startIndex = 0;
        int endIndex = 0;

        while ((startIndex = input.IndexOf("[[", endIndex)) != -1 &&
               (endIndex = input.IndexOf("]]", startIndex)) != -1)
        {
            string token = input.Substring(startIndex + 2, endIndex - startIndex - 2).ToLower();

            string replacement = GetReplacement(token);

            input = input.Remove(startIndex, endIndex - startIndex + 2)
                .Insert(startIndex, replacement);

            endIndex = startIndex + replacement.Length;
        }

        return input;
    }

    public static string GetLastPartAfterSecondToLastSlash(string input)
    {
        int lastSlashIndex = input.LastIndexOf('/');
        int secondToLastSlashIndex = input.LastIndexOf('/', lastSlashIndex - 1);

        if (lastSlashIndex != -1 && secondToLastSlashIndex != -1)
        {
            return input.Substring(secondToLastSlashIndex + 1);
        }

        // Return "" if an invalid format
        return "";
    }

    public static List<Dictionary<string, string>> GetMergeData(DataObject dataObject, EntityType entityType)
    {
        // Create a list of dictionaries for merge data
        var mergeData = new List<Dictionary<string, string>>();

        // Iterate through each record in dataObject
        foreach (var record in dataObject.DataProperties)
        {
            // Find the matching entity property based on the GUID
            var entityProperty = entityType.EntityProperties
                .FirstOrDefault(p => p.Guid == Functions.ParseAndReturnEmptyGuidIfInvalid(record.EntityPropertyGuid.ToString()));

            // Skip to the next record if no matching property found
            if (entityProperty == null) continue;

            // Create a new dictionary with case-insensitive keys
            var dictionary = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "Name", entityProperty.Name }
        };

            var anyValue = record.Value;

            // Unpack the Any value based on its type URL
            switch (anyValue.TypeUrl)
            {
                case "type.googleapis.com/google.protobuf.Empty":
                    dictionary.Add("Value", "");
                    break;

                case "type.googleapis.com/google.protobuf.BoolValue":
                    var boolValue = anyValue.Unpack<BoolValue>();
                    dictionary.Add("Value", boolValue.Value.ToString());
                    break;

                case "type.googleapis.com/google.protobuf.UInt32Value":
                    var uint32Value = anyValue.Unpack<UInt32Value>();
                    dictionary.Add("Value", uint32Value.Value.ToString());
                    break;

                case "type.googleapis.com/google.protobuf.StringValue":
                    var stringValue = anyValue.Unpack<StringValue>();
                    dictionary.Add("Value", stringValue.Value);
                    break;

                case "type.googleapis.com/google.protobuf.Timestamp":
                    var timestampValue = anyValue.Unpack<Timestamp>();
                    dictionary.Add("Value", DateTime.SpecifyKind(timestampValue.ToDateTime(), DateTimeKind.Utc).ToString());
                    break;

                case "type.googleapis.com/google.protobuf.DoubleValue":
                    var doubleValue = anyValue.Unpack<DoubleValue>();
                    dictionary.Add("Value", doubleValue.Value.ToString());
                    break;

                case "type.googleapis.com/google.protobuf.Int64Value":
                    var int64Value = anyValue.Unpack<Int64Value>();
                    dictionary.Add("Value", int64Value.Value.ToString());
                    break;

                default:
                    dictionary.Add("Value", "Unknown type");
                    break;
            }

            // Add the dictionary to the merge data list
            mergeData.Add(dictionary);
        }

        return mergeData;
    }

    public static string GetPartAfterThirdSlash(string input)
    {
        // Remove "https://" or "http://" if present
        if (input.StartsWith("https://"))
        {
            input = input.Substring(8);
        }
        else if (input.StartsWith("http://"))
        {
            input = input.Substring(7);
        }

        // Find the index of the 3rd occurrence of '/'
        int slashCount = 0;
        int index = 0;
        while (slashCount < 3 && index < input.Length)
        {
            if (input[index] == '/')
            {
                slashCount++;
            }
            index++;
        }

        // If we've found the 4th slash, return the substring after it
        if (slashCount == 3 && index < input.Length)
        {
            return input.Substring(index);
        }

        // Return an empty string if less than 4 slashes are found
        return "";
    }

    public static string GetReplacement(string token)
    {
        switch (token)
        {
            case "date":
                return DateTime.Now.Date.ToString("dd_MM_yyyy");

            case "datetime":
                return DateTime.Now.ToString("dd_MM_yyyy HH_mm");

            case "client":
                return "ClientValue";

            case "agent":
                return "AgentValue";

            default:
                return $"UnknownToken_{token}";
        }
    }

    public static List<string> GetSeparatedNumberValues(string input)
    {
        List<string> resultList = new List<string>();

        // Split the input string based on "\\" delimiter
        string[] values = input.Split('\\', '/');

        // Add each value to the result list
        foreach (string value in values)
        {
            resultList.Add(value);
        }

        return resultList;
    }

    public static async Task<UserInfoGetResponse> GetUserResponseByUsernameAsync(UserInfoGetRequest request, ServiceBase serviceBase)
    {
        var user = await serviceBase._entityFramework.GetUserInfo(Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid), request.Username);

        return new UserInfoGetResponse
        {
            User = Converters.ConvertEfUserToCoreUser(user)
        };
    }

    public static async Task<UserInfoGetResponse> GetUserResponseFromCurrentIdentityAsync(ServiceBase serviceBase)
    {
        var username = serviceBase.Identity.Name ?? "";
        var user = (await serviceBase._entityFramework.UsersGet())
            .FirstOrDefault(u => u.Email.ToLower() == username.ToLower());

        return user != null
            ? new UserInfoGetResponse { User = Converters.ConvertEfUserToCoreUser(user) }
            : new UserInfoGetResponse();
    }

    public static Guid ParseAndReturnEmptyGuidIfInvalid(string inputGuid)
    {
        if (Guid.TryParse(inputGuid, out var parsedGuid))
            return parsedGuid;
        else
            // Return an empty Guid if the inputGuid is not a valid Guid
            return Guid.Empty;
    }

    public static List<Guid> ParseAndReturnListEmptyGuidIfInvalid(RepeatedField<string>? objectGuids)
    {
        List<Guid> result = [];
        if (objectGuids != null)
            result.AddRange(objectGuids.Select(objectGuid =>
                Guid.TryParse(objectGuid, out var parsedGuid) ? parsedGuid : Guid.Empty));
        return result;
    }

    public static (string, string) ReturnSiteIdentifierAndFolderNameByURL(string sharePointUrl)
    {
        var SiteIdentifier = "";
        var FolderStructure = "";

        if (string.IsNullOrEmpty(sharePointUrl))
        {
            return ("", "");
        }
        else
        {
            // List of site information
            var siteInfos = new List<SiteInfo>
        {
            new SiteInfo { SiteIdentifier = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e", SiteUrl = "https://environmentalscientifics.sharepoint.com/sites/ConcursusJobs" },
            new SiteInfo { SiteIdentifier = "environmentalscientifics.sharepoint.com,2a9db7d5-748b-472c-b76c-41accbfe3c5b,39e2f733-4aff-4568-a053-52dacbe1f03e", SiteUrl = "https://environmentalscientifics.sharepoint.com/sites/ConcursusAccounts" },
            new SiteInfo { SiteIdentifier = "environmentalscientifics.sharepoint.com,b44b2bc4-e9f2-4f25-8906-55f970704bc2,39e2f733-4aff-4568-a053-52dacbe1f03e", SiteUrl = "https://environmentalscientifics.sharepoint.com/sites/ConcursusQuotes" },
            new SiteInfo { SiteIdentifier = "environmentalscientifics.sharepoint.com,4a2d93a3-76bd-434b-9818-629cab522081,39e2f733-4aff-4568-a053-52dacbe1f03e", SiteUrl = "https://environmentalscientifics.sharepoint.com/sites/ConcursusEnquires" },
            new SiteInfo { SiteIdentifier = "environmentalscientifics.sharepoint.com,4269b76c-d941-4597-a107-502289e6e781,39e2f733-4aff-4568-a053-52dacbe1f03e", SiteUrl = "https://environmentalscientifics.sharepoint.com/sites/ConcursusProperties" },
            new SiteInfo { SiteIdentifier = "environmentalscientifics.sharepoint.com,579b8d4c-9404-432e-816e-4ea8b0fa8e3d,39e2f733-4aff-4568-a053-52dacbe1f03e", SiteUrl = "https://environmentalscientifics.sharepoint.com/sites/ConcursusSystem" }
        };

            // Check if the sharePointUrl contains any of the SiteUrls
            foreach (var siteInfo in siteInfos)
            {
                if (sharePointUrl.Contains(siteInfo.SiteUrl))
                {
                    SiteIdentifier = siteInfo.SiteIdentifier; // Set the matching SiteIdentifier

                    // Extract the FolderStructure by removing the matched SiteUrl from the sharePointUrl
                    FolderStructure = sharePointUrl.Replace(siteInfo.SiteUrl, "").TrimStart('/'); // Get remaining part after SiteUrl
                    break; // Exit the loop once we find a match
                }
            }
        }

        return (SiteIdentifier, FolderStructure);
    }

    public static string SanitizeFileName(string fileName)
    {
        // Define a regex pattern to match illegal characters
        string pattern = "[\\\\/:*?\"<>|#%]+";

        // Replace illegal characters with an empty string
        string sanitizedFileName = Regex.Replace(fileName, pattern, "");

        // Trim any leading or trailing dots or spaces
        sanitizedFileName = sanitizedFileName.Trim('.', ' ');

        return sanitizedFileName;
    }

    public static object UnpackProtobufValue(dynamic protobufObject)
    {
        var protobufType = Functions.ConvertSystemTypeToGoogleProtobufWellknownTypes(protobufObject);

        // Return the value of the Value property
        return "";
    }

    public static async Task<UserInfoUpdateResponse> UpdateUserSignatureAsync(UserInfoUpdateRequest request, ServiceBase serviceBase)
    {
        // Update the user in the database
        var efUser = Converters.ConvertCoreUserToEfUser(request.User);
        return new UserInfoUpdateResponse
        {
            User = Converters.ConvertEfUserToCoreUser(await serviceBase._entityFramework.UpdateUserSignature(efUser))
        };
    }

    #endregion Public Methods

    #region Internal Methods

    internal static EF.Types.DataObjectCompositeFilter ConvertToCoreFilterRequest(
                RepeatedField<DataObjectCompositeFilter> filters)
    {
        var resultFilter = new EF.Types.DataObjectCompositeFilter();

        // Iterate through the DataCompositeFilters
        foreach (var dataCompositeFilter in filters)
        {
            // Check if the DataCompositeFilter contains child filters
            if (dataCompositeFilter.CompositeFilters.Count > 0)
            {
                var compositeFilter = ConvertToCoreFilterRequest(dataCompositeFilter.CompositeFilters);
                resultFilter.CompositeFilters.Add(compositeFilter);
            }

            if (dataCompositeFilter.Filters.Count > 0)
            {
                var corefilters = ConvertToCoreFilterRequest(dataCompositeFilter.Filters);
                resultFilter.Filters.Add(corefilters);
            }

            dataCompositeFilter.LogicalOperator = dataCompositeFilter.LogicalOperator;
        }

        return resultFilter;
    }

    internal static EF.Types.DataObjectCompositeFilter ConvertToServerFilterRequest(
        RepeatedField<DataCompositeFilter> filters)
    {
        var resultFilter = new EF.Types.DataObjectCompositeFilter();

        // Iterate through the DataCompositeFilters
        foreach (var dataCompositeFilter in filters)
        {
            // Check if the DataCompositeFilter contains child filters
            if (dataCompositeFilter.CompositeFilters.Count > 0)
            {
                var compositeFilter = ConvertToServerFilterRequest(dataCompositeFilter.CompositeFilters);
                compositeFilter.LogicalOperator = dataCompositeFilter.LogicalOperator;
                resultFilter.CompositeFilters.Add(compositeFilter);
                resultFilter.LogicalOperator = "AND"; // dataCompositeFilter.LogicalOperator;
            }

            if (dataCompositeFilter.Filters.Count > 0)
            {
                foreach (var filter in dataCompositeFilter.Filters)
                {
                    // Check if the Guid return an empty if so get a new Guid
                    var giveMeAGuid = ParseAndReturnEmptyGuidIfInvalid(filter.Guid) == Guid.Empty ? Guid.NewGuid() : ParseAndReturnEmptyGuidIfInvalid(filter.Guid);

                    resultFilter.Filters.Add(new EF.Types.DataObjectFilter()
                    {
                        Guid = giveMeAGuid,
                        Value = filter.Value,
                        ColumnName = filter.ColumnName,
                        Operator = filter.Operator
                    });
                }
            }
        }
        return resultFilter;
    }

    //internal static EF.Types.DataObjectCompositeFilter ConvertToServerFilterRequest(
    //    RepeatedField<DataCompositeFilter> filters)
    //{
    //    var resultFilter = new EF.Types.DataObjectCompositeFilter();

    // // Iterate through the DataCompositeFilters foreach (var dataCompositeFilter in filters) { //
    // Check if the DataCompositeFilter contains child filters if
    // (dataCompositeFilter.CompositeFilters.Count > 0) { var compositeFilter =
    // ConvertToServerFilterRequest(dataCompositeFilter.CompositeFilters);
    // resultFilter.CompositeFilters.Add(compositeFilter); resultFilter.LogicalOperator =
    // dataCompositeFilter.LogicalOperator; }

    // if (dataCompositeFilter.Filters.Count > 0) { foreach (var filter in
    // dataCompositeFilter.Filters) { // Check if the Guid return an empty if so get a new Guid var
    // giveMeAGuid = ParseAndReturnEmptyGuidIfInvalid(filter.Guid) == Guid.Empty ? Guid.NewGuid() : ParseAndReturnEmptyGuidIfInvalid(filter.Guid);

    //                resultFilter.Filters.Add(new EF.Types.DataObjectFilter()
    //                {
    //                    Guid = giveMeAGuid,
    //                    Value = filter.Value,
    //                    ColumnName = filter.ColumnName,
    //                    Operator = filter.Operator
    //                });
    //            }
    //        }
    //    }
    //    return resultFilter;
    //}

    internal static EF.DataSort ConvertToServerSortRequest(RepeatedField<DataSort> sort)
    {
        var resultSort = new EF.DataSort();

        foreach (var dataSort in sort)
        {
            resultSort.ColumnName = dataSort.ColumnName;
            resultSort.Direction = dataSort.Direction;
        }

        return resultSort;
    }

    internal static async Task<DataObjectUpsertResponse> PrepareUpdateToEfDataObjectSharePoint(DataObject dataObject, EF.Core efCore,
        string siteId, string siteUrl, string? requestEntityQueryGuid, bool? requestValidateOnly = false)
    {
        try
        {
            //Update dataObject SharePoint details
            dataObject.SharePointUrl = siteUrl;
            dataObject.SharePointSiteIdentifier = siteId;
            //get the last part of the string from siteUrl after the third slash excluding https:// '/'
            dataObject.SharePointFolderPath = GetPartAfterThirdSlash(siteUrl);

            var request = new DataObjectUpsertRequest()
            {
                DataObject = Converters.ConvertEfDataObjectToCoreDataObject(dataObject),
                EntityQueryGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(requestEntityQueryGuid).ToString(),
                ValidateOnly = requestValidateOnly ?? false
            };
            var response = await efCore.DataObjectUpsert(
                new EF.Types.DataObjectUpsertRequest
                {
                    DataObject = Converters.ConvertCoreDataObjectToEfDataObject(request.DataObject),
                    EntityQueryGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid),
                    ValidateOnly = request.ValidateOnly,
                    //As this is just for loading exisiting records and not part of the save process, we can ignore the validation.
                    SkipValidation = true
                });

            dataObject = response.DataObject;
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex);
        }

        return new DataObjectUpsertResponse() { DataObject = dataObject };
    }

    #endregion Internal Methods

    #region Private Methods

    private static EF.Types.DataObjectFilter ConvertToCoreFilterRequest(RepeatedField<DataObjectFilter> filters)
    {
        var resultFilter = new EF.Types.DataObjectFilter();

        foreach (var dataFilter in filters)
        {
            resultFilter.ColumnName = dataFilter.ColumnName;
            resultFilter.Operator = GetCorrectFilterType(dataFilter.Operator);
            resultFilter.Value = dataFilter.Value;
            resultFilter.Guid = Guid.NewGuid();
        }

        return resultFilter;
    }

    private static EF.Types.DataObjectFilter ConvertToServerFilterRequest(RepeatedField<DataFilter> filters)
    {
        var resultFilter = new EF.Types.DataObjectFilter();

        foreach (var dataFilter in filters)
        {
            resultFilter.ColumnName = dataFilter.ColumnName;
            resultFilter.Operator = GetCorrectFilterType(dataFilter.Operator);
            resultFilter.Value = dataFilter.Value;
            resultFilter.Guid = string.IsNullOrEmpty(Functions.ParseAndReturnEmptyGuidIfInvalid(dataFilter.Guid).ToString()) ? Guid.NewGuid() : new Guid(Functions.ParseAndReturnEmptyGuidIfInvalid(dataFilter.Guid).ToString());
        }

        return resultFilter;
    }

    private static string GetCorrectFilterType(string @operator)
    {
        return FilterTypeMappings.TryGetValue(@operator, out var result) ? result : "eq";
    }

    #endregion Private Methods
}