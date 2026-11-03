SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApplyPreview_Accept]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApplyPreview_Accept]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ApplySelectedOnly BIT = 1,
    @ExpectedPreviewFingerprint VARCHAR(64),
    @SourceSnapshotFingerprint VARCHAR(64),
    @TargetSnapshotFingerprint VARCHAR(64)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RunStatus NVARCHAR(30),
        @IsValidateOnly BIT,
        @TargetDatabaseName SYSNAME,
        @FailCount INT = 0,
        @PreviewFingerprint VARBINARY(32),
        @ScopeFingerprint VARBINARY(32),
        @ExpectedPreviewFingerprintBinary VARBINARY(32),
        @PreviewFingerprintHex VARCHAR(64),
        @ScopeFingerprintHex VARCHAR(64),
        @ApplyCount INT = 0,
        @AcceptedByUserId INT = ISNULL(SCore.GetCurrentUserId(), -1),
        @AcceptedOnUtc DATETIME2,
        @ExistingAcceptanceId BIGINT,
        @DetailsJson NVARCHAR(MAX),
        @Message NVARCHAR(2000);

    IF ISNULL(@ApplySelectedOnly, 0) <> 1
        THROW 52920, 'Metadata apply preview acceptance requires an explicit selected-row scope.', 1;

    IF LEN(ISNULL(@ExpectedPreviewFingerprint, '')) <> 64
        THROW 52911, 'A valid 64-character apply preview fingerprint is required for acceptance.', 1;

    SET @ExpectedPreviewFingerprintBinary = TRY_CONVERT(VARBINARY(32), @ExpectedPreviewFingerprint, 2);

    IF @ExpectedPreviewFingerprintBinary IS NULL
        THROW 52911, 'A valid hexadecimal apply preview fingerprint is required for acceptance.', 1;

    BEGIN TRANSACTION;

    SELECT
        @RunStatus = r.RunStatus,
        @IsValidateOnly = r.IsValidateOnly,
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r WITH (UPDLOCK, HOLDLOCK)
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @RunStatus IS NULL
        THROW 52912, 'Metadata apply preview acceptance could not find the selected run.', 1;

    IF ISNULL(@IsValidateOnly, 1) = 1
        THROW 52913, 'Validate-only metadata runs cannot be accepted for deployment.', 1;

    IF @RunStatus NOT IN
    (
        N'Validated',
        N'PartiallyApplied',
        N'AppliedCoreMetadata',
        N'AppliedUiMetadata'
    )
        THROW 52914, 'Metadata apply preview acceptance requires a validated or retryable metadata run.', 1;

    SELECT
        @FailCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi WITH (HOLDLOCK)
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_ValidationIssueIgnores AS ignoredIssue WITH (HOLDLOCK)
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

    IF ISNULL(@FailCount, 0) > 0
        THROW 52915, 'Metadata apply preview cannot be accepted while validation failures exist.', 1;

    EXEC SMigration.MetadataApplyPreviewFingerprint_Get
        @RunGuid = @RunGuid,
        @ApplySelectedOnly = @ApplySelectedOnly,
        @SourceSnapshotFingerprint = @SourceSnapshotFingerprint,
        @TargetSnapshotFingerprint = @TargetSnapshotFingerprint,
        @PreviewFingerprint = @PreviewFingerprint OUTPUT,
        @ScopeFingerprint = @ScopeFingerprint OUTPUT,
        @ApplyCount = @ApplyCount OUTPUT;

    IF ISNULL(@ApplyCount, 0) = 0
        THROW 52916, 'Metadata apply preview acceptance requires at least one actionable metadata row.', 1;

    IF @PreviewFingerprint <> @ExpectedPreviewFingerprintBinary
        THROW 52917, 'The metadata apply preview changed before acceptance. Reload and review the current preview before accepting it for deployment.', 1;

    SET @PreviewFingerprintHex = CONVERT(VARCHAR(64), @PreviewFingerprint, 2);
    SET @ScopeFingerprintHex = CONVERT(VARCHAR(64), @ScopeFingerprint, 2);

    SELECT TOP (1)
        @ExistingAcceptanceId = el.ID,
        @AcceptedOnUtc = el.CreatedOnUtc,
        @AcceptedByUserId = ISNULL(TRY_CONVERT(INT, JSON_VALUE(el.DetailsJson, '$.acceptedByUserId')), -1)
    FROM SMigration.Metadata_ExecutionLog AS el WITH (HOLDLOCK)
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

    IF @ExistingAcceptanceId IS NULL
    BEGIN
        SET @AcceptedOnUtc = SYSUTCDATETIME();

        SELECT
            @DetailsJson =
            (
                SELECT
                    @PreviewFingerprintHex AS previewFingerprint,
                    @ScopeFingerprintHex AS scopeFingerprint,
                    UPPER(@SourceSnapshotFingerprint) AS sourceSnapshotFingerprint,
                    UPPER(@TargetSnapshotFingerprint) AS targetSnapshotFingerprint,
                    CONVERT(INT, ISNULL(@ApplySelectedOnly, 0)) AS applySelectedOnly,
                    @ApplyCount AS applyCount,
                    @AcceptedByUserId AS acceptedByUserId,
                    @AcceptedOnUtc AS acceptedOnUtc
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
            );

        EXEC SMigration.MetadataExecutionLog_Add
            @RunGuid = @RunGuid,
            @StepName = N'ApplyPreviewAcceptance',
            @StepStatus = N'Accepted',
            @Message = N'Metadata apply preview reviewed and accepted for deployment.',
            @DetailsJson = @DetailsJson;

        SET @Message = N'Metadata apply preview accepted for deployment.';
    END
    ELSE
    BEGIN
        SET @Message = N'This unchanged metadata apply preview is already accepted for deployment.';
    END;

    COMMIT TRANSACTION;

    SELECT
        CONVERT(BIT, 1) AS IsAccepted,
        CONVERT(BIT, ISNULL(@ApplySelectedOnly, 0)) AS ApplySelectedOnly,
        @PreviewFingerprintHex AS PreviewFingerprint,
        @ApplyCount AS ApplyCount,
        @AcceptedOnUtc AS AcceptedOnUtc,
        @AcceptedByUserId AS AcceptedByUserId,
        @Message AS Message;
END;
GO
