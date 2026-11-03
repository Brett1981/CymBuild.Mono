namespace Concursus.EF.Types
{
    /// <summary>
    /// CYB-323: an active quote line as seen by "Conditional Row" merge processing.
    /// RibaStageId/RibaStageNumber are already normalised (ProvideAtStageID = -1 counts as
    /// stage ID 2, matching SSop.tvf_QuoteFeeDrawdown). Deliverable is the quote item's
    /// Details text, falling back to the product description when Details is blank.
    /// </summary>
    public class QuoteItemMergeLine
    {
        #region Public Properties

        public int ProductId { get; set; }
        public int RibaStageId { get; set; }
        public int RibaStageNumber { get; set; }
        public decimal LineNet { get; set; }
        public string Deliverable { get; set; } = "";
        public int SortOrder { get; set; }

        #endregion Public Properties
    }
}
