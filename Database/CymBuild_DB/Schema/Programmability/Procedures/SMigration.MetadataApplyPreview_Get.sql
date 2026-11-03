SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApplyPreview_Get]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApplyPreview_Get]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ApplySelectedOnly BIT = 1,
    @IncludeIgnored BIT = 1,
    @SourceSnapshotFingerprint VARCHAR(64),
    @TargetSnapshotFingerprint VARCHAR(64)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISNULL(@ApplySelectedOnly, 0) <> 1
        THROW 52301, 'Metadata apply preview requires an explicit selected-row scope.', 1;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @RunFailureCount INT = 0,
        @PreviewFingerprint VARBINARY(32),
        @ScopeFingerprint VARBINARY(32),
        @PreviewFingerprintHex VARCHAR(64),
        @ScopeFingerprintHex VARCHAR(64),
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
      AND vi.Severity = N'Fail'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_ValidationIssueIgnores AS ignoredIssue
          WHERE ignoredIssue.DatabaseName = @TargetDatabaseName
            AND ignoredIssue.RegistryGuid = vi.RegistryGuid
            AND ignoredIssue.SourceRowGuid = vi.SourceRowGuid
            AND ignoredIssue.IssueCode = vi.IssueCode
            AND ignoredIssue.RowStatus NOT IN (0,254)
      )
      AND
      (
          vi.IssueCode IN (N'RunNotFound', N'NoSelectedRows', N'DuplicateSourceGuid', N'DuplicateTargetGuid', N'DuplicateTargetKey', N'UnresolvedReference')
          OR EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_RunSelections AS selected
              INNER JOIN SMigration.Metadata_StagedRows AS selectedRow
                  ON selectedRow.RunGuid = selected.RunGuid
                 AND selectedRow.RegistryGuid = selected.RegistryGuid
                 AND selectedRow.SourceRowGuid = selected.SourceRowGuid
                 AND selectedRow.RowStatus NOT IN (0,254)
              WHERE selected.RunGuid = vi.RunGuid
                AND selected.RowStatus NOT IN (0,254)
                AND selectedRow.DifferenceType IN (N'Insert', N'Update')
                AND selectedRow.RegistryGuid = vi.RegistryGuid
                AND (vi.SourceRowGuid IS NULL OR selectedRow.SourceRowGuid = vi.SourceRowGuid)
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SMigration.Metadata_IgnoredRecords AS selectedIgnored
                    WHERE selectedIgnored.DatabaseName = @TargetDatabaseName
                      AND selectedIgnored.RegistryGuid = selectedRow.RegistryGuid
                      AND selectedIgnored.SourceRowGuid = selectedRow.SourceRowGuid
                      AND selectedIgnored.RowStatus NOT IN (0,254)
                )
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SMigration.Metadata_IdentityMapOverrides AS selectedOverride
                    WHERE selectedOverride.DatabaseName = @TargetDatabaseName
                      AND selectedOverride.RegistryGuid = selectedRow.RegistryGuid
                      AND selectedOverride.SourceRowGuid = selectedRow.SourceRowGuid
                      AND selectedOverride.RowStatus NOT IN (0,254)
                )
          )
      );

    EXEC SMigration.MetadataApplyPreviewFingerprint_Get
        @RunGuid = @RunGuid,
        @ApplySelectedOnly = @ApplySelectedOnly,
        @SourceSnapshotFingerprint = @SourceSnapshotFingerprint,
        @TargetSnapshotFingerprint = @TargetSnapshotFingerprint,
        @PreviewFingerprint = @PreviewFingerprint OUTPUT,
        @ScopeFingerprint = @ScopeFingerprint OUTPUT,
        @ApplyCount = @PreviewApplyCount OUTPUT;

    SET @PreviewFingerprintHex = CONVERT(VARCHAR(64), @PreviewFingerprint, 2);
    SET @ScopeFingerprintHex = CONVERT(VARCHAR(64), @ScopeFingerprint, 2);

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
            ELSE N'Apply'
        END AS ApplyAction,
        CASE
            WHEN @RunFailureCount > 0 THEN N'Run has validation failure(s).'
            WHEN ign.Guid IS NOT NULL THEN N'Record is ignored for this target database.'
            WHEN ov.Guid IS NOT NULL THEN N'Record has a manual identity-map target match - applies as an update to that mapped target record.'
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
      AND sel.Guid IS NOT NULL
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
      AND JSON_VALUE(el.DetailsJson, '$.scopeFingerprint') = @ScopeFingerprintHex
      AND JSON_VALUE(el.DetailsJson, '$.sourceSnapshotFingerprint') = UPPER(@SourceSnapshotFingerprint)
      AND JSON_VALUE(el.DetailsJson, '$.targetSnapshotFingerprint') = UPPER(@TargetSnapshotFingerprint)
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
