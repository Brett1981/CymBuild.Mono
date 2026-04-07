namespace Concursus.API.Client.Models;

public class UserGroup
{
    #region Public Properties

    public string GroupGuid { get; set; } = "";
    public int GroupId { get; set; } = 0;
    public string GroupName { get; set; } = "";
    public string Guid { get; set; } = "";
    public int Id { get; set; } = 0;
    public string RowVersion { get; set; } = "";
    public string UserGuid { get; set; } = "";
    public int UserId { get; set; } = 0;

    #endregion Public Properties
}

public class UserService
{
    #region Public Properties

    public string Email { get; set; } = "";
    public string FirstName { get; set; } = "";
    public string FullName { get; set; } = "";
    public string Guid { get; set; } = "";
    public string LastName { get; set; } = "";
    public string MobileNo { get; set; } = "";
    public bool OnHoliday { get; set; } = false;
    public List<UserGroup>? UserGroups { get; set; }
    public int UserId { get; set; } = -1;
    public string UserName { get; set; } = "";
    public string JobTitle { get; set; } = "";
    public decimal BillableRate { get; set; } = 0;
    public byte[] Signature { get; set; } = new byte[0];

    #endregion Public Properties
}