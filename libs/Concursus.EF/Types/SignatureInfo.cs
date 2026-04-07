namespace Concursus.EF.Types
{
    public class SignatureInfo
    {
        #region Public Properties

        public string EmailAddress { get; set; } = "";
        public string FullName { get; set; } = "";
        public Guid EnquiryGuid { get; set; }
        public Guid QuoteGuid { get; set; }
        public Guid JobGuid { get; set; }
        public Guid UserGuid { get; set; }
        public bool IsActive { get; set; }
        public string JobTitle { get; set; } = "";
        public string JobTypeName { get; set; } = "";
        public byte[] Signature { get; set; } = new byte[0];

        #endregion Public Properties
    }
}