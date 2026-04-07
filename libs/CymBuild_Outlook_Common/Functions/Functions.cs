using Concursus.EF.Types;
using Google.Protobuf.Collections;
using System.Text.RegularExpressions;

namespace CymBuild_Outlook_Common.Functions
{
    public static class Functions
    {
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

        public static Guid ParseAndReturnEmptyGuidIfInvalid(string inputGuid)
        {
            if (Guid.TryParse(inputGuid, out var parsedGuid))
                return parsedGuid;
            else
                // Return an empty Guid if the inputGuid is not a valid Guid
                return Guid.Empty;
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

        public static async Task<DataObjectUpsertResponse> PrepareUpdateToEfDataObjectSharePoint(DataObject dataObject,
    string siteId, string siteUrl, string? requestEntityQueryGuid, bool? requestValidateOnly = false)
        {
            try
            {
                //Update dataObject SharePoint details
                dataObject.SharePointUrl = siteUrl;
                dataObject.SharePointSiteIdentifier = siteId;
                //get the last part of the string from siteUrl after the second from last '/'
                dataObject.SharePointFolderPath = GetLastPartAfterSecondToLastSlash(siteUrl);
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex);
            }

            return new DataObjectUpsertResponse() { DataObject = dataObject };
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

        public static List<Guid> ParseAndReturnListEmptyGuidIfInvalid(RepeatedField<string>? objectGuids)
        {
            List<Guid> result = [];
            if (objectGuids != null)
                result.AddRange(objectGuids.Select(objectGuid =>
                    Guid.TryParse(objectGuid, out var parsedGuid) ? parsedGuid : Guid.Empty));
            return result;
        }
    }
}