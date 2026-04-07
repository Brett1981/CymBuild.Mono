namespace Concursus.EF.Types
{
    public class ObjectSecurity : BigIntTypeBase
    {
        #region Public Properties

        public bool CanRead { get; set; }
        public bool CanWrite { get; set; }
        public Guid GroupGuid { get; set; }
        public string GroupIdentity { get; set; } = "";

        //public string DefaultGroupIdentity { get; set; } = "";
        public Guid ObjectGuid { get; set; }

        public Guid UserGuid { get; set; }
        public string UserIdentity { get; set; } = "";

        #endregion Public Properties
    }
}