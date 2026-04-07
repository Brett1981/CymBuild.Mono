namespace Concursus.EF.Types
{
    public class ObjectSharePointPaths
    {
        #region Public Properties

        public Guid ObjectGuid { get; set; } = Guid.Empty;
        public string SharePointSiteIdentifier { get; set; } = "";
        public string FolderPath { get; set; } = "";
        public string FullSharePointUrl { get; set; } = "";

        #endregion Public Properties
    }
}