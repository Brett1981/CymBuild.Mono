SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataStage_NormaliseEnvironmentOnlyUpdates]')
GO


CREATE PROCEDURE [SMigration].[MetadataStage_NormaliseEnvironmentOnlyUpdates]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        Converts staged rows from Update -> NoChange when the only changed JSON
        properties are environment-specific identity values:
          - ID / Guid
          - numeric FK columns whose target values legitimately differ between databases

        This does not alter SourcePayloadJson or TargetPayloadJson; it only suppresses
        false-positive DifferenceType values after the main stage comparison has already
        captured the full audit payloads.
    */

    ------------------------------------------------------------
    -- SCore.EntityProperties
    ------------------------------------------------------------
    UPDATE sr
    SET DifferenceType = N'NoChange'
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND sr.TargetPayloadJson IS NOT NULL
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityProperties'
      AND NOT EXISTS
      (
          SELECT 1
          FROM OPENJSON(sr.SourcePayloadJson) AS src
          FULL OUTER JOIN OPENJSON(sr.TargetPayloadJson) AS tgt
              ON tgt.[key] COLLATE DATABASE_DEFAULT = src.[key] COLLATE DATABASE_DEFAULT
          WHERE ISNULL(CONVERT(NVARCHAR(MAX), src.[value]), N'') COLLATE DATABASE_DEFAULT
              <> ISNULL(CONVERT(NVARCHAR(MAX), tgt.[value]), N'') COLLATE DATABASE_DEFAULT
            AND COALESCE(src.[key], tgt.[key]) COLLATE DATABASE_DEFAULT NOT IN
            (
                N'ID',
                N'Guid',
                N'RowVersion',
                N'LanguageLabelID',
                N'LanguageLabelId',
                N'EntityHoBTID',
                N'EntityHoBTId',
                N'EntityHobtID',
                N'EntityHobtId',
                N'Statement',
                N'EntityDataTypeID',
                N'EntityDataTypeId',
                N'EntityPropertyGroupID',
                N'EntityPropertyGroupId',
                N'DropDownListDefinitionID',
                N'DropDownListDefinitionId'
            )
      );

    ------------------------------------------------------------
    -- SCore.EntityQueries
    ------------------------------------------------------------
    UPDATE sr
    SET DifferenceType = N'NoChange'
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY OPENJSON(sr.SourcePayloadJson)
        WITH
        (
            Statement NVARCHAR(MAX) N'$.Statement'
        ) AS srcStmt
        OUTER APPLY OPENJSON(sr.TargetPayloadJson)
        WITH
        (
            Statement NVARCHAR(MAX) N'$.Statement'
        ) AS tgtStmt
        CROSS APPLY
        (
            SELECT
                LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    ISNULL(srcStmt.Statement, N''),
                    CHAR(13), N''), CHAR(10), N''), CHAR(9), N''), NCHAR(160), N''), N' ', N''), N'"', N''
                )) AS NormalisedSourceStatement,
                LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    ISNULL(tgtStmt.Statement, N''),
                    CHAR(13), N''), CHAR(10), N''), CHAR(9), N''), NCHAR(160), N''), N' ', N''), N'"', N''
                )) AS NormalisedTargetStatement
        ) AS stmt
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND sr.TargetPayloadJson IS NOT NULL
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueries'
      AND NOT EXISTS
      (
          SELECT 1
          FROM OPENJSON(sr.SourcePayloadJson) AS src
          FULL OUTER JOIN OPENJSON(sr.TargetPayloadJson) AS tgt
              ON tgt.[key] COLLATE DATABASE_DEFAULT = src.[key] COLLATE DATABASE_DEFAULT
          WHERE ISNULL(CONVERT(NVARCHAR(MAX), src.[value]), N'') COLLATE DATABASE_DEFAULT
              <> ISNULL(CONVERT(NVARCHAR(MAX), tgt.[value]), N'') COLLATE DATABASE_DEFAULT
            AND COALESCE(src.[key], tgt.[key]) COLLATE DATABASE_DEFAULT NOT IN
            (
                N'ID',
                N'Guid',
                N'RowVersion',
                N'EntityTypeID',
                N'EntityTypeId',
                N'EntityHoBTID',
                N'EntityHoBTId',
                N'EntityHobtID',
                N'EntityHobtId',
                N'Statement'
            )
      )
      AND stmt.NormalisedSourceStatement = stmt.NormalisedTargetStatement;

    ------------------------------------------------------------
    -- SUserInterface.GridViewColumnDefinitions
    ------------------------------------------------------------
    UPDATE sr
    SET DifferenceType = N'NoChange'
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND sr.TargetPayloadJson IS NOT NULL
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewColumnDefinitions'
      AND NOT EXISTS
      (
          SELECT 1
          FROM OPENJSON(sr.SourcePayloadJson) AS src
          FULL OUTER JOIN OPENJSON(sr.TargetPayloadJson) AS tgt
              ON tgt.[key] COLLATE DATABASE_DEFAULT = src.[key] COLLATE DATABASE_DEFAULT
          WHERE ISNULL(CONVERT(NVARCHAR(MAX), src.[value]), N'') COLLATE DATABASE_DEFAULT
              <> ISNULL(CONVERT(NVARCHAR(MAX), tgt.[value]), N'') COLLATE DATABASE_DEFAULT
            AND COALESCE(src.[key], tgt.[key]) COLLATE DATABASE_DEFAULT NOT IN
            (
                N'ID',
                N'Guid',
                N'RowVersion',
                N'GridViewDefinitionID',
                N'GridViewDefinitionId',
                N'LanguageLabelID',
                N'LanguageLabelId'
            )
      );
END;
GO