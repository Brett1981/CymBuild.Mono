namespace Concursus.EF.Types
{
    public class EntityPropertyDependant : IntTypeBase
    {
        #region Public Properties

        public Guid DependantEntityPropertyGuid { get; set; }
        public Guid ParentEntityPropertyGuid { get; set; }

        #endregion Public Properties
    }
}