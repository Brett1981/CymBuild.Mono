namespace Concursus.Common.Shared.Helpers;

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

    #endregion Public Methods
}