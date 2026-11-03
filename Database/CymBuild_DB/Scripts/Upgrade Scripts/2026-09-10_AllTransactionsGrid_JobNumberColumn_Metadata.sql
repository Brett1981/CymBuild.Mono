/*
    Fixes the "Finance > All Transactions" (SUserInterface.GridViewDefinitions.Code =
    ALLTRANSACTIONS) grid throwing "GridDataList failed: Exception occurred getting
    GridDataList: JobNumber" on load.

    Root cause: a GridViewColumnDefinitions row named 'JobNumber' already exists for
    this grid (added directly against the DEV database, outside source control), but
    the grid's SqlQuery text was never updated to project a same-named column, even
    though SFin.tvf_AllTransactions has returned JobNumber since commit 9200fb41
    (2026-08-10). This script only corrects the SqlQuery text; it does not touch the
    GridViewColumnDefinitions row, which already exists with whatever ColumnOrder/
    Width/LanguageLabelId it was given when it was added.

    Idempotent by stable Guid: safe to re-run. If the current SqlQuery no longer
    matches the expected pre-fix shape below (e.g. it has already been corrected, or
    changed for some other reason), the UPDATE is a no-op - check the verification
    SELECT at the end.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON
GO

BEGIN TRANSACTION;

DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = '18FC2298-1C99-47DE-9B50-ECD643664251';
DECLARE @OldSqlQuery NVARCHAR(MAX);
DECLARE @NewSqlQuery NVARCHAR(MAX);

IF NOT EXISTS
(
    SELECT 1
    FROM SUserInterface.GridViewDefinitions AS gvd
    WHERE gvd.Guid = @GridViewDefinitionGuid
      AND gvd.RowStatus NOT IN (0, 254)
)
BEGIN
    THROW 51100, 'ALLTRANSACTIONS GridViewDefinition (Guid 18FC2298-1C99-47DE-9B50-ECD643664251) was not found. Cannot apply the JobNumber query fix.', 1;
END;

-- Known pre-fix shape: the SageInvoiceNumber column added by
-- 2026-09-07_AllTransactionsGrid_DocumentNumberColumn_Metadata.sql, still missing JobNumber.
SET @OldSqlQuery = N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Number,
        root_hobt.Date,
        root_hobt.Account,
        root_hobt.TransactionType,
        root_hobt.Net,
        root_hobt.Vat,
        root_hobt.Gross,
        root_hobt.Outstanding,
        root_hobt.SageTransactionReference,
        root_hobt.SageInvoiceNumber,
        root_hobt.PurchaseOrderNumber,
        root_hobt.Surveyor,
        root_hobt.Batched,
        root_hobt.IsOverdue,
        root_hobt.SageStatusCode,
        root_hobt.HasSageReference,
        root_hobt.Department,
        root_hobt.OrgUnit
FROM    [SFin].[tvf_AllTransactions]([[UserId]]) AS root_hobt
WHERE   root_hobt.Batched = CONVERT(BIT, 0)';

SET @NewSqlQuery = N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Number,
        root_hobt.Date,
        root_hobt.Account,
        root_hobt.TransactionType,
        root_hobt.Net,
        root_hobt.Vat,
        root_hobt.Gross,
        root_hobt.Outstanding,
        root_hobt.SageTransactionReference,
        root_hobt.SageInvoiceNumber,
        root_hobt.PurchaseOrderNumber,
        root_hobt.Surveyor,
        root_hobt.Batched,
        root_hobt.IsOverdue,
        root_hobt.SageStatusCode,
        root_hobt.HasSageReference,
        root_hobt.Department,
        root_hobt.OrgUnit,
        root_hobt.JobNumber
FROM    [SFin].[tvf_AllTransactions]([[UserId]]) AS root_hobt
WHERE   root_hobt.Batched = CONVERT(BIT, 0)';

UPDATE SUserInterface.GridViewDefinitions
SET
    SqlQuery = @NewSqlQuery
WHERE
    Guid = @GridViewDefinitionGuid
    AND SqlQuery = @OldSqlQuery;

COMMIT TRANSACTION;
GO

-- Verification
SELECT
    gvd.Code,
    gvd.SqlQuery
FROM
    SUserInterface.GridViewDefinitions AS gvd
WHERE
    gvd.Guid = '18FC2298-1C99-47DE-9B50-ECD643664251';

SELECT
    gvcd.Guid,
    gvcd.Name,
    gvcd.ColumnOrder,
    gvcd.Width
FROM
    SUserInterface.GridViewColumnDefinitions AS gvcd
WHERE
    gvcd.Name = N'JobNumber'
    AND gvcd.RowStatus NOT IN (0, 254);
GO
