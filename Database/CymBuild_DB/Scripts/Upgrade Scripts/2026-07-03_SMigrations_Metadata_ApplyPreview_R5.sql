/* CI/CD-safe idempotent SMigration apply preview deployment.
   R5: non-destructive apply preview/preflight for selected or all valid metadata rows.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApplyPreview_Get]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ApplySelectedOnly BIT = 0,
    @IncludeIgnored BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @RunFailureCount INT = 0,
        @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

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
            WHEN ISNULL(@ApplySelectedOnly, 0) = 1 AND sel.Guid IS NULL THEN N'Skip'
            ELSE N'Apply'
        END AS ApplyAction,
        CASE
            WHEN @RunFailureCount > 0 THEN N'Run has validation failure(s).'
            WHEN ign.Guid IS NOT NULL THEN N'Record is ignored for this target database.'
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
            WHEN ign.Guid IS NOT NULL THEN 2
            ELSE 1
        END,
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowId;
END;
GO

PRINT N'R5 metadata apply preview procedure deployed.';
GO
