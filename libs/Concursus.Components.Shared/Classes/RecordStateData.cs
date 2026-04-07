using Concursus.API.Client.Models;

namespace Concursus.Components.Shared.Classes
{
    public class RecordStateData
    {
        #region Public Constructors

        public RecordStateData(StateService stateService)
        {
            OriginalGuid = ParseAndReturnEmptyGuidIfInvalid(stateService.OriginalRecordGuid);
            ChildGuid = ParseAndReturnEmptyGuidIfInvalid(stateService.ChildRecordGuid);
            OriginalItem = ParseAndReturnEmptyGuidIfInvalid(stateService.OriginalRecordItem);
            ChildItem = ParseAndReturnEmptyGuidIfInvalid(stateService.ChildRecordItem);
            OriginalRecordType = ParseAndReturnEmptyGuidIfInvalid(stateService.OriginalRecordType);
            ChildRecordType = ParseAndReturnEmptyGuidIfInvalid(stateService.ChildRecordType);
        }

        #endregion Public Constructors

        #region Public Properties

        public Guid ChildGuid { get; set; }
        public Guid ChildItem { get; set; }
        public Guid ChildRecordType { get; set; }
        public Guid OriginalGuid { get; set; }
        public Guid OriginalItem { get; set; }
        public Guid OriginalRecordType { get; set; }

        #endregion Public Properties

        #region Private Methods

        private static Guid ParseAndReturnEmptyGuidIfInvalid(string inputGuid)
        {
            if (Guid.TryParse(inputGuid, out var parsedGuid))
                return parsedGuid;
            // Return an empty Guid if the inputGuid is not a valid Guid
            return Guid.Empty;
        }

        #endregion Private Methods
    }
}