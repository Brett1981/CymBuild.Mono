namespace Concursus.Common.Shared.Functions
{
    public static class CommonFunctions
    {
        public static Guid ParseAndReturnEmptyGuidIfInvalid(string inputGuid)
        {
            if (Guid.TryParse(inputGuid, out var parsedGuid))
                return parsedGuid;
            else
                // Return an empty Guid if the inputGuid is not a valid Guid
                return Guid.Empty;
        }
    }
}