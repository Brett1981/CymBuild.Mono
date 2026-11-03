/*
    CYB-501 - Adds the Sage Document Number (SFin.Transactions.SageInvoiceNumber,
    now exposed by SFin.tvf_AllTransactions) as a visible column on the existing
    "Transactions" grid (SUserInterface.GridViewDefinitions.Code = ALLTRANSACTIONS)
    so it sits alongside Sage Ref. for easy reference.

    Idempotent by stable Guid: safe to re-run. Does not touch the
    "Transactions (Batched)" grid (BATCHEDTRANSACTIONS).
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON
GO

BEGIN TRANSACTION;

DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = '18FC2298-1C99-47DE-9B50-ECD643664251';
DECLARE @ColumnGuid UNIQUEIDENTIFIER = '69F2A6BB-200B-45FC-8BB3-070CDC4AD4A9';
DECLARE @LabelGuid UNIQUEIDENTIFIER = '486BAABE-CEC1-49A4-BBE0-C9345FB06FC6';
DECLARE @LabelName NVARCHAR(250) = N'ALLTRANSACTIONS.SageInvoiceNumber';
DECLARE @LabelText NVARCHAR(250) = N'Document No.';
DECLARE @GridViewDefinitionId INT;
DECLARE @DefaultLanguageId INT;
DECLARE @OldSqlQuery NVARCHAR(MAX);
DECLARE @NewSqlQuery NVARCHAR(MAX);

SELECT
    @GridViewDefinitionId = gvd.ID,
    @OldSqlQuery = gvd.SqlQuery
FROM
    SUserInterface.GridViewDefinitions AS gvd
WHERE
    gvd.Guid = @GridViewDefinitionGuid
    AND gvd.RowStatus NOT IN (0, 254);

IF @GridViewDefinitionId IS NULL
BEGIN
    THROW 51100, 'ALLTRANSACTIONS GridViewDefinition (Guid 18FC2298-1C99-47DE-9B50-ECD643664251) was not found. Cannot apply the Document No. column.', 1;
END;

SELECT
    @DefaultLanguageId = COALESCE(
        (SELECT TOP (1) l.ID FROM SCore.Languages AS l WHERE l.ID = 1 AND l.RowStatus NOT IN (0, 254)),
        (SELECT TOP (1) l.ID FROM SCore.Languages AS l WHERE l.RowStatus NOT IN (0, 254) ORDER BY l.ID)
    );

IF @DefaultLanguageId IS NULL
BEGIN
    THROW 51101, 'No active language was found. Cannot apply the ALLTRANSACTIONS Document No. label.', 1;
END;

-- Language label (idempotent by Guid)
UPDATE ll
SET
    ll.RowStatus = 1,
    ll.Name = @LabelName
FROM
    SCore.LanguageLabels AS ll
WHERE
    ll.Guid = @LabelGuid;

INSERT INTO SCore.LanguageLabels
    (RowStatus, Guid, Name)
SELECT
    1, @LabelGuid, @LabelName
WHERE
    NOT EXISTS (SELECT 1 FROM SCore.LanguageLabels WHERE Guid = @LabelGuid);

DECLARE @LabelId INT = (SELECT ID FROM SCore.LanguageLabels WHERE Guid = @LabelGuid);

UPDATE llt
SET
    llt.RowStatus = 1,
    llt.Text = @LabelText,
    llt.TextPlural = @LabelText,
    llt.HelpText = N''
FROM
    SCore.LanguageLabelTranslations AS llt
WHERE
    llt.LanguageLabelID = @LabelId
    AND llt.LanguageID = @DefaultLanguageId;

INSERT INTO SCore.LanguageLabelTranslations
    (RowStatus, Guid, Text, TextPlural, LanguageLabelID, LanguageID, HelpText)
SELECT
    1, NEWID(), @LabelText, @LabelText, @LabelId, @DefaultLanguageId, N''
WHERE
    NOT EXISTS
    (
        SELECT 1
        FROM SCore.LanguageLabelTranslations
        WHERE LanguageLabelID = @LabelId
          AND LanguageID = @DefaultLanguageId
          AND RowStatus NOT IN (0, 254)
    );

-- Grid view SqlQuery: add root_hobt.SageInvoiceNumber right after SageTransactionReference.
-- Only applied when the query still matches the known pre-CYB-501 shape (safe / idempotent no-op otherwise).
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
        root_hobt.OrgUnit
FROM    [SFin].[tvf_AllTransactions]([[UserId]]) AS root_hobt
WHERE   root_hobt.Batched = CONVERT(BIT, 0)';

UPDATE SUserInterface.GridViewDefinitions
SET
    SqlQuery = @NewSqlQuery
WHERE
    Guid = @GridViewDefinitionGuid
    AND SqlQuery = @OldSqlQuery;

-- Column definition (idempotent by Guid). Placed after OrgUnit (order 11) and
-- before the trailing Department/ID overrides (150/999) so no existing
-- ColumnOrder values need to change.
UPDATE gvcd
SET
    gvcd.RowStatus = 1,
    gvcd.Name = N'SageInvoiceNumber',
    gvcd.ColumnOrder = 12,
    gvcd.GridViewDefinitionId = @GridViewDefinitionId,
    gvcd.IsPrimaryKey = 0,
    gvcd.IsHidden = 0,
    gvcd.IsFiltered = 1,
    gvcd.IsCombo = 0,
    gvcd.IsLongitude = 0,
    gvcd.IsLatitude = 0,
    gvcd.DisplayFormat = N'',
    gvcd.Width = N'150px',
    gvcd.LanguageLabelId = @LabelId,
    gvcd.TopHeaderCategory = N'',
    gvcd.TopHeaderCategoryOrder = 0
FROM
    SUserInterface.GridViewColumnDefinitions AS gvcd
WHERE
    gvcd.Guid = @ColumnGuid;

INSERT INTO SUserInterface.GridViewColumnDefinitions
    (RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder)
SELECT
    1, @ColumnGuid, N'SageInvoiceNumber', 12, @GridViewDefinitionId, 0, 0, 1, 0, 0, 0, N'', N'150px', @LabelId, N'', 0
WHERE
    NOT EXISTS (SELECT 1 FROM SUserInterface.GridViewColumnDefinitions WHERE Guid = @ColumnGuid);

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
    gvcd.Width,
    ll.Name AS LabelName,
    llt.Text AS LabelText
FROM
    SUserInterface.GridViewColumnDefinitions AS gvcd
JOIN
    SCore.LanguageLabels AS ll ON (ll.ID = gvcd.LanguageLabelId)
LEFT JOIN
    SCore.LanguageLabelTranslations AS llt ON (llt.LanguageLabelID = ll.ID)
WHERE
    gvcd.Guid = '69F2A6BB-200B-45FC-8BB3-070CDC4AD4A9';
GO
