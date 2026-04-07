namespace Concursus.EF.Types
{
    public class EntityQueryParameter : IntTypeBase
    {
        #region Public Properties

        public EntityDataType EntityDataType { get; set; } = new();
        public Guid MappedEntityPropertyGuid { get; set; }
        public string Name { get; set; } = "";

        #endregion Public Properties
    }
}