SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIdentityMapDetails_List]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIdentityMapDetails_List]')
GO

CREATE PROCEDURE [SMigration].[MetadataIdentityMapDetails_List]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SchemaName NVARCHAR(128) = N'',
    @TableName NVARCHAR(128) = N'',
    @IncludeIgnored BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TargetDatabaseName SYSNAME;

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52300, 'Metadata identity map detail could not find the selected run.', 1;

    SELECT
        maprow.SchemaName,
        maprow.TableName,
        maprow.SourceRowGuid,
        ISNULL(maprow.SourceRowId, 0) AS SourceRowId,
        maprow.TargetRowId,
        ISNULL(sr.DifferenceType, N'') AS DifferenceType,
        COALESCE
        (
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.Name'), N''),
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.FullName'), N''),
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.Code'), N''),
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.Description'), N''),
            NULLIF(JSON_VALUE(sr.SourcePayloadJson, N'$.Title'), N''),
            CONVERT(NVARCHAR(36), maprow.SourceRowGuid)
        ) AS SourceDisplayName,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL AND ov.ID IS NOT NULL THEN N'ManualOverride'
            WHEN maprow.TargetRowId IS NOT NULL THEN N'Resolved'
            WHEN ign.ID IS NOT NULL THEN N'KnownIgnored'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Insert' THEN N'ExpectedInsert'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Update' THEN N'UnresolvedDependency'
            ELSE N'TargetMissing'
        END AS IssueCode,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL AND ov.ID IS NOT NULL THEN N'Mapped'
            WHEN maprow.TargetRowId IS NOT NULL THEN N'Resolved'
            WHEN ign.ID IS NOT NULL THEN N'Ignored'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Insert' THEN N'Expected insert'
            ELSE N'Review needed'
        END AS IssueStatus,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL AND ov.ID IS NOT NULL THEN N'Target row was resolved using a persistent manual mapping override.'
            WHEN maprow.TargetRowId IS NOT NULL THEN N'Target row was matched by stable Guid.'
            WHEN ign.ID IS NOT NULL THEN N'This missing target mapping has been acknowledged as acceptable for the selected target database.'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Insert' THEN N'Target row is not present because this source metadata row is staged as an insert for this run.'
            ELSE N'Source metadata row has no matching target row by stable Guid and is not classified as an expected insert.'
        END AS Reason,
        CASE
            WHEN maprow.TargetRowId IS NOT NULL AND ov.ID IS NOT NULL THEN N'Review override if needed. Future identity-map builds will use this mapping for the selected target database.'
            WHEN maprow.TargetRowId IS NOT NULL THEN N'No action required.'
            WHEN ign.ID IS NOT NULL THEN N'No action required unless this issue should be re-reviewed; unignore it to return it to review needed.'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Insert' THEN N'No identity-map action required if this is genuinely new metadata. Preview/apply will insert this row if it is included and not ignored. If this target already exists under a different Guid, select the row and map it to the existing target record.'
            WHEN ISNULL(sr.DifferenceType, N'') = N'Update' THEN N'Review target Guid alignment. Use manual mapping only when the source and target rows represent the same logical metadata record.'
            ELSE N'Review the staged metadata row and decide whether it should be included, ignored, manually mapped, or corrected before apply.'
        END AS SuggestedAction,
        CONVERT(BIT, CASE
            WHEN maprow.TargetRowId IS NOT NULL THEN 1
            WHEN ign.ID IS NULL AND ISNULL(sr.DifferenceType, N'') = N'Insert' THEN 1
            ELSE 0
        END) AS IsResolved,
        CONVERT(BIT, CASE WHEN ign.ID IS NULL THEN 0 ELSE 1 END) AS IsIgnoredIssue,
        ISNULL(ign.Reason, N'') AS IgnoreReason,
        CASE WHEN ign.IgnoredOnUtc IS NULL THEN N'' ELSE CONVERT(NVARCHAR(30), ign.IgnoredOnUtc, 126) END AS IgnoredOnUtc,
        ISNULL(sr.SourcePayloadJson, N'{}') AS SourcePayloadJson,
        CONVERT(BIT, CASE WHEN ov.ID IS NULL THEN 0 ELSE 1 END) AS HasOverride,
        CASE WHEN ov.TargetRowGuid IS NULL THEN N'' ELSE CONVERT(NVARCHAR(36), ov.TargetRowGuid) END AS OverrideTargetRowGuid,
        ISNULL(ov.TargetDisplayName, N'') AS OverrideTargetDisplayName,
        ISNULL(ov.Reason, N'') AS OverrideReason
    FROM SMigration.Metadata_ApplyIdentityMap AS maprow
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = maprow.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_StagedRows AS sr
        ON sr.RunGuid = maprow.RunGuid
       AND sr.RegistryGuid = maprow.RegistryGuid
       AND sr.SourceRowGuid = maprow.SourceRowGuid
       AND sr.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapIgnoredIssues AS ign
        ON ign.DatabaseName = @TargetDatabaseName
       AND ign.RegistryGuid = maprow.RegistryGuid
       AND ign.SourceRowGuid = maprow.SourceRowGuid
       AND ign.IssueCode = N'TargetMissing'
       AND ign.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_IdentityMapOverrides AS ov
        ON ov.DatabaseName = @TargetDatabaseName
       AND ov.RegistryGuid = maprow.RegistryGuid
       AND ov.SourceRowGuid = maprow.SourceRowGuid
       AND ov.RowStatus NOT IN (0,254)
    WHERE maprow.RunGuid = @RunGuid
      AND maprow.RowStatus NOT IN (0,254)
      AND (@SchemaName = N'' OR maprow.SchemaName = @SchemaName)
      AND (@TableName = N'' OR maprow.TableName = @TableName)
      AND (@IncludeIgnored = 1 OR ign.ID IS NULL)
    ORDER BY
        CASE
            WHEN maprow.TargetRowId IS NOT NULL THEN 4
            WHEN ign.ID IS NOT NULL THEN 3
            WHEN ISNULL(sr.DifferenceType, N'') = N'Insert' THEN 2
            ELSE 0
        END,
        maprow.SchemaName,
        maprow.TableName,
        ISNULL(maprow.SourceRowId, 0),
        maprow.SourceRowGuid;
END
GO