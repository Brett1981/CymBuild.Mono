namespace Concursus.EF.Types
{
    public class User
    {
        #region Public Properties

        public string Email { get; set; } = "";
        public string FirstName { get; set; } = "";
        public string FullName { get; set; } = "";
        public Guid Guid { get; set; }
        public string LastName { get; set; } = "";
        public string MobileNo { get; set; } = "";
        public string JobTitle { get; set; } = "";
        public decimal? BillableRate { get; set; }
        public bool OnHoliday { get; set; }
        public int UserId { get; set; }
        public byte[] Signature { get; set; } = new byte[0];

        #endregion Public Properties
    }
}