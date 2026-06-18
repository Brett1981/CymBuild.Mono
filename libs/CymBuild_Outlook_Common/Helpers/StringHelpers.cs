using Newtonsoft.Json;

namespace CymBuild_Outlook_Common.Helpers
{
    public static class StringHelpers
    {
        #region Public Methods

        public static string Between(string inputstring, string firstString, string lastString)
        {
            string finalString;
            var pos1 = inputstring.IndexOf(firstString) + firstString.Length;
            var pos2 = inputstring.IndexOf(lastString);
            finalString = inputstring.Substring(pos1, pos2 - pos1);

            return finalString;
        }

        public static string PrepareFullTextSearchString(string input)
        {
            // Format and sanitize the input string for SQL full-text search
            return "\"" + input.Replace("\"", "\"\"") + "*\"";
        }

        public static string PrepareSQLFullTextSearchString(string input)
        {
            if (string.IsNullOrEmpty(input))
                return input;

            // Replace potentially dangerous characters to prevent SQL injection
            var sanitizedInput = input.Replace("'", "''").Replace("%", "[%]").Replace("_", "[_]");

            // Format for full-text search with wildcard % at the start and end
            return "%" + sanitizedInput + "%";
        }

        public static List<string> ParseFolderLocation(string jsonString)
        {
            var results = new List<string>();

            if (string.IsNullOrWhiteSpace(jsonString))
                return results;

            List<FolderLocation>? folderLocations;

            try
            {
                folderLocations = JsonConvert.DeserializeObject<List<FolderLocation>>(jsonString);
            }
            catch
            {
                return results;
            }

            if (folderLocations == null || folderLocations.Count == 0)
                return results;

            foreach (var location in folderLocations)
            {
                if (location == null)
                    continue;

                if (!string.IsNullOrWhiteSpace(location.SiteIdentifier))
                    results.Add(location.SiteIdentifier.Trim());

                if (!string.IsNullOrWhiteSpace(location.FolderPath))
                {
                    var cleanPath = location.FolderPath
                        .Replace("\\", "/")
                        .Trim()
                        .Trim('/');

                    results.Add(cleanPath);
                }
            }

            return results;
        }

        #endregion Public Methods
    }

    public class FolderLocation
    {
        public string SiteIdentifier { get; set; }
        public string FolderPath { get; set; }
    }
}