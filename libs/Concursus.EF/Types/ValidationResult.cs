namespace Concursus.EF.Types
{
    public class ValidationResult
    {
        #region Public Properties

        public bool IsHidden { get; set; }
        public bool IsInformationOnly { get; set; }
        public bool IsInvalid { get; set; }
        public bool IsReadOnly { get; set; }
        public string Message { get; set; } = "";
        public Guid TargetGuid { get; set; }
        public string TargetType { get; set; } = "";

        #endregion Public Properties
    }
}