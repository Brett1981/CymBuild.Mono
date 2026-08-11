SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApplyPreviewFingerprint_Get]')
GO

CREATE PROCEDURE [SMigration].[MetadataApplyPreviewFingerprint_Get]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ApplySelectedOnly BIT = 0,
    @SourceSnapshotFingerprint VARCHAR(64),
    @TargetSnapshotFingerprint VARCHAR(64),
    @PreviewFingerprint VARBINARY(32) OUTPUT,
    @ScopeFingerprint VARBINARY(32) OUTPUT,
    @ApplyCount INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @ValidatedOnUtc DATETIME2,
        @SourceSnapshotFingerprintBinary VARBINARY(32),
        @TargetSnapshotFingerprintBinary VARBINARY(32),
        @SourceSnapshotFingerprintHex VARCHAR(64),
        @TargetSnapshotFingerprintHex VARCHAR(64),
        @ScopeFingerprintHex VARCHAR(64),
        @FingerprintRows NVARCHAR(MAX),
        @ScopeFingerprintEnvelope NVARCHAR(MAX),
        @DeploymentFingerprintEnvelope NVARCHAR(MAX);

    IF LEN(ISNULL(@SourceSnapshotFingerprint, '')) <> 64
        THROW 52918, 'A valid 64-character source snapshot fingerprint is required.', 1;

    SET @SourceSnapshotFingerprintBinary = TRY_CONVERT(VARBINARY(32), @SourceSnapshotFingerprint, 2);

    IF @SourceSnapshotFingerprintBinary IS NULL
        THROW 52918, 'A valid hexadecimal source snapshot fingerprint is required.', 1;

    IF LEN(ISNULL(@TargetSnapshotFingerprint, '')) <> 64
        THROW 52919, 'A valid 64-character target snapshot fingerprint is required.', 1;

    SET @TargetSnapshotFingerprintBinary = TRY_CONVERT(VARBINARY(32), @TargetSnapshotFingerprint, 2);

    IF @TargetSnapshotFingerprintBinary IS NULL
        THROW 52919, 'A valid hexadecimal target snapshot fingerprint is required.', 1;

    SET @SourceSnapshotFingerprintHex = CONVERT(VARCHAR(64), @SourceSnapshotFingerprintBinary, 2);
    SET @TargetSnapshotFingerprintHex = CONVERT(VARCHAR(64), @TargetSnapshotFingerprintBinary, 2);

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName,
        @ValidatedOnUtc = r.ValidatedOnUtc
    FROM SMigration.Metadata_Run AS r WITH (HOLDLOCK)
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52910, 'Metadata apply preview fingerprint could not find the selected run.', 1;

    IF OBJECT_ID(N'tempdb..#MetadataApplyPreviewFingerprintRows') IS NOT NULL
        DROP TABLE #MetadataApplyPreviewFingerprintRows;

    CREATE TABLE #MetadataApplyPreviewFingerprintRows
    (
        ApplyOrder INT NOT NULL,
        RegistryGuid UNIQUEIDENTIFIER NOT NULL,
        SourceRowGuid UNIQUEIDENTIFIER NOT NULL,
        RowFingerprint VARCHAR(64) NOT NULL,
        CONSTRAINT PK_MetadataApplyPreviewFingerprintRows PRIMARY KEY CLUSTERED
        (
            ApplyOrder,
            RegistryGuid,
            SourceRowGuid
        )
    );

    INSERT INTO #MetadataApplyPreviewFingerprintRows
    (
        ApplyOrder,
        RegistryGuid,
        SourceRowGuid,
        RowFingerprint
    )
    SELECT
        tr.ApplyOrder,
        sr.RegistryGuid,
        sr.SourceRowGuid,
        CONVERT
        (
            VARCHAR(64),
            HASHBYTES
            (
                'SHA2_256',
                CONVERT
                (
                    NVARCHAR(MAX),
                    CONCAT
                    (
                        N'schema=', tr.SchemaName,
                        N'|table=', tr.TableName,
                        N'|applyOrder=', CONVERT(NVARCHAR(20), tr.ApplyOrder),
                        N'|registryGuid=', CONVERT(NVARCHAR(36), sr.RegistryGuid),
                        N'|sourceRowGuid=', CONVERT(NVARCHAR(36), sr.SourceRowGuid),
                        N'|sourceRowId=', ISNULL(CONVERT(NVARCHAR(30), sr.SourceRowId), N'<null>'),
                        N'|sourceRowStatus=', ISNULL(CONVERT(NVARCHAR(10), sr.SourceRowStatus), N'<null>'),
                        N'|differenceType=', sr.DifferenceType,
                        N'|sourcePayloadHash=', CONVERT(VARCHAR(64), sr.SourcePayloadHash, 2),
                        N'|targetPayloadHash=', ISNULL(CONVERT(VARCHAR(64), sr.TargetPayloadHash, 2), N'<null>')
                    )
                )
            ),
            2
        )
    FROM SMigration.Metadata_StagedRows AS sr WITH (HOLDLOCK)
    INNER JOIN SMigration.Metadata_TableRegistry AS tr WITH (HOLDLOCK)
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND
      (
          ISNULL(@ApplySelectedOnly, 0) = 0
          OR EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_RunSelections AS selection WITH (HOLDLOCK)
              WHERE selection.RunGuid = sr.RunGuid
                AND selection.RegistryGuid = sr.RegistryGuid
                AND selection.SourceRowGuid = sr.SourceRowGuid
                AND selection.RowStatus NOT IN (0,254)
          )
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored WITH (HOLDLOCK)
          WHERE ignored.DatabaseName = @TargetDatabaseName
            AND ignored.RegistryGuid = sr.RegistryGuid
            AND ignored.SourceRowGuid = sr.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IdentityMapOverrides AS identityOverride WITH (HOLDLOCK)
          WHERE identityOverride.DatabaseName = @TargetDatabaseName
            AND identityOverride.RegistryGuid = sr.RegistryGuid
            AND identityOverride.SourceRowGuid = sr.SourceRowGuid
            AND identityOverride.RowStatus NOT IN (0,254)
      );

    SET @ApplyCount = @@ROWCOUNT;

    SELECT
        @FingerprintRows = STRING_AGG(CONVERT(NVARCHAR(MAX), rowsToHash.RowFingerprint), N'|')
            WITHIN GROUP
            (
                ORDER BY
                    rowsToHash.ApplyOrder,
                    rowsToHash.RegistryGuid,
                    rowsToHash.SourceRowGuid
            )
    FROM #MetadataApplyPreviewFingerprintRows AS rowsToHash;

    SELECT
        @ScopeFingerprintEnvelope =
        (
            SELECT
                CONVERT(NVARCHAR(36), @RunGuid) AS runGuid,
                @TargetDatabaseName AS targetDatabaseName,
                CONVERT(INT, ISNULL(@ApplySelectedOnly, 0)) AS applySelectedOnly,
                CONVERT(NVARCHAR(33), @ValidatedOnUtc, 126) AS validatedOnUtc,
                @ApplyCount AS applyCount,
                ISNULL(@FingerprintRows, N'') AS rowFingerprints
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

    SET @ScopeFingerprint = HASHBYTES('SHA2_256', @ScopeFingerprintEnvelope);
    SET @ScopeFingerprintHex = CONVERT(VARCHAR(64), @ScopeFingerprint, 2);

    SET @DeploymentFingerprintEnvelope = CONVERT
    (
        NVARCHAR(MAX),
        CONCAT
        (
            N'scope=', @ScopeFingerprintHex,
            N'|source=', @SourceSnapshotFingerprintHex,
            N'|target=', @TargetSnapshotFingerprintHex
        )
    );

    SET @PreviewFingerprint = HASHBYTES('SHA2_256', @DeploymentFingerprintEnvelope);
END;
GO
