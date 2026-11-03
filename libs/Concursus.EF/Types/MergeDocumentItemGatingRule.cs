namespace Concursus.EF.Types
{
    /// <summary>
    /// CYB-323: one SCore.MergeDocumentItemGatingProducts row - a "Conditional Row" merge
    /// document item is kept when any active quote item matches ProductId and, unless
    /// RibaStageId is -1 (any stage), is provided at that RIBA stage.
    /// </summary>
    public class MergeDocumentItemGatingRule
    {
        #region Public Properties

        public int ProductId { get; set; }
        public int RibaStageId { get; set; } = -1;

        #endregion Public Properties
    }
}
