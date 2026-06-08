SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataStage_NormaliseDifferences]')
GO

/*
    CymBuild Metadata CI/CD
    Stage/Diff normalisation fix

    Purpose:
    - Keep raw SourcePayloadJson / TargetPayloadJson for audit.
    - Stop Stage/Diff reporting false inserts where Apply intentionally reuses
      an existing target row by natural key.
    - Stop Stage/Diff reporting false updates caused only by environment-specific
      numeric IDs/FKs.

    Required call point:
    - Execute SMigration.MetadataStage_NormaliseDifferences after all
      SMigration.Metadata_StagedRows have been inserted for a run and before
      SummaryJson is calculated/read by the UI.

    Works for:
    - same-server SQL proc staging
    - API two-connection staging, provided the API calls this proc after staging
*/

CREATE PROCEDURE [SMigration].[MetadataStage_NormaliseDifferences]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_Run AS r
        WHERE r.Guid = @RunGuid
          AND r.RowStatus NOT IN (0,254)
    )
    BEGIN
        THROW 53000, 'Metadata stage normalisation failed because the run was not found or is inactive.', 1;
    END;

    DECLARE
        @EntityPropertiesColumnList NVARCHAR(MAX),
        @GridViewColumnDefinitionsColumnList NVARCHAR(MAX),
        @IconsColumnList NVARCHAR(MAX),
        @Sql NVARCHAR(MAX);

    /* =========================================================
       1. Convert false inserts to natural-key target matches.
          These remain Update/NoChange based on the real target payload.
       ========================================================= */

    SELECT
        @EntityPropertiesColumnList = STRING_AGG(CONVERT(NVARCHAR(MAX), N'epj.' + QUOTENAME(c.name)), N',')
            WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = N'SCore'
      AND t.name = N'EntityProperties'
      AND c.is_computed = 0
      AND c.system_type_id <> 189;

    IF @EntityPropertiesColumnList IS NOT NULL
    BEGIN
        SET @Sql = N'
;WITH EntityPropertiesToNaturalise AS
(
    SELECT
        sr.ID AS StagedRowID,
        targetEp.ID AS TargetEntityPropertyID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            TRY_CONVERT(BIGINT, COALESCE
            (
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHoBTID''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHoBTId''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHobtID''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHobtId'')
            )) AS SourceEntityHoBTID,
            JSON_VALUE(sr.SourcePayloadJson, N''$.Name'') AS PropertyName
    ) AS parsed
    LEFT JOIN SMigration.Metadata_TableRegistry AS hobtReg
        ON hobtReg.SchemaName = N''SCore''
       AND hobtReg.TableName = N''EntityHobts''
       AND hobtReg.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_StagedRows AS srcHobt
        ON srcHobt.RunGuid = sr.RunGuid
       AND srcHobt.RegistryGuid = hobtReg.Guid
       AND srcHobt.SourceRowId = parsed.SourceEntityHoBTID
       AND srcHobt.RowStatus NOT IN (0,254)
    LEFT JOIN SCore.EntityHobts AS targetHobt
        ON targetHobt.Guid = srcHobt.SourceRowGuid
       AND targetHobt.RowStatus NOT IN (0,254)
    LEFT JOIN SCore.EntityProperties AS targetEp
        ON targetEp.EntityHoBTID = targetHobt.ID
       AND targetEp.Name = parsed.PropertyName
       AND targetEp.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N''Insert''
      AND tr.SchemaName = N''SCore''
      AND tr.TableName = N''EntityProperties''
      AND targetEp.ID IS NOT NULL
)
UPDATE sr
SET
    TargetPayloadJson = tgt.TargetPayloadJson,
    TargetPayloadHash = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)),
    DifferenceType = CASE
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), sr.SourcePayloadJson))
           = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''NoChange''
        ELSE N''Update''
    END
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN EntityPropertiesToNaturalise AS n
    ON n.StagedRowID = sr.ID
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @EntityPropertiesColumnList + N'
            FROM SCore.EntityProperties AS epj
            WHERE epj.ID = n.TargetEntityPropertyID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt
WHERE tgt.TargetPayloadJson IS NOT NULL;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;
    END;

    SELECT
        @GridViewColumnDefinitionsColumnList = STRING_AGG(CONVERT(NVARCHAR(MAX), N'gvcdj.' + QUOTENAME(c.name)), N',')
            WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = N'SUserInterface'
      AND t.name = N'GridViewColumnDefinitions'
      AND c.is_computed = 0
      AND c.system_type_id <> 189;

    IF @GridViewColumnDefinitionsColumnList IS NOT NULL
    BEGIN
        SET @Sql = N'
;WITH GridViewColumnsToNaturalise AS
(
    SELECT
        sr.ID AS StagedRowID,
        targetCol.ID AS TargetGridViewColumnDefinitionID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            TRY_CONVERT(BIGINT, COALESCE
            (
                JSON_VALUE(sr.SourcePayloadJson, N''$.GridViewDefinitionID''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.GridViewDefinitionId'')
            )) AS SourceGridViewDefinitionID,
            JSON_VALUE(sr.SourcePayloadJson, N''$.Name'') AS ColumnName,
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N''$.IsPrimaryKey'')) AS IsPrimaryKey
    ) AS parsed
    LEFT JOIN SMigration.Metadata_TableRegistry AS gvdReg
        ON gvdReg.SchemaName = N''SUserInterface''
       AND gvdReg.TableName = N''GridViewDefinitions''
       AND gvdReg.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_StagedRows AS srcGvd
        ON srcGvd.RunGuid = sr.RunGuid
       AND srcGvd.RegistryGuid = gvdReg.Guid
       AND srcGvd.SourceRowId = parsed.SourceGridViewDefinitionID
       AND srcGvd.RowStatus NOT IN (0,254)
    LEFT JOIN SUserInterface.GridViewDefinitions AS targetGvd
        ON targetGvd.Guid = srcGvd.SourceRowGuid
       AND targetGvd.RowStatus NOT IN (0,254)
    LEFT JOIN SUserInterface.GridViewColumnDefinitions AS targetCol
        ON targetCol.GridViewDefinitionID = targetGvd.ID
       AND targetCol.RowStatus NOT IN (0,254)
       AND
       (
            targetCol.Name = parsed.ColumnName
            OR
            (
                ISNULL(parsed.IsPrimaryKey, 0) = 1
                AND targetCol.IsPrimaryKey = 1
            )
       )
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N''Insert''
      AND tr.SchemaName = N''SUserInterface''
      AND tr.TableName = N''GridViewColumnDefinitions''
      AND targetCol.ID IS NOT NULL
)
UPDATE sr
SET
    TargetPayloadJson = tgt.TargetPayloadJson,
    TargetPayloadHash = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)),
    DifferenceType = CASE
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), sr.SourcePayloadJson))
           = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''NoChange''
        ELSE N''Update''
    END
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN GridViewColumnsToNaturalise AS n
    ON n.StagedRowID = sr.ID
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @GridViewColumnDefinitionsColumnList + N'
            FROM SUserInterface.GridViewColumnDefinitions AS gvcdj
            WHERE gvcdj.ID = n.TargetGridViewColumnDefinitionID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt
WHERE tgt.TargetPayloadJson IS NOT NULL;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;
    END;

    SELECT
        @IconsColumnList = STRING_AGG(CONVERT(NVARCHAR(MAX), N'ij.' + QUOTENAME(c.name)), N',')
            WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = N'SUserInterface'
      AND t.name = N'Icons'
      AND c.is_computed = 0
      AND c.system_type_id <> 189;

    IF @IconsColumnList IS NOT NULL
    BEGIN
        SET @Sql = N'
;WITH IconsToNaturalise AS
(
    SELECT
        sr.ID AS StagedRowID,
        targetIcon.ID AS TargetIconID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT JSON_VALUE(sr.SourcePayloadJson, N''$.Name'') AS IconName
    ) AS parsed
    LEFT JOIN SUserInterface.Icons AS targetIcon
        ON targetIcon.Name = parsed.IconName
       AND targetIcon.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N''Insert''
      AND tr.SchemaName = N''SUserInterface''
      AND tr.TableName = N''Icons''
      AND targetIcon.ID IS NOT NULL
)
UPDATE sr
SET
    TargetPayloadJson = tgt.TargetPayloadJson,
    TargetPayloadHash = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)),
    DifferenceType = CASE
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), sr.SourcePayloadJson))
           = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''NoChange''
        ELSE N''Update''
    END
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN IconsToNaturalise AS n
    ON n.StagedRowID = sr.ID
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @IconsColumnList + N'
            FROM SUserInterface.Icons AS ij
            WHERE ij.ID = n.TargetIconID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt
WHERE tgt.TargetPayloadJson IS NOT NULL;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;
    END;

    /* =========================================================
       2. Normalise false updates caused by environment-specific IDs.
          This keeps relationship drift visible only where a stable, non-ID
          metadata value differs. Raw payloads remain available for audit.
       ========================================================= */

    IF OBJECT_ID(N'tempdb..#MetadataNormalisedDiff') IS NOT NULL
        DROP TABLE #MetadataNormalisedDiff;

    CREATE TABLE #MetadataNormalisedDiff
    (
        StagedRowID BIGINT NOT NULL PRIMARY KEY,
        SourceNormalisedHash VARBINARY(32) NULL,
        TargetNormalisedHash VARBINARY(32) NULL
    );

    ;WITH SourceNormalised AS
    (
        SELECT
            sr.ID AS StagedRowID,
            HASHBYTES
            (
                'SHA2_256',
                CONVERT
                (
                    VARBINARY(MAX),
                    STRING_AGG
                    (
                        CONVERT(NVARCHAR(MAX), CONCAT(j.[key], N'=', ISNULL(j.[value], N'<NULL>'))),
                        N'|'
                    ) WITHIN GROUP (ORDER BY j.[key])
                )
            ) AS NormalisedHash
        FROM SMigration.Metadata_StagedRows AS sr
        CROSS APPLY OPENJSON(sr.SourcePayloadJson) AS j
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType = N'Update'
          AND sr.TargetPayloadJson IS NOT NULL
          AND j.[key] NOT IN
          (
              N'ID',
              N'EntityTypeID', N'EntityTypeId',
              N'EntityHoBTID', N'EntityHoBTId', N'EntityHobtID', N'EntityHobtId',
              N'LanguageLabelID', N'LanguageLabelId',
              N'LanguageID', N'LanguageId',
              N'EntityDataTypeID', N'EntityDataTypeId',
              N'EntityPropertyGroupID', N'EntityPropertyGroupId',
              N'DropDownListDefinitionID', N'DropDownListDefinitionId',
              N'EntityQueryID', N'EntityQueryId',
              N'MappedEntityPropertyID', N'MappedEntityPropertyId',
              N'GridDefinitionID', N'GridDefinitionId',
              N'GridViewDefinitionID', N'GridViewDefinitionId',
              N'MetricTypeID', N'MetricTypeId',
              N'DrawerIconID', N'DrawerIconId',
              N'GridViewTypeID', N'GridViewTypeId',
              N'IconID', N'IconId',
              N'PropertyGroupLayoutID', N'PropertyGroupLayoutId'
          )
        GROUP BY sr.ID
    ),
    TargetNormalised AS
    (
        SELECT
            sr.ID AS StagedRowID,
            HASHBYTES
            (
                'SHA2_256',
                CONVERT
                (
                    VARBINARY(MAX),
                    STRING_AGG
                    (
                        CONVERT(NVARCHAR(MAX), CONCAT(j.[key], N'=', ISNULL(j.[value], N'<NULL>'))),
                        N'|'
                    ) WITHIN GROUP (ORDER BY j.[key])
                )
            ) AS NormalisedHash
        FROM SMigration.Metadata_StagedRows AS sr
        CROSS APPLY OPENJSON(sr.TargetPayloadJson) AS j
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType = N'Update'
          AND sr.TargetPayloadJson IS NOT NULL
          AND j.[key] NOT IN
          (
              N'ID',
              N'EntityTypeID', N'EntityTypeId',
              N'EntityHoBTID', N'EntityHoBTId', N'EntityHobtID', N'EntityHobtId',
              N'LanguageLabelID', N'LanguageLabelId',
              N'LanguageID', N'LanguageId',
              N'EntityDataTypeID', N'EntityDataTypeId',
              N'EntityPropertyGroupID', N'EntityPropertyGroupId',
              N'DropDownListDefinitionID', N'DropDownListDefinitionId',
              N'EntityQueryID', N'EntityQueryId',
              N'MappedEntityPropertyID', N'MappedEntityPropertyId',
              N'GridDefinitionID', N'GridDefinitionId',
              N'GridViewDefinitionID', N'GridViewDefinitionId',
              N'MetricTypeID', N'MetricTypeId',
              N'DrawerIconID', N'DrawerIconId',
              N'GridViewTypeID', N'GridViewTypeId',
              N'IconID', N'IconId',
              N'PropertyGroupLayoutID', N'PropertyGroupLayoutId'
          )
        GROUP BY sr.ID
    )
    INSERT INTO #MetadataNormalisedDiff
    (
        StagedRowID,
        SourceNormalisedHash,
        TargetNormalisedHash
    )
    SELECT
        sr.ID,
        sn.NormalisedHash,
        tn.NormalisedHash
    FROM SMigration.Metadata_StagedRows AS sr
    LEFT JOIN SourceNormalised AS sn
        ON sn.StagedRowID = sr.ID
    LEFT JOIN TargetNormalised AS tn
        ON tn.StagedRowID = sr.ID
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND sr.TargetPayloadJson IS NOT NULL;

    UPDATE sr
    SET DifferenceType = N'NoChange'
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN #MetadataNormalisedDiff AS nd
        ON nd.StagedRowID = sr.ID
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND nd.SourceNormalisedHash = nd.TargetNormalisedHash;

    /* =========================================================
       3. Refresh run summary after normalisation.
       ========================================================= */

    UPDATE SMigration.Metadata_Run
    SET SummaryJson =
    (
        SELECT
            CONCAT
            (
                N'{"insertCount":',
                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Insert' THEN 1 ELSE 0 END), 0)),
                N',"updateCount":',
                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Update' THEN 1 ELSE 0 END), 0)),
                N',"noChangeCount":',
                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'NoChange' THEN 1 ELSE 0 END), 0)),
                N',"totalCount":',
                CONVERT(NVARCHAR(30), COUNT_BIG(1)),
                N'}'
            )
        FROM SMigration.Metadata_StagedRows AS sr
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
    )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);
END;
GO