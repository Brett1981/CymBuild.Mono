namespace Concursus.API.Types;

internal class ValidationResult
{
    #region Internal Properties

    internal bool IsHidden { get; set; }
    internal bool IsInvalid { get; set; }
    internal bool IsReadOnly { get; set; }
    internal string? Message { get; set; }
    internal Guid TargetGuid { get; set; }
    internal string? TargetType { get; set; }

    #endregion Internal Properties
}