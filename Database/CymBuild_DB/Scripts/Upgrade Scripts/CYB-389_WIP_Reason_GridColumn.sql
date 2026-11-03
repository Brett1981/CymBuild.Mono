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
