/*
CYB-323 - Fire Engineering Fee Proposal Document Auto-Population

Registers a new MergeDocumentItemType, "Conditional Row", used to mark a single Word
bookmark (placed inside a static table row already present in the template) whose containing
table row should be REMOVED from the generated document when its gating product(s)
(SCore.MergeDocumentItemGatingProducts) are not present as line items on the quote.

This is deliberately a brand new item type rather than reusing "Includes": the existing
"Includes" pipeline (WordDocumentService.ProcessIncludesRecursively) unconditionally splices a
separate sub-document's content at a bookmark for every item of that type, for every merge
document - repurposing it here would risk changing that shared, unconditional behaviour for
every other document. A new type means the new conditional-row-removal step only ever looks at
items of this type, so no existing merge document (none of which will ever have
"Conditional Row" items) is affected in any way.

Idempotent: guarded by a fixed Guid, safe to re-run and safe to promote unchanged to
QA / UAT / LIVE.
*/
SET QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TypeGuid UNIQUEIDENTIFIER = '7892a85b-8312-43fc-b13c-c8e0f3f185c8';

IF NOT EXISTS (SELECT 1 FROM SCore.MergeDocumentItemTypes WHERE Guid = @TypeGuid)
    INSERT INTO SCore.MergeDocumentItemTypes (RowStatus, Guid, Name, IsImageType)
    VALUES (1, @TypeGuid, N'Conditional Row', 0);

SELECT ID, Guid, Name, IsImageType FROM SCore.MergeDocumentItemTypes WHERE Guid = @TypeGuid;
