namespace Concursus.PWA.Classes
{
    /// <summary>
    /// When an identifying field (name, address, ...) changes after the duplicate check was
    /// confirmed, the Account, Contact and Structure pages re-arm "You must validate before you can
    /// save". FlexPropertyGroup only renders the Validate button while the record is new, so
    /// re-arming a record that has already been saved blocks Save with no way to clear it (renaming a
    /// just-created Account silently did nothing until the page was reloaded).
    /// </summary>
    internal static class DuplicateCheckRevalidation
    {
        internal static bool ShouldRearm(bool validationConfirmed, bool isIdentifyingField, string? recordGuid) =>
            validationConfirmed && isIdentifyingField && IsNewRecord(recordGuid);

        internal static bool IsNewRecord(string? recordGuid) =>
            string.IsNullOrWhiteSpace(recordGuid) || recordGuid == Guid.Empty.ToString();
    }
}
