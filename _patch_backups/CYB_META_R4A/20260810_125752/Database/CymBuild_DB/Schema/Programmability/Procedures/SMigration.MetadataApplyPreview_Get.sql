SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApplyPreview_Get]')
GO

CREATE PROCEDURE [SMigration].[MetadataApplyPreview_Get]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ApplySelectedOnly BIT = 0,
    @IncludeIgnored BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @RunFailureCount INT = 0,
        @PreviewFingerprint VARBINARY(32),
        @PreviewFingerprintHex VARCHAR(64),
        @PreviewApplyCount INT = 0,
        @AcceptedOnUtc DATETIME2,
        @AcceptedByUserId INT = -1,
        @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    BEGIN TRANSACTION;

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52300, 'Metadata apply preview could not find the selected run.', 1;

    SELECT
        @RunFailureCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail';

    EXEC SMigration.MetadataApplyPreviewFingerprint_Get
        @RunGuid = @RunGuid,
        @ApplySelectedOnly = @ApplySelectedOnly,
        @PreviewFingerprint = @PreviewFingerprint OUTPUT,
        @ApplyCount = @PreviewApplyCount OUTPUT;

    SET @PreviewFingerprintHex = CONVERT(VARCHAR(64), @PreviewFingerprint, 2);

    SELECT
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowGuid,
        ISNULL(sr.SourceRowId, -1) AS SourceRowId,
        sr.DifferenceType,
        CONVERT(BIT, CASE WHEN sel.Guid IS NULL THEN 0 ELSE 1 END) AS IsSelected,
        CONVERT(BIT, CASE WHEN ign.Guid IS NULL THEN 0 ELSE 1 END) AS IsIgnored,
        CONVERT(BIT, CASE WHEN @RunFailureCount > 0 THEN 1 ELSE 0 END) AS HasValidationFailure,
        CASE
            WHEN @RunFailureCount > 0 THEN N'Blocked'
            WHEN ign.Guid IS NOT NULL THEN N'Skip'
            WHEN ov.Guid IS NOT NULL THEN N'Skip'
            WHEN ISNULL(@ApplySelectedOnly, 0) = 1 AND sel.Guid IS NULL THEN N'Skip'
            ELSE N'Apply'
        END AS ApplyAction,
        CASE
            WHEN @RunFailureCount > 0 THEN N'Run has validation failure(s).'
            WHEN ign.Guid IS NOT NULL THEN N'Record is ignored for this target database.'
            WHEN ov.Guid IS NOT NULL THEN N'Record has a manual identity-map target match and will not be blindly inserted by automated apply.'
            WHEN ISNULL(@ApplySelectedOnly, 0) = 1 AND sel.Guid IS NULL THEN N'Not selected in this run.'
            ELSE N''
        END AS SkipReason,
        ISNULL(changed.ChangedColumns, N'') AS ChangedColumns,
        @RunFailureCount AS RunValidationFailureCount
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_RunSelections AS sel
        ON sel.RunGuid = sr.RunGuid
       AND sel.RegistryGuid = sr.RegistryGuid
       AND sel.SourceRowGuid = sr.SourceRowGuid
       AND sel.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IgnoredRecords AS ign
        ON ign.DatabaseName = @TargetDatabaseName
       AND ign.RegistryGuid = sr.RegistryGuid
       AND ign.SourceRowGuid = sr.SourceRowGuid
       AND ign.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = sr.RegistryGuid
       AND ov.SourceRowGuid = sr.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            STRING_AGG(CONVERT(NVARCHAR(MAX), diff.ColumnName), N', ') AS ChangedColumns
        FROM
        (
            SELECT
                COALESCE(src.[key], tgt.[key]) AS ColumnName
            FROM OPENJSON(ISNULL(sr.SourcePayloadJson, N'{}')) AS src
            FULL OUTER JOIN OPENJSON(ISNULL(sr.TargetPayloadJson, N'{}')) AS tgt
                ON tgt.[key] = src.[key]
            WHERE ISNULL(CONVERT(NVARCHAR(MAX), src.[value]), N'') <> ISNULL(CONVERT(NVARCHAR(MAX), tgt.[value]), N'')
        ) AS diff
    ) AS changed
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND (ISNULL(@ApplySelectedOnly, 0) = 0 OR sel.Guid IS NOT NULL)
      AND (ISNULL(@IncludeIgnored, 0) = 1 OR ign.Guid IS NULL)
    ORDER BY
        CASE
            WHEN @RunFailureCount > 0 THEN 0
            WHEN ign.Guid IS NOT NULL THEN 3
            WHEN ov.Guid IS NOT NULL THEN 2
            ELSE 1
        END,
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowId;

    SELECT TOP (1)
        @AcceptedOnUtc = el.CreatedOnUtc,
        @AcceptedByUserId = ISNULL(TRY_CONVERT(INT, JSON_VALUE(el.DetailsJson, '$.acceptedByUserId')), -1)
    FROM SMigration.Metadata_ExecutionLog AS el
    WHERE el.RunGuid = @RunGuid
      AND el.RowStatus NOT IN (0,254)
      AND el.StepName = N'ApplyPreviewAcceptance'
      AND el.StepStatus = N'Accepted'
      AND JSON_VALUE(el.DetailsJson, '$.previewFingerprint') = @PreviewFingerprintHex
      AND TRY_CONVERT(INT, JSON_VALUE(el.DetailsJson, '$.applySelectedOnly')) = CONVERT(INT, ISNULL(@ApplySelectedOnly, 0))
    ORDER BY el.ID DESC;

    COMMIT TRANSACTION;

    SELECT
        @PreviewFingerprintHex AS PreviewFingerprint,
        @PreviewApplyCount AS PreviewApplyCount,
        CONVERT(BIT, CASE WHEN @AcceptedOnUtc IS NULL THEN 0 ELSE 1 END) AS IsAccepted,
        @AcceptedOnUtc AS AcceptedOnUtc,
        @AcceptedByUserId AS AcceptedByUserId;
END;
GO
