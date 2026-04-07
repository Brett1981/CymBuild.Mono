namespace Concursus.EF.Types;

public class OrganisationalUnit : IntTypeBase
{
    #region Public Properties

    public string Name { get; set; } = "";
    public Guid ParentOrganisationalUnitGuid { get; set; }

    //CBLD-405: Fields below added.
    public bool? IsDivision { get; set; } = false;

    public bool? IsBusinessUnit { get; set; } = false;
    public bool? IsDepartment { get; set; } = false;
    public bool? IsTeam { get; set; } = false;

    #endregion Public Properties
}