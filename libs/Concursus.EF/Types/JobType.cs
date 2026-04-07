namespace Concursus.EF.Types
{
    //CBLD-405: Added jobtype
    public class JobType
    {
        #region Public Properties

        public Guid? Guid { get; set; }
        public string Name { get; set; } = "";
        public bool IsActive { get; set; } = false;
        public int SequenceID { get; set; } = -1;
        public bool UseTimeSheets { get; set; } = false;
        public bool UserPlanChecks { get; set; } = false;
        public Guid? OrganisationalUnitGuid { get; set; }

        #endregion Public Properties
    }
}