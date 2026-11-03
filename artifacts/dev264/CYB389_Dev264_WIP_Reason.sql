/* CYB-389 Dev264 apply: tvf_InvoiceRequestsWIP returns WIPReason, then the WIP grid column.
   Run: sqlcmd -S "10.100.34.114\general" -d CymBuild_Dev264 -E -C -b -i <this file> */
USE [CymBuild_Dev264];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER FUNCTION [SFin].[tvf_InvoiceRequestsWIP]
(
    @UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS
RETURN
SELECT
    ir.ID,
    ir.RowStatus,
    ir.RowVersion,
    ir.Guid,
    ir.Notes,
    ir.WIPReason, --[CYB-389] why the request is on hold, shown in the WIP grid
    ir.CreatedDateTimeUTC,
    ir.InvoicingType,
    ir.ExpectedDate,
    ir.ManualStatus,
    i.Guid AS RequesterUserId,
    i.FullName AS SurveyorName,
    j.Guid AS JobId,
    j.Number,
    j.FinanceAccountID,
    FinAcc.Name AS FinanceAccountName,
    FinAcc.Code AS FinanceAccountCode,
    STRING_AGG(ActT.Name, ', ') AS ActivityID,
    Acc.Name AS ClientName,
    SUM(IRI.Net) AS Net,
    MAX(Act.EndDate) AS EndDate,
    j.BillingInstruction AS JobBillingInstruction,
    FinAcc.BillingInstruction AS CRMBillingInstruction,
    CASE
        WHEN MAX
        (
            CASE
                WHEN ActT.IsBillable = 0 THEN 'No'
                ELSE 'Yes'
            END
        ) = 'Yes' THEN 'Yes'
        ELSE 'No'
    END AS IsBillable,
    OrgUnit.Name AS OrgUnit,
    CAST
    (
        CASE
            WHEN j.FinanceAccountID IS NULL OR j.FinanceAccountID <= 0 THEN 1
            WHEN NULLIF(LTRIM(RTRIM(FinAcc.Code)), N'') IS NULL THEN 1
            ELSE 0
        END
        AS bit
    ) AS HasFinanceAccountIssue,
    CASE
        WHEN j.FinanceAccountID IS NULL OR j.FinanceAccountID <= 0
            THEN N'No finance account selected.'
        WHEN NULLIF(LTRIM(RTRIM(FinAcc.Code)), N'') IS NULL
            THEN N'Finance account does not have a valid Sage Code.'
        ELSE N''
    END AS FinanceAccountIssueMessage,
    CAST
    (
        CASE
            WHEN SUM(IRI.Net) <= 0 THEN 1
            ELSE 0
        END
        AS bit
    ) AS HasBatchingIssue,
    CASE
        WHEN SUM(IRI.Net) <= 0
            THEN N'Invoice request value is zero or negative and cannot be converted into a transaction.'
        ELSE N''
    END AS BatchingIssueMessage,
	OrgUnit.Name AS Department,
	OrgUnit2.Name AS BusinessUnit
FROM SFin.InvoiceRequests AS ir
JOIN SJob.Jobs AS j
    ON j.ID = ir.JobId
JOIN SCore.Identities AS i
    ON i.ID = ir.RequesterUserId
JOIN SCore.OrganisationalUnits AS OrgUnit
    ON OrgUnit.ID = j.OrganisationalUnitID
JOIN SCore.OrganisationalUnits AS OrgUnit2
	ON OrgUnit.ParentID = OrgUnit2.ID
INNER JOIN SFin.InvoiceRequestItems AS IRI
    ON IRI.InvoiceRequestId = ir.ID
INNER JOIN SJob.Activities AS Act
    ON IRI.ActivityId = Act.ID
INNER JOIN SJob.ActivityTypes AS ActT
    ON Act.ActivityTypeID = ActT.ID
INNER JOIN SCrm.Accounts AS Acc
    ON Acc.ID = j.ClientAccountID
LEFT JOIN SCrm.Accounts AS FinAcc
    ON FinAcc.ID = j.FinanceAccountID
WHERE
    ir.RowStatus NOT IN (0, 254)
    AND ir.ID > 0
    AND j.CannotBeInvoiced <> 1
    AND ir.IsMerged = 0
    AND ir.isWIP = 1
    AND EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequestItems AS iri
        WHERE iri.RowStatus NOT IN (0, 254)
          AND iri.InvoiceRequestId = ir.ID
    )
    AND
    (
        EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceRequestItems AS iri
            INNER JOIN SJob.Activities AS act
                ON iri.ActivityId = act.ID
            WHERE (act.ActivityStatusID = 3 OR act.ID < 0)
              AND iri.InvoiceRequestId = ir.ID
              AND iri.RowStatus NOT IN (0, 254)
              AND act.RowStatus NOT IN (0, 254)
        )
        OR IRI.ActivityId < 0
    )
    AND
    (
        EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceRequestItems AS iri
            INNER JOIN SJob.Activities AS Act
                ON iri.ActivityId = Act.ID
            WHERE iri.RowStatus NOT IN (0, 254)
              AND Act.RowStatus NOT IN (0, 254)
              AND CAST(Act.EndDate AS date) <= CAST(GETDATE() AS date)
              AND iri.InvoiceRequestId = ir.ID
        )
        OR IRI.ActivityId < 0
    )
    AND EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
    )
    AND EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(ir.Guid, @UserId) AS oscr
    )
   AND NOT EXISTS
    (
        SELECT 1
        FROM SFin.TransactionDetails AS td
        INNER JOIN SFin.InvoiceRequestItems AS iri
            ON iri.ID = td.InvoiceRequestItemId
        INNER JOIN SFin.Transactions AS tr
            ON tr.ID = td.TransactionID
        WHERE iri.InvoiceRequestId = ir.ID
          AND td.RowStatus NOT IN (0, 254)
          AND iri.RowStatus NOT IN (0, 254)
          AND tr.RowStatus NOT IN (0, 254, 200)
    )
GROUP BY
    ir.ID,
    ir.RowStatus,
    ir.RowVersion,
    ir.Guid,
    ir.Notes,
    ir.WIPReason,
    ir.CreatedDateTimeUTC,
    ir.InvoicingType,
    ir.ExpectedDate,
    ir.ManualStatus,
    i.Guid,
    i.FullName,
    j.Guid,
    j.Number,
    j.FinanceAccountID,
    FinAcc.Name,
    FinAcc.Code,
    Acc.Name,
    j.BillingInstruction,
    FinAcc.BillingInstruction,
    OrgUnit.Name,
	OrgUnit2.Name
GO
/*
    CYB-389: show the WIP reason in the Finance "Invoice Requests (WIP)" grid.

    SFin.tvf_InvoiceRequestsWIP now returns ir.WIPReason; this adds the matching grid column to
    the INVOICEREQUESTSWIP grid view. Idempotent and Guid-only:
      - grid view   INVOICEREQUESTSWIP  FC756AD7-E56E-40F0-85E0-0F4408544C4B
      - column      WIPReason           B29C12D0-2DB9-4517-BBF5-5C28A3769DD5 (new, stable)
      - label       reuses the form field's "WIP - Reason" label
                    [SFin].[InvoiceRequests].[WIPReason] 86FE124C-ECE6-4744-A8FF-5602710F19F7
    The column and its SCore.DataObjects row are created together by
    SUserInterface.GridViewColumnDefinitionUpsert (SCore.UpsertDataObject).

    Apply to DEV first; it is promoted with the rest of the metadata by the metadata migration.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @GridViewGuid    UNIQUEIDENTIFIER = 'FC756AD7-E56E-40F0-85E0-0F4408544C4B',
        @ColumnGuid      UNIQUEIDENTIFIER = 'B29C12D0-2DB9-4517-BBF5-5C28A3769DD5',
        @LabelGuid       UNIQUEIDENTIFIER = '86FE124C-ECE6-4744-A8FF-5602710F19F7';

IF NOT EXISTS (SELECT 1 FROM SUserInterface.GridViewDefinitions WHERE [Guid] = @GridViewGuid AND RowStatus NOT IN (0, 254))
BEGIN
    ;THROW 60389, N'CYB-389: grid view INVOICEREQUESTSWIP (FC756AD7-...) not found.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM SCore.LanguageLabels WHERE [Guid] = @LabelGuid AND RowStatus NOT IN (0, 254))
BEGIN
    ;THROW 60389, N'CYB-389: language label [SFin].[InvoiceRequests].[WIPReason] (86FE124C-...) not found.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM   SUserInterface.GridViewColumnDefinitions AS c
    JOIN   SUserInterface.GridViewDefinitions AS gvd ON (gvd.ID = c.GridViewDefinitionId)
    WHERE  (gvd.[Guid] = @GridViewGuid)
       AND (c.Name = N'WIPReason')
       AND (c.[Guid] <> @ColumnGuid)
       AND (c.RowStatus NOT IN (0, 254))
)
BEGIN
    ;THROW 60389, N'CYB-389: a different WIPReason column already exists on INVOICEREQUESTSWIP.', 1;
END;

BEGIN TRANSACTION;

-- Upsert by stable Guid: inserts on first run, re-applies the same values on later runs.
EXEC SUserInterface.GridViewColumnDefinitionUpsert
    @Name                   = N'WIPReason',
    @RowStatus              = 1,
    @GridViewDefinitionGuid = @GridViewGuid,
    @ColumnOrder            = 4,        -- beside Notes
    @IsPrimaryKey           = 0,
    @IsHidden               = 0,
    @IsFiltered             = 1,
    @IsCombo                = 0,
    @DisplayFormat          = N'',
    @Width                  = N'',
    @LanguageLabelGuid      = @LabelGuid,
    @Guid                   = @ColumnGuid OUTPUT,
    @TopHeaderCategory      = N'',
    @TopHeaderCategoryOrder = 0;

COMMIT TRANSACTION;

SELECT  c.[Guid], c.Name, c.ColumnOrder, c.IsHidden, c.IsFiltered, ll.Name AS Label,
        CASE WHEN dob.[Guid] IS NULL THEN 'MISSING DataObject' ELSE 'OK' END AS DataObject
FROM    SUserInterface.GridViewColumnDefinitions AS c
JOIN    SCore.LanguageLabels AS ll ON (ll.ID = c.LanguageLabelId)
LEFT JOIN SCore.DataObjects AS dob ON (dob.[Guid] = c.[Guid])
WHERE   (c.[Guid] = @ColumnGuid);
GO
