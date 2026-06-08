/* 
    CymBuild Metadata Apply Handlers
    Generated: 2026-05-22
    Purpose: DEV -> QA/controlled metadata apply using source Guid identity only.

    Rules preserved:
    - Uses existing CymBuild upsert procedures only.
    - Does not copy source numeric IDs into target.
    - Resolves all FK-style references via source numeric ID -> source Guid -> target upsert proc.
    - Idempotent when rerun for the same staged metadata run.
    - Applies metadata in dependency order.
*/

USE [CymBuild_QA];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApply_Run]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ForceApply BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RunStatus NVARCHAR(30),
        @TargetEnvironment NVARCHAR(20),
        @SourceDatabaseName SYSNAME,
        @FailCount INT = 0;

    SELECT
        @RunStatus = r.RunStatus,
        @TargetEnvironment = r.TargetEnvironment,
        @SourceDatabaseName = r.SourceDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @RunStatus IS NULL
        THROW 52000, 'Metadata run was not found or is inactive.', 1;

    IF @RunStatus NOT IN (N'Validated', N'PartiallyApplied')
        THROW 52001, 'Metadata run must be Validated or PartiallyApplied before apply.', 1;

    SELECT
        @FailCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail';

    IF ISNULL(@FailCount, 0) > 0
        THROW 52002, 'Metadata run has validation failures and cannot be applied.', 1;

    IF @TargetEnvironment = N'LIVE' AND ISNULL(@ForceApply, 0) = 0
        THROW 52003, 'LIVE metadata apply requires @ForceApply = 1.', 1;

    BEGIN TRANSACTION;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyStart',
        @StepStatus = N'Started',
        @Message = N'Metadata apply started.',
        @DetailsJson = N'{}';

    /* =========================================================
       1. SCore.LanguageLabels
       ========================================================= */
    DECLARE
        @Guid UNIQUEIDENTIFIER,
        @Name NVARCHAR(500);

    DECLARE LanguageLabels_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name')
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'LanguageLabels'
        ORDER BY sr.SourceRowId;

    OPEN LanguageLabels_Cursor;

    FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @LanguageLabelGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelUpsert
            @Name = @Name,
            @Guid = @LanguageLabelGuid OUTPUT;

        FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;
    END;

    CLOSE LanguageLabels_Cursor;
    DEALLOCATE LanguageLabels_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabels',
        @StepStatus = N'Succeeded',
        @Message = N'Language labels applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       2. SCore.LanguageLabelTranslations
       ========================================================= */
    DECLARE
        @Text NVARCHAR(500),
        @TextPlural NVARCHAR(500),
        @HelpText NVARCHAR(MAX),
        @LanguageLabelGuidRef UNIQUEIDENTIFIER,
        @LanguageGuidRef UNIQUEIDENTIFIER,
        @SourceLanguageLabelId BIGINT,
        @SourceLanguageId BIGINT,
        @Sql NVARCHAR(MAX);

    IF OBJECT_ID(N'tempdb..#LanguageLabelTranslationsToApply') IS NOT NULL
        DROP TABLE #LanguageLabelTranslationsToApply;

    CREATE TABLE #LanguageLabelTranslationsToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        Text NVARCHAR(500) NULL,
        TextPlural NVARCHAR(500) NULL,
        HelpText NVARCHAR(MAX) NULL,
        SourceLanguageLabelId BIGINT NULL,
        SourceLanguageId BIGINT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #LanguageLabelTranslationsToApply
    (
        Guid,
        Text,
        TextPlural,
        HelpText,
        SourceLanguageLabelId,
        SourceLanguageId,
        SourceRowId
    )
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Text'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TextPlural'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.HelpText'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageID')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'LanguageLabelTranslations';

    DECLARE LanguageLabelTranslations_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            Text,
            TextPlural,
            HelpText,
            SourceLanguageLabelId,
            SourceLanguageId
        FROM #LanguageLabelTranslationsToApply
        ORDER BY SourceRowId;

    OPEN LanguageLabelTranslations_Cursor;

    FETCH NEXT FROM LanguageLabelTranslations_Cursor
    INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Sql = N'
SELECT
    @LanguageLabelGuidRef = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @SourceLanguageLabelId;

SELECT
    @LanguageGuidRef = l.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.Languages AS l
WHERE l.ID = @SourceLanguageId;';

        EXEC sys.sp_executesql
            @Sql,
            N'@SourceLanguageLabelId BIGINT, @SourceLanguageId BIGINT, @LanguageLabelGuidRef UNIQUEIDENTIFIER OUTPUT, @LanguageGuidRef UNIQUEIDENTIFIER OUTPUT',
            @SourceLanguageLabelId = @SourceLanguageLabelId,
            @SourceLanguageId = @SourceLanguageId,
            @LanguageLabelGuidRef = @LanguageLabelGuidRef OUTPUT,
            @LanguageGuidRef = @LanguageGuidRef OUTPUT;

        DECLARE @LanguageLabelTranslationGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelTranslationUpsert
            @Text = @Text,
            @TextPlural = @TextPlural,
            @HelpText = @HelpText,
            @LanguageLabelGuid = @LanguageLabelGuidRef,
            @LanguageGuid = @LanguageGuidRef,
            @Guid = @LanguageLabelTranslationGuid OUTPUT;

        FETCH NEXT FROM LanguageLabelTranslations_Cursor
        INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;
    END;

    CLOSE LanguageLabelTranslations_Cursor;
    DEALLOCATE LanguageLabelTranslations_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabelTranslations',
        @StepStatus = N'Succeeded',
        @Message = N'Language label translations applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       3. SCore.EntityQueries
       ========================================================= */
    DECLARE
        @Statement NVARCHAR(MAX),
        @EntityTypeGuid UNIQUEIDENTIFIER,
        @EntityHoBTGuid UNIQUEIDENTIFIER,
        @IsDefaultCreate BIT,
        @IsDefaultRead BIT,
        @IsDefaultUpdate BIT,
        @IsDefaultDelete BIT,
        @IsScalarExecute BIT,
        @IsDefaultValidation BIT,
        @IsDefaultDataPills BIT,
        @IsMergeDocumentQuery BIT,
        @IsProgressData BIT,
        @SchemaName NVARCHAR(255),
        @ObjectName NVARCHAR(255),
        @IsManualStatement BIT,
        @RowStatus TINYINT,
        @SourceEntityTypeId BIGINT,
        @SourceEntityHoBTId BIGINT;

    IF OBJECT_ID(N'tempdb..#EntityQueriesToApply') IS NOT NULL
        DROP TABLE #EntityQueriesToApply;

    CREATE TABLE #EntityQueriesToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        RowStatus TINYINT NULL,
        Name NVARCHAR(500) NULL,
        Statement NVARCHAR(MAX) NULL,
        SourceEntityTypeId BIGINT NULL,
        SourceEntityHoBTId BIGINT NULL,
        IsDefaultCreate BIT NULL,
        IsDefaultRead BIT NULL,
        IsDefaultUpdate BIT NULL,
        IsDefaultDelete BIT NULL,
        IsScalarExecute BIT NULL,
        IsDefaultValidation BIT NULL,
        IsDefaultDataPills BIT NULL,
        IsMergeDocumentQuery BIT NULL,
        IsProgressData BIT NULL,
        SchemaName NVARCHAR(255) NULL,
        ObjectName NVARCHAR(255) NULL,
        IsManualStatement BIT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #EntityQueriesToApply
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        jsonPayload.Statement,
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCreate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultRead')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultUpdate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDelete')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsScalarExecute')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultValidation')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDataPills')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMergeDocumentQuery')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsProgressData')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsManualStatement')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        Statement NVARCHAR(MAX) N'$.Statement'
    ) AS jsonPayload
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueries';

    DECLARE EntityQueries_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            RowStatus,
            Name,
            Statement,
            SourceEntityTypeId,
            SourceEntityHoBTId,
            IsDefaultCreate,
            IsDefaultRead,
            IsDefaultUpdate,
            IsDefaultDelete,
            IsScalarExecute,
            IsDefaultValidation,
            IsDefaultDataPills,
            IsMergeDocumentQuery,
            IsProgressData,
            SchemaName,
            ObjectName,
            IsManualStatement
        FROM #EntityQueriesToApply
        ORDER BY SourceRowId;

    OPEN EntityQueries_Cursor;

    FETCH NEXT FROM EntityQueries_Cursor
    INTO
        @Guid,
        @RowStatus,
        @Name,
        @Statement,
        @SourceEntityTypeId,
        @SourceEntityHoBTId,
        @IsDefaultCreate,
        @IsDefaultRead,
        @IsDefaultUpdate,
        @IsDefaultDelete,
        @IsScalarExecute,
        @IsDefaultValidation,
        @IsDefaultDataPills,
        @IsMergeDocumentQuery,
        @IsProgressData,
        @SchemaName,
        @ObjectName,
        @IsManualStatement;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Sql = N'
SELECT @EntityTypeGuid = et.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityTypes AS et
WHERE et.ID = @SourceEntityTypeId;

SELECT @EntityHoBTGuid = eh.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityHobts AS eh
WHERE eh.ID = @SourceEntityHoBTId;';

        EXEC sys.sp_executesql
            @Sql,
            N'@SourceEntityTypeId BIGINT, @SourceEntityHoBTId BIGINT, @EntityTypeGuid UNIQUEIDENTIFIER OUTPUT, @EntityHoBTGuid UNIQUEIDENTIFIER OUTPUT',
            @SourceEntityTypeId = @SourceEntityTypeId,
            @SourceEntityHoBTId = @SourceEntityHoBTId,
            @EntityTypeGuid = @EntityTypeGuid OUTPUT,
            @EntityHoBTGuid = @EntityHoBTGuid OUTPUT;

        DECLARE @EntityQueryGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityQueryUpsert
            @Name = @Name,
            @RowStatus = @RowStatus,
            @Statement = @Statement,
            @EntityTypeGuid = @EntityTypeGuid,
            @IsDefaultCreate = @IsDefaultCreate,
            @IsDefaultRead = @IsDefaultRead,
            @IsDefaultUpdate = @IsDefaultUpdate,
            @IsDefaultDelete = @IsDefaultDelete,
            @IsScalarExecute = @IsScalarExecute,
            @IsDefaultValidation = @IsDefaultValidation,
            @EntityHoBTGuid = @EntityHoBTGuid,
            @IsDefaultDataPills = @IsDefaultDataPills,
            @IsMergeDocumentQuery = @IsMergeDocumentQuery,
            @IsProgressData = @IsProgressData,
            @SchemaName = @SchemaName,
            @ObjectName = @ObjectName,
            @IsManualStatement = @IsManualStatement,
            @Guid = @EntityQueryGuid OUTPUT;

        FETCH NEXT FROM EntityQueries_Cursor
        INTO
            @Guid,
            @RowStatus,
            @Name,
            @Statement,
            @SourceEntityTypeId,
            @SourceEntityHoBTId,
            @IsDefaultCreate,
            @IsDefaultRead,
            @IsDefaultUpdate,
            @IsDefaultDelete,
            @IsScalarExecute,
            @IsDefaultValidation,
            @IsDefaultDataPills,
            @IsMergeDocumentQuery,
            @IsProgressData,
            @SchemaName,
            @ObjectName,
            @IsManualStatement;
    END;

    CLOSE EntityQueries_Cursor;
    DEALLOCATE EntityQueries_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityQueries',
        @StepStatus = N'Succeeded',
        @Message = N'Entity queries applied.',
        @DetailsJson = N'{}';

/* =========================================================
   4. SCore.EntityProperties
   ========================================================= */

DECLARE
    @EP_RowStatus TINYINT,
    @EP_Name NVARCHAR(500),
    @EP_SourceLanguageLabelID BIGINT,
    @EP_SourceEntityHoBTID BIGINT,
    @EP_SourceEntityDataTypeID BIGINT,
    @EP_SourceEntityPropertyGroupID BIGINT,
    @EP_SourceDropDownListDefinitionID BIGINT,
    @EP_LanguageLabelGuid UNIQUEIDENTIFIER,
    @EP_EntityHoBTGuid UNIQUEIDENTIFIER,
    @EP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EP_EntityPropertyGroupGuid UNIQUEIDENTIFIER,
    @EP_DropDownListDefinitionGuid UNIQUEIDENTIFIER,
    @EP_IsReadOnly BIT,
    @EP_IsImmutable BIT,
    @EP_IsUppercase BIT,
    @EP_IsHidden BIT,
    @EP_IsCompulsory BIT,
    @EP_MaxLength INT,
    @EP_Precision INT,
    @EP_Scale INT,
    @EP_DoNotTrackChanges BIT,
    @EP_SortOrder SMALLINT,
    @EP_GroupSortOrder SMALLINT,
    @EP_IsObjectLabel BIT,
    @EP_IsParentRelationship BIT,
    @EP_IsIncludedInformation BIT,
    @EP_IsLatitude BIT,
    @EP_IsLongitude BIT,
    @EP_FixDefaultValue NVARCHAR(100),
    @EP_SqlDefaultValueStatement NVARCHAR(MAX),
    @EP_AllowBulkChange BIT,
    @EP_IsVirtual BIT,
    @EP_ShowOnMobile BIT,
    @EP_IsAlwaysVisibleInGroup BIT,
    @EP_IsAlwaysVisibleInGroup_Mobile BIT;

IF OBJECT_ID(N'tempdb..#EntityPropertiesToApply') IS NOT NULL
    DROP TABLE #EntityPropertiesToApply;

CREATE TABLE #EntityPropertiesToApply
(
    Guid UNIQUEIDENTIFIER NOT NULL,
    RowStatus TINYINT NULL,
    Name NVARCHAR(500) NULL,
    SourceLanguageLabelID BIGINT NULL,
    SourceEntityHoBTID BIGINT NULL,
    SourceEntityDataTypeID BIGINT NULL,
    IsReadOnly BIT NULL,
    IsImmutable BIT NULL,
    IsUppercase BIT NULL,
    IsHidden BIT NULL,
    IsCompulsory BIT NULL,
    MaxLength INT NULL,
    PrecisionValue INT NULL,
    ScaleValue INT NULL,
    DoNotTrackChanges BIT NULL,
    SourceEntityPropertyGroupID BIGINT NULL,
    SortOrder SMALLINT NULL,
    GroupSortOrder SMALLINT NULL,
    IsObjectLabel BIT NULL,
    SourceDropDownListDefinitionID BIGINT NULL,
    IsParentRelationship BIT NULL,
    IsIncludedInformation BIT NULL,
    IsLatitude BIT NULL,
    IsLongitude BIT NULL,
    FixDefaultValue NVARCHAR(100) NULL,
    SqlDefaultValueStatement NVARCHAR(MAX) NULL,
    AllowBulkChange BIT NULL,
    IsVirtual BIT NULL,
    ShowOnMobile BIT NULL,
    IsAlwaysVisibleInGroup BIT NULL,
    IsAlwaysVisibleInGroup_Mobile BIT NULL,
    SourceRowId BIGINT NULL
);

INSERT INTO #EntityPropertiesToApply
SELECT
    sr.SourceRowGuid,
    TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
    JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID')),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID')),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnly')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsImmutable')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsUppercase')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCompulsory')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MaxLength')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Precision')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Scale')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupID')),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GroupSortOrder')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsObjectLabel')),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionID')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsParentRelationship')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsIncludedInformation')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLatitude')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLongitude')),
    ISNULL
    (
        COALESCE
        (
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixedDefaultValue'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixDefaultValue')
        ),
        N''
    ),
    epjson.SqlDefaultValueStatement,
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsVirtual')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup_Mobile')),
    sr.SourceRowId
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = sr.RegistryGuid
   AND tr.RowStatus NOT IN (0,254)
OUTER APPLY OPENJSON(sr.SourcePayloadJson)
WITH
(
    SqlDefaultValueStatement NVARCHAR(MAX) N'$.SqlDefaultValueStatement'
) AS epjson
WHERE sr.RunGuid = @RunGuid
  AND sr.RowStatus NOT IN (0,254)
  AND sr.DifferenceType IN (N'Insert', N'Update')
  AND tr.SchemaName = N'SCore'
  AND tr.TableName = N'EntityProperties';

DECLARE EntityProperties_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        Guid,
        RowStatus,
        Name,
        SourceLanguageLabelID,
        SourceEntityHoBTID,
        SourceEntityDataTypeID,
        IsReadOnly,
        IsImmutable,
        IsUppercase,
        IsHidden,
        IsCompulsory,
        MaxLength,
        PrecisionValue,
        ScaleValue,
        DoNotTrackChanges,
        SourceEntityPropertyGroupID,
        SortOrder,
        GroupSortOrder,
        IsObjectLabel,
        SourceDropDownListDefinitionID,
        IsParentRelationship,
        IsIncludedInformation,
        IsLatitude,
        IsLongitude,
        FixDefaultValue,
        SqlDefaultValueStatement,
        AllowBulkChange,
        IsVirtual,
        ShowOnMobile,
        IsAlwaysVisibleInGroup,
        IsAlwaysVisibleInGroup_Mobile
    FROM #EntityPropertiesToApply
    ORDER BY SourceRowId;

OPEN EntityProperties_Cursor;

FETCH NEXT FROM EntityProperties_Cursor
INTO
    @Guid,
    @EP_RowStatus,
    @EP_Name,
    @EP_SourceLanguageLabelID,
    @EP_SourceEntityHoBTID,
    @EP_SourceEntityDataTypeID,
    @EP_IsReadOnly,
    @EP_IsImmutable,
    @EP_IsUppercase,
    @EP_IsHidden,
    @EP_IsCompulsory,
    @EP_MaxLength,
    @EP_Precision,
    @EP_Scale,
    @EP_DoNotTrackChanges,
    @EP_SourceEntityPropertyGroupID,
    @EP_SortOrder,
    @EP_GroupSortOrder,
    @EP_IsObjectLabel,
    @EP_SourceDropDownListDefinitionID,
    @EP_IsParentRelationship,
    @EP_IsIncludedInformation,
    @EP_IsLatitude,
    @EP_IsLongitude,
    @EP_FixDefaultValue,
    @EP_SqlDefaultValueStatement,
    @EP_AllowBulkChange,
    @EP_IsVirtual,
    @EP_ShowOnMobile,
    @EP_IsAlwaysVisibleInGroup,
    @EP_IsAlwaysVisibleInGroup_Mobile;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EP_LanguageLabelGuid = NULL;
    SET @EP_EntityHoBTGuid = NULL;
    SET @EP_EntityDataTypeGuid = NULL;
    SET @EP_EntityPropertyGroupGuid = NULL;
    SET @EP_DropDownListDefinitionGuid = NULL;
    SET @EP_FixDefaultValue = ISNULL(@EP_FixDefaultValue, N'');
    SET @Sql = N'
SELECT @EP_LanguageLabelGuid = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @EP_SourceLanguageLabelID;

SELECT @EP_EntityHoBTGuid = eh.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityHobts AS eh
WHERE eh.ID = @EP_SourceEntityHoBTID;

SELECT @EP_EntityDataTypeGuid = edt.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityDataTypes AS edt
WHERE edt.ID = @EP_SourceEntityDataTypeID;

SELECT @EP_EntityPropertyGroupGuid = epg.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityPropertyGroups AS epg
WHERE epg.ID = @EP_SourceEntityPropertyGroupID;

SELECT @EP_DropDownListDefinitionGuid = ddl.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.DropDownListDefinitions AS ddl
WHERE ddl.ID = @EP_SourceDropDownListDefinitionID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@EP_SourceLanguageLabelID BIGINT,
          @EP_SourceEntityHoBTID BIGINT,
          @EP_SourceEntityDataTypeID BIGINT,
          @EP_SourceEntityPropertyGroupID BIGINT,
          @EP_SourceDropDownListDefinitionID BIGINT,
          @EP_LanguageLabelGuid UNIQUEIDENTIFIER OUTPUT,
          @EP_EntityHoBTGuid UNIQUEIDENTIFIER OUTPUT,
          @EP_EntityDataTypeGuid UNIQUEIDENTIFIER OUTPUT,
          @EP_EntityPropertyGroupGuid UNIQUEIDENTIFIER OUTPUT,
          @EP_DropDownListDefinitionGuid UNIQUEIDENTIFIER OUTPUT',
        @EP_SourceLanguageLabelID = @EP_SourceLanguageLabelID,
        @EP_SourceEntityHoBTID = @EP_SourceEntityHoBTID,
        @EP_SourceEntityDataTypeID = @EP_SourceEntityDataTypeID,
        @EP_SourceEntityPropertyGroupID = @EP_SourceEntityPropertyGroupID,
        @EP_SourceDropDownListDefinitionID = @EP_SourceDropDownListDefinitionID,
        @EP_LanguageLabelGuid = @EP_LanguageLabelGuid OUTPUT,
        @EP_EntityHoBTGuid = @EP_EntityHoBTGuid OUTPUT,
        @EP_EntityDataTypeGuid = @EP_EntityDataTypeGuid OUTPUT,
        @EP_EntityPropertyGroupGuid = @EP_EntityPropertyGroupGuid OUTPUT,
        @EP_DropDownListDefinitionGuid = @EP_DropDownListDefinitionGuid OUTPUT;

    DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SCore.EntityPropertyUpsert
        @Name = @EP_Name,
        @RowStatus = @EP_RowStatus,
        @LanguageLabelGuid = @EP_LanguageLabelGuid,
        @EntityHobtGuid = @EP_EntityHoBTGuid,
        @EntityDataTypeGuid = @EP_EntityDataTypeGuid,
        @IsReadOnly = @EP_IsReadOnly,
        @IsImmutable = @EP_IsImmutable,
        @IsUppercase = @EP_IsUppercase,
        @IsHidden = @EP_IsHidden,
        @IsCompulsory = @EP_IsCompulsory,
        @MaxLength = @EP_MaxLength,
        @Precision = @EP_Precision,
        @Scale = @EP_Scale,
        @DoNotTrackChanges = @EP_DoNotTrackChanges,
        @EntityPropertyGroupGuid = @EP_EntityPropertyGroupGuid,
        @SortOrder = @EP_SortOrder,
        @GroupSortOrder = @EP_GroupSortOrder,
        @IsObjectLabel = @EP_IsObjectLabel,
        @DropDownListDefinitionGuid = @EP_DropDownListDefinitionGuid,
        @IsParentRelationship = @EP_IsParentRelationship,
        @IsIncludedInformation = @EP_IsIncludedInformation,
        @IsLatitude = @EP_IsLatitude,
        @IsLongitude = @EP_IsLongitude,
        @FixDefaultValue = @EP_FixDefaultValue,
        @SqlDefaultValueStatement = @EP_SqlDefaultValueStatement,
        @AllowBulkChange = @EP_AllowBulkChange,
        @IsVirtual = @EP_IsVirtual,
        @ShowOnMobile = @EP_ShowOnMobile,
        @IsAlwaysVisibleInGroup = @EP_IsAlwaysVisibleInGroup,
        @IsAlwaysVisibleInGroup_Mobile = @EP_IsAlwaysVisibleInGroup_Mobile,
        @Guid = @EntityPropertyGuid OUTPUT;

    FETCH NEXT FROM EntityProperties_Cursor
    INTO
        @Guid,
        @EP_RowStatus,
        @EP_Name,
        @EP_SourceLanguageLabelID,
        @EP_SourceEntityHoBTID,
        @EP_SourceEntityDataTypeID,
        @EP_IsReadOnly,
        @EP_IsImmutable,
        @EP_IsUppercase,
        @EP_IsHidden,
        @EP_IsCompulsory,
        @EP_MaxLength,
        @EP_Precision,
        @EP_Scale,
        @EP_DoNotTrackChanges,
        @EP_SourceEntityPropertyGroupID,
        @EP_SortOrder,
        @EP_GroupSortOrder,
        @EP_IsObjectLabel,
        @EP_SourceDropDownListDefinitionID,
        @EP_IsParentRelationship,
        @EP_IsIncludedInformation,
        @EP_IsLatitude,
        @EP_IsLongitude,
        @EP_FixDefaultValue,
        @EP_SqlDefaultValueStatement,
        @EP_AllowBulkChange,
        @EP_IsVirtual,
        @EP_ShowOnMobile,
        @EP_IsAlwaysVisibleInGroup,
        @EP_IsAlwaysVisibleInGroup_Mobile;
END;

CLOSE EntityProperties_Cursor;
DEALLOCATE EntityProperties_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityProperties',
    @StepStatus = N'Succeeded',
    @Message = N'Entity properties applied.',
    @DetailsJson = N'{}';

/* =========================================================
   5. SCore.EntityQueryParameters
   ========================================================= */

DECLARE
    @EQP_RowStatus TINYINT,
    @EQP_Name NVARCHAR(500),
    @EQP_SourceEntityQueryID BIGINT,
    @EQP_SourceEntityDataTypeID BIGINT,
    @EQP_SourceMappedEntityPropertyID BIGINT,
    @EQP_EntityQueryGuid UNIQUEIDENTIFIER,
    @EQP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EQP_MappedEntityPropertyGuid UNIQUEIDENTIFIER,
    @EQP_DefaultValue NVARCHAR(200),
    @EQP_IsInput BIT,
    @EQP_IsOutput BIT,
    @EQP_IsReturnColumn BIT;

DECLARE EntityQueryParameters_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyID')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultValue'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsInput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsOutput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReturnColumn'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueryParameters'
    ORDER BY sr.SourceRowId;

OPEN EntityQueryParameters_Cursor;

FETCH NEXT FROM EntityQueryParameters_Cursor
INTO
    @Guid,
    @EQP_RowStatus,
    @EQP_Name,
    @EQP_SourceEntityQueryID,
    @EQP_SourceEntityDataTypeID,
    @EQP_SourceMappedEntityPropertyID,
    @EQP_DefaultValue,
    @EQP_IsInput,
    @EQP_IsOutput,
    @EQP_IsReturnColumn;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EQP_EntityQueryGuid = NULL;
    SET @EQP_EntityDataTypeGuid = NULL;
    SET @EQP_MappedEntityPropertyGuid = NULL;

    SET @Sql = N'
SELECT @EQP_EntityQueryGuid = eq.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityQueries AS eq
WHERE eq.ID = @EQP_SourceEntityQueryID;

SELECT @EQP_EntityDataTypeGuid = edt.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityDataTypes AS edt
WHERE edt.ID = @EQP_SourceEntityDataTypeID;

SELECT @EQP_MappedEntityPropertyGuid = ep.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityProperties AS ep
WHERE ep.ID = @EQP_SourceMappedEntityPropertyID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@EQP_SourceEntityQueryID BIGINT,
          @EQP_SourceEntityDataTypeID BIGINT,
          @EQP_SourceMappedEntityPropertyID BIGINT,
          @EQP_EntityQueryGuid UNIQUEIDENTIFIER OUTPUT,
          @EQP_EntityDataTypeGuid UNIQUEIDENTIFIER OUTPUT,
          @EQP_MappedEntityPropertyGuid UNIQUEIDENTIFIER OUTPUT',
        @EQP_SourceEntityQueryID = @EQP_SourceEntityQueryID,
        @EQP_SourceEntityDataTypeID = @EQP_SourceEntityDataTypeID,
        @EQP_SourceMappedEntityPropertyID = @EQP_SourceMappedEntityPropertyID,
        @EQP_EntityQueryGuid = @EQP_EntityQueryGuid OUTPUT,
        @EQP_EntityDataTypeGuid = @EQP_EntityDataTypeGuid OUTPUT,
        @EQP_MappedEntityPropertyGuid = @EQP_MappedEntityPropertyGuid OUTPUT;

    DECLARE @EntityQueryParameterGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SCore.EntityQueryParameterUpsert
        @Name = @EQP_Name,
        @RowStatus = @EQP_RowStatus,
        @EntityQueryGuid = @EQP_EntityQueryGuid,
        @EntityDataTypeGuid = @EQP_EntityDataTypeGuid,
        @MappedEntityPropertyGuid = @EQP_MappedEntityPropertyGuid,
        @DefaultValue = @EQP_DefaultValue,
        @IsInput = @EQP_IsInput,
        @IsOutput = @EQP_IsOutput,
        @IsReturnColumn = @EQP_IsReturnColumn,
        @Guid = @EntityQueryParameterGuid OUTPUT;

    FETCH NEXT FROM EntityQueryParameters_Cursor
    INTO
        @Guid,
        @EQP_RowStatus,
        @EQP_Name,
        @EQP_SourceEntityQueryID,
        @EQP_SourceEntityDataTypeID,
        @EQP_SourceMappedEntityPropertyID,
        @EQP_DefaultValue,
        @EQP_IsInput,
        @EQP_IsOutput,
        @EQP_IsReturnColumn;
END;

CLOSE EntityQueryParameters_Cursor;
DEALLOCATE EntityQueryParameters_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityQueryParameters',
    @StepStatus = N'Succeeded',
    @Message = N'Entity query parameters applied.',
    @DetailsJson = N'{}';


/* =========================================================
   6. SUserInterface.GridDefinitions
   ========================================================= */

DECLARE
    @GD_RowStatus TINYINT,
    @GD_Code NVARCHAR(30),
    @GD_TabName NVARCHAR(250),
    @GD_ShowAsTiles BIT,
    @GD_PageUri NVARCHAR(250),
    @GD_SourceLanguageLabelID BIGINT,
    @GD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TabName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowAsTiles')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.PageUri'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridDefinitions_Cursor;

FETCH NEXT FROM GridDefinitions_Cursor
INTO
    @Guid,
    @GD_RowStatus,
    @GD_Code,
    @GD_TabName,
    @GD_ShowAsTiles,
    @GD_PageUri,
    @GD_SourceLanguageLabelID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GD_LanguageLabelGuid = NULL;

    SET @Sql = N'
SELECT @GD_LanguageLabelGuid = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @GD_SourceLanguageLabelID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@GD_SourceLanguageLabelID BIGINT,
          @GD_LanguageLabelGuid UNIQUEIDENTIFIER OUTPUT',
        @GD_SourceLanguageLabelID = @GD_SourceLanguageLabelID,
        @GD_LanguageLabelGuid = @GD_LanguageLabelGuid OUTPUT;

    DECLARE @GridDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridDefinitionUpsert
        @Code = @GD_Code,
        @RowStatus = @GD_RowStatus,
        @TabName = @GD_TabName,
        @ShowAsTiles = @GD_ShowAsTiles,
        @PageUri = @GD_PageUri,
        @LanguageLabelGuid = @GD_LanguageLabelGuid,
        @Guid = @GridDefinitionGuid OUTPUT;

    FETCH NEXT FROM GridDefinitions_Cursor
    INTO
        @Guid,
        @GD_RowStatus,
        @GD_Code,
        @GD_TabName,
        @GD_ShowAsTiles,
        @GD_PageUri,
        @GD_SourceLanguageLabelID;
END;

CLOSE GridDefinitions_Cursor;
DEALLOCATE GridDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   7. SUserInterface.GridViewDefinitions
   ========================================================= */

DECLARE
    @GVD_RowStatus TINYINT,
    @GVD_Code NVARCHAR(20),
    @GVD_SourceGridDefinitionID BIGINT,
    @GVD_DetailPageUri NVARCHAR(250),
    @GVD_SqlQuery NVARCHAR(MAX),
    @GVD_DefaultSortColumnName NVARCHAR(250),
    @GVD_SecurableCode NVARCHAR(20),
    @GVD_DisplayOrder INT,
    @GVD_DisplayGroupName NVARCHAR(50),
    @GVD_MetricSqlQuery NVARCHAR(MAX),
    @GVD_ShowMetric BIT,
    @GVD_IsDetailWindowed BIT,
    @GVD_SourceEntityTypeID BIGINT,
    @GVD_SourceMetricTypeID BIGINT,
    @GVD_MetricMin INT,
    @GVD_MetricMax INT,
    @GVD_MetricMinorUnit INT,
    @GVD_MetricMajorUnit INT,
    @GVD_MetricStartAngle INT,
    @GVD_MetricEndAngle INT,
    @GVD_MetricReversed BIT,
    @GVD_MetricRange1Min DECIMAL(18,0),
    @GVD_MetricRange1Max DECIMAL(18,0),
    @GVD_MetricRange1ColourHex NVARCHAR(10),
    @GVD_MetricRange2Min DECIMAL(18,0),
    @GVD_MetricRange2Max DECIMAL(18,0),
    @GVD_MetricRange2ColourHex NVARCHAR(10),
    @GVD_IsDefaultSortDescending BIT,
    @GVD_ShowOnMobile BIT,
    @GVD_AllowNew BIT,
    @GVD_AllowExcelExport BIT,
    @GVD_AllowPdfExport BIT,
    @GVD_AllowCsvExport BIT,
    @GVD_SourceLanguageLabelID BIGINT,
    @GVD_SourceDrawerIconID BIGINT,
    @GVD_SourceGridViewTypeID BIGINT,
    @GVD_AllowBulkChange BIT,
    @GVD_TreeListFirstOrderBy NVARCHAR(100),
    @GVD_TreeListSecondOrderBy NVARCHAR(100),
    @GVD_TreeListThirdOrderBy NVARCHAR(100),
    @GVD_TreeListOrderBy NVARCHAR(100),
    @GVD_TreeListGroupBy NVARCHAR(100),
    @GVD_ShowOnDashboard BIT,
    @GVD_FilteredListCreatedOnColumn NVARCHAR(100),
    @GVD_FilteredListRedStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListOrangeStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGreenStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGroupBy NVARCHAR(100),
    @GVD_IsHidden BIT,
    @GVD_GridDefinitionGuid UNIQUEIDENTIFIER,
    @GVD_EntityTypeGuid UNIQUEIDENTIFIER,
    @GVD_MetricTypeGuid UNIQUEIDENTIFIER,
    @GVD_LanguageLabelGuid UNIQUEIDENTIFIER,
    @GVD_DrawerIconGuid UNIQUEIDENTIFIER,
    @GVD_GridViewTypeGuid UNIQUEIDENTIFIER;

DECLARE GridViewDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionId')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUri'),
        jsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SecurableCode'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayOrder')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayGroupName'),
        jsonValues.MetricSqlQuery,
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowMetric')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeID')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMin')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMax')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMinorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMajorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricStartAngle')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricEndAngle')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricReversed')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1ColourHex'),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2ColourHex'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultSortDescending')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowNew')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowExcelExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowPdfExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowCsvExport')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconId')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeId')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListFirstOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListSecondOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListThirdOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnDashboard')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListCreatedOnColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListRedStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListOrangeStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGreenStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery',
        MetricSqlQuery NVARCHAR(MAX) N'$.MetricSqlQuery'
    ) AS jsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewDefinitions_Cursor;

FETCH NEXT FROM GridViewDefinitions_Cursor
INTO
    @Guid,
    @GVD_RowStatus,
    @GVD_Code,
    @GVD_SourceGridDefinitionID,
    @GVD_DetailPageUri,
    @GVD_SqlQuery,
    @GVD_DefaultSortColumnName,
    @GVD_SecurableCode,
    @GVD_DisplayOrder,
    @GVD_DisplayGroupName,
    @GVD_MetricSqlQuery,
    @GVD_ShowMetric,
    @GVD_IsDetailWindowed,
    @GVD_SourceEntityTypeID,
    @GVD_SourceMetricTypeID,
    @GVD_MetricMin,
    @GVD_MetricMax,
    @GVD_MetricMinorUnit,
    @GVD_MetricMajorUnit,
    @GVD_MetricStartAngle,
    @GVD_MetricEndAngle,
    @GVD_MetricReversed,
    @GVD_MetricRange1Min,
    @GVD_MetricRange1Max,
    @GVD_MetricRange1ColourHex,
    @GVD_MetricRange2Min,
    @GVD_MetricRange2Max,
    @GVD_MetricRange2ColourHex,
    @GVD_IsDefaultSortDescending,
    @GVD_ShowOnMobile,
    @GVD_AllowNew,
    @GVD_AllowExcelExport,
    @GVD_AllowPdfExport,
    @GVD_AllowCsvExport,
    @GVD_SourceLanguageLabelID,
    @GVD_SourceDrawerIconID,
    @GVD_SourceGridViewTypeID,
    @GVD_AllowBulkChange,
    @GVD_TreeListFirstOrderBy,
    @GVD_TreeListSecondOrderBy,
    @GVD_TreeListThirdOrderBy,
    @GVD_TreeListOrderBy,
    @GVD_TreeListGroupBy,
    @GVD_ShowOnDashboard,
    @GVD_FilteredListCreatedOnColumn,
    @GVD_FilteredListRedStatusIndicatorTxt,
    @GVD_FilteredListOrangeStatusIndicatorTxt,
    @GVD_FilteredListGreenStatusIndicatorTxt,
    @GVD_FilteredListGroupBy,
    @GVD_IsHidden;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVD_GridDefinitionGuid = NULL;
    SET @GVD_EntityTypeGuid = NULL;
    SET @GVD_MetricTypeGuid = NULL;
    SET @GVD_LanguageLabelGuid = NULL;
    SET @GVD_DrawerIconGuid = NULL;
    SET @GVD_GridViewTypeGuid = NULL;

    SET @Sql = N'
SELECT @GVD_GridDefinitionGuid = gd.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.GridDefinitions AS gd
WHERE gd.ID = @GVD_SourceGridDefinitionID;

SELECT @GVD_EntityTypeGuid = et.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityTypes AS et
WHERE et.ID = @GVD_SourceEntityTypeID;

SELECT @GVD_MetricTypeGuid = mt.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.MetricTypes AS mt
WHERE mt.ID = @GVD_SourceMetricTypeID;

SELECT @GVD_LanguageLabelGuid = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @GVD_SourceLanguageLabelID;

SELECT @GVD_DrawerIconGuid = i.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.Icons AS i
WHERE i.ID = @GVD_SourceDrawerIconID;

SELECT @GVD_GridViewTypeGuid = gvt.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.GridViewTypes AS gvt
WHERE gvt.ID = @GVD_SourceGridViewTypeID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@GVD_SourceGridDefinitionID BIGINT,
          @GVD_SourceEntityTypeID BIGINT,
          @GVD_SourceMetricTypeID BIGINT,
          @GVD_SourceLanguageLabelID BIGINT,
          @GVD_SourceDrawerIconID BIGINT,
          @GVD_SourceGridViewTypeID BIGINT,
          @GVD_GridDefinitionGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_EntityTypeGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_MetricTypeGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_LanguageLabelGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_DrawerIconGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_GridViewTypeGuid UNIQUEIDENTIFIER OUTPUT',
        @GVD_SourceGridDefinitionID = @GVD_SourceGridDefinitionID,
        @GVD_SourceEntityTypeID = @GVD_SourceEntityTypeID,
        @GVD_SourceMetricTypeID = @GVD_SourceMetricTypeID,
        @GVD_SourceLanguageLabelID = @GVD_SourceLanguageLabelID,
        @GVD_SourceDrawerIconID = @GVD_SourceDrawerIconID,
        @GVD_SourceGridViewTypeID = @GVD_SourceGridViewTypeID,
        @GVD_GridDefinitionGuid = @GVD_GridDefinitionGuid OUTPUT,
        @GVD_EntityTypeGuid = @GVD_EntityTypeGuid OUTPUT,
        @GVD_MetricTypeGuid = @GVD_MetricTypeGuid OUTPUT,
        @GVD_LanguageLabelGuid = @GVD_LanguageLabelGuid OUTPUT,
        @GVD_DrawerIconGuid = @GVD_DrawerIconGuid OUTPUT,
        @GVD_GridViewTypeGuid = @GVD_GridViewTypeGuid OUTPUT;

    DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridViewDefinitionUpsert
        @Code = @GVD_Code,
        @RowStatus = @GVD_RowStatus,
        @GridDefinitionGuid = @GVD_GridDefinitionGuid,
        @DetailPageUri = @GVD_DetailPageUri,
        @SqlQuery = @GVD_SqlQuery,
        @DefaultSortColumnName = @GVD_DefaultSortColumnName,
        @SecurableCode = @GVD_SecurableCode,
        @DisplayOrder = @GVD_DisplayOrder,
        @DisplayGroupName = @GVD_DisplayGroupName,
        @MetricSqlQuery = @GVD_MetricSqlQuery,
        @ShowMetric = @GVD_ShowMetric,
        @IsDetailWindowed = @GVD_IsDetailWindowed,
        @EntityTypeGuid = @GVD_EntityTypeGuid,
        @MetricTypeGuid = @GVD_MetricTypeGuid,
        @MetricMin = @GVD_MetricMin,
        @MetricMax = @GVD_MetricMax,
        @MetricMinorUnit = @GVD_MetricMinorUnit,
        @MetricMajorUnit = @GVD_MetricMajorUnit,
        @MetricStartAngle = @GVD_MetricStartAngle,
        @MetricEndAngle = @GVD_MetricEndAngle,
        @MetricReversed = @GVD_MetricReversed,
        @MetricRange1Min = @GVD_MetricRange1Min,
        @MetricRange1Max = @GVD_MetricRange1Max,
        @MetricRange1ColourHex = @GVD_MetricRange1ColourHex,
        @MetricRange2Min = @GVD_MetricRange2Min,
        @MetricRange2Max = @GVD_MetricRange2Max,
        @MetricRange2ColourHex = @GVD_MetricRange2ColourHex,
        @IsDefaultSortDescending = @GVD_IsDefaultSortDescending,
        @AllowNew = @GVD_AllowNew,
        @AllowExcelExport = @GVD_AllowExcelExport,
        @AllowPdfExport = @GVD_AllowPdfExport,
        @AllowCsvExport = @GVD_AllowCsvExport,
        @LanguageLabelGuid = @GVD_LanguageLabelGuid,
        @DrawerIconGuid = @GVD_DrawerIconGuid,
        @GridViewTypeGuid = @GVD_GridViewTypeGuid,
        @AllowBulkChange = @GVD_AllowBulkChange,
        @Guid = @GridViewDefinitionGuid OUTPUT,
        @ShowOnMobile = @GVD_ShowOnMobile,
        @TreeListFirstOrderBy = @GVD_TreeListFirstOrderBy,
        @TreeListSecondOrderBy = @GVD_TreeListSecondOrderBy,
        @TreeListThirdOrderBy = @GVD_TreeListThirdOrderBy,
        @TreeListOrderBy = @GVD_TreeListOrderBy,
        @TreeListGroupBy = @GVD_TreeListGroupBy,
        @ShowOnDashboard = @GVD_ShowOnDashboard,
        @FilteredListCreatedOnColumn = @GVD_FilteredListCreatedOnColumn,
        @FilteredListRedStatusIndicatorTxt = @GVD_FilteredListRedStatusIndicatorTxt,
        @FilteredListOrangeStatusIndicatorTxt = @GVD_FilteredListOrangeStatusIndicatorTxt,
        @FilteredListGreenStatusIndicatorTxt = @GVD_FilteredListGreenStatusIndicatorTxt,
        @FilteredListGroupBy = @GVD_FilteredListGroupBy,
        @IsHidden = @GVD_IsHidden;

    FETCH NEXT FROM GridViewDefinitions_Cursor
    INTO
        @Guid,
        @GVD_RowStatus,
        @GVD_Code,
        @GVD_SourceGridDefinitionID,
        @GVD_DetailPageUri,
        @GVD_SqlQuery,
        @GVD_DefaultSortColumnName,
        @GVD_SecurableCode,
        @GVD_DisplayOrder,
        @GVD_DisplayGroupName,
        @GVD_MetricSqlQuery,
        @GVD_ShowMetric,
        @GVD_IsDetailWindowed,
        @GVD_SourceEntityTypeID,
        @GVD_SourceMetricTypeID,
        @GVD_MetricMin,
        @GVD_MetricMax,
        @GVD_MetricMinorUnit,
        @GVD_MetricMajorUnit,
        @GVD_MetricStartAngle,
        @GVD_MetricEndAngle,
        @GVD_MetricReversed,
        @GVD_MetricRange1Min,
        @GVD_MetricRange1Max,
        @GVD_MetricRange1ColourHex,
        @GVD_MetricRange2Min,
        @GVD_MetricRange2Max,
        @GVD_MetricRange2ColourHex,
        @GVD_IsDefaultSortDescending,
        @GVD_ShowOnMobile,
        @GVD_AllowNew,
        @GVD_AllowExcelExport,
        @GVD_AllowPdfExport,
        @GVD_AllowCsvExport,
        @GVD_SourceLanguageLabelID,
        @GVD_SourceDrawerIconID,
        @GVD_SourceGridViewTypeID,
        @GVD_AllowBulkChange,
        @GVD_TreeListFirstOrderBy,
        @GVD_TreeListSecondOrderBy,
        @GVD_TreeListThirdOrderBy,
        @GVD_TreeListOrderBy,
        @GVD_TreeListGroupBy,
        @GVD_ShowOnDashboard,
        @GVD_FilteredListCreatedOnColumn,
        @GVD_FilteredListRedStatusIndicatorTxt,
        @GVD_FilteredListOrangeStatusIndicatorTxt,
        @GVD_FilteredListGreenStatusIndicatorTxt,
        @GVD_FilteredListGroupBy,
        @GVD_IsHidden;
END;

CLOSE GridViewDefinitions_Cursor;
DEALLOCATE GridViewDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   8. SUserInterface.GridViewColumnDefinitions
   ========================================================= */

DECLARE
    @GVCD_RowStatus TINYINT,
    @GVCD_Name NVARCHAR(250),
    @GVCD_SourceGridViewDefinitionID BIGINT,
    @GVCD_ColumnOrder INT,
    @GVCD_IsPrimaryKey BIT,
    @GVCD_IsHidden BIT,
    @GVCD_IsFiltered BIT,
    @GVCD_IsCombo BIT,
    @GVCD_DisplayFormat NVARCHAR(50),
    @GVCD_Width NVARCHAR(10),
    @GVCD_SourceLanguageLabelID BIGINT,
    @GVCD_TopHeaderCategory NVARCHAR(50),
    @GVCD_TopHeaderCategoryOrder INT,
    @GVCD_GridViewDefinitionGuid UNIQUEIDENTIFIER,
    @GVCD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridViewColumnDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionId')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.ColumnOrder')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsPrimaryKey')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsFiltered')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCombo')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayFormat'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Width'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategory'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategoryOrder'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewColumnDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewColumnDefinitions_Cursor;

FETCH NEXT FROM GridViewColumnDefinitions_Cursor
INTO
    @Guid,
    @GVCD_RowStatus,
    @GVCD_Name,
    @GVCD_SourceGridViewDefinitionID,
    @GVCD_ColumnOrder,
    @GVCD_IsPrimaryKey,
    @GVCD_IsHidden,
    @GVCD_IsFiltered,
    @GVCD_IsCombo,
    @GVCD_DisplayFormat,
    @GVCD_Width,
    @GVCD_SourceLanguageLabelID,
    @GVCD_TopHeaderCategory,
    @GVCD_TopHeaderCategoryOrder;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVCD_GridViewDefinitionGuid = NULL;
    SET @GVCD_LanguageLabelGuid = NULL;

    SET @Sql = N'
SELECT @GVCD_GridViewDefinitionGuid = gvd.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.GridViewDefinitions AS gvd
WHERE gvd.ID = @GVCD_SourceGridViewDefinitionID;

SELECT @GVCD_LanguageLabelGuid = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @GVCD_SourceLanguageLabelID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@GVCD_SourceGridViewDefinitionID BIGINT,
          @GVCD_SourceLanguageLabelID BIGINT,
          @GVCD_GridViewDefinitionGuid UNIQUEIDENTIFIER OUTPUT,
          @GVCD_LanguageLabelGuid UNIQUEIDENTIFIER OUTPUT',
        @GVCD_SourceGridViewDefinitionID = @GVCD_SourceGridViewDefinitionID,
        @GVCD_SourceLanguageLabelID = @GVCD_SourceLanguageLabelID,
        @GVCD_GridViewDefinitionGuid = @GVCD_GridViewDefinitionGuid OUTPUT,
        @GVCD_LanguageLabelGuid = @GVCD_LanguageLabelGuid OUTPUT;

    DECLARE @GridViewColumnDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridViewColumnDefinitionUpsert
        @Name = @GVCD_Name,
        @RowStatus = @GVCD_RowStatus,
        @GridViewDefinitionGuid = @GVCD_GridViewDefinitionGuid,
        @ColumnOrder = @GVCD_ColumnOrder,
        @IsPrimaryKey = @GVCD_IsPrimaryKey,
        @IsHidden = @GVCD_IsHidden,
        @IsFiltered = @GVCD_IsFiltered,
        @IsCombo = @GVCD_IsCombo,
        @DisplayFormat = @GVCD_DisplayFormat,
        @Width = @GVCD_Width,
        @LanguageLabelGuid = @GVCD_LanguageLabelGuid,
        @Guid = @GridViewColumnDefinitionGuid OUTPUT,
        @TopHeaderCategory = @GVCD_TopHeaderCategory,
        @TopHeaderCategoryOrder = @GVCD_TopHeaderCategoryOrder;

    FETCH NEXT FROM GridViewColumnDefinitions_Cursor
    INTO
        @Guid,
        @GVCD_RowStatus,
        @GVCD_Name,
        @GVCD_SourceGridViewDefinitionID,
        @GVCD_ColumnOrder,
        @GVCD_IsPrimaryKey,
        @GVCD_IsHidden,
        @GVCD_IsFiltered,
        @GVCD_IsCombo,
        @GVCD_DisplayFormat,
        @GVCD_Width,
        @GVCD_SourceLanguageLabelID,
        @GVCD_TopHeaderCategory,
        @GVCD_TopHeaderCategoryOrder;
END;

CLOSE GridViewColumnDefinitions_Cursor;
DEALLOCATE GridViewColumnDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewColumnDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view column definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   9. SUserInterface.DropDownListDefinitions
   ========================================================= */

DECLARE
    @DDL_Code NVARCHAR(20),
    @DDL_NameColumn NVARCHAR(254),
    @DDL_ValueColumn NVARCHAR(254),
    @DDL_SqlQuery NVARCHAR(MAX),
    @DDL_DefaultSortColumnName NVARCHAR(254),
    @DDL_IsDefaultColumn BIT,
    @DDL_IsDetailWindowed BIT,
    @DDL_DetailPageURI NVARCHAR(250),
    @DDL_SourceEntityTypeID BIGINT,
    @DDL_InformationPageURI NVARCHAR(250),
    @DDL_GroupColumn NVARCHAR(254),
    @DDL_ColourHexColumn NVARCHAR(7),
    @DDL_ExternalSearchPageUrl NVARCHAR(250),
    @DDL_EntityTypeGuid UNIQUEIDENTIFIER;

DECLARE DropDownListDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.NameColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ValueColumn'),
        ddlJsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultColumn')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.InformationPageUrl'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.GroupColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ColourHexColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ExternalSearchPageUrl')
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery'
    ) AS ddlJsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'DropDownListDefinitions'
    ORDER BY sr.SourceRowId;

OPEN DropDownListDefinitions_Cursor;

FETCH NEXT FROM DropDownListDefinitions_Cursor
INTO
    @Guid,
    @DDL_Code,
    @DDL_NameColumn,
    @DDL_ValueColumn,
    @DDL_SqlQuery,
    @DDL_DefaultSortColumnName,
    @DDL_IsDefaultColumn,
    @DDL_IsDetailWindowed,
    @DDL_DetailPageURI,
    @DDL_SourceEntityTypeID,
    @DDL_InformationPageURI,
    @DDL_GroupColumn,
    @DDL_ColourHexColumn,
    @DDL_ExternalSearchPageUrl;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @DDL_EntityTypeGuid = NULL;

    SET @Sql = N'
SELECT @DDL_EntityTypeGuid = et.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityTypes AS et
WHERE et.ID = @DDL_SourceEntityTypeID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@DDL_SourceEntityTypeID BIGINT,
          @DDL_EntityTypeGuid UNIQUEIDENTIFIER OUTPUT',
        @DDL_SourceEntityTypeID = @DDL_SourceEntityTypeID,
        @DDL_EntityTypeGuid = @DDL_EntityTypeGuid OUTPUT;

    DECLARE @DropDownListDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.DropDownListDefinitionUpsert
        @Code = @DDL_Code,
        @NameColumn = @DDL_NameColumn,
        @ValueColumn = @DDL_ValueColumn,
        @SqlQuery = @DDL_SqlQuery,
        @DefaultSortColumnName = @DDL_DefaultSortColumnName,
        @IsDefaultColumn = @DDL_IsDefaultColumn,
        @IsDetailWindowed = @DDL_IsDetailWindowed,
        @DetailPageURI = @DDL_DetailPageURI,
        @EntityTypeGuid = @DDL_EntityTypeGuid,
        @InformationPageURI = @DDL_InformationPageURI,
        @GroupColumn = @DDL_GroupColumn,
        @Guid = @DropDownListDefinitionGuid OUTPUT,
        @ColourHexColumn = @DDL_ColourHexColumn,
        @ExternalSearchPageUrl = @DDL_ExternalSearchPageUrl;

    FETCH NEXT FROM DropDownListDefinitions_Cursor
    INTO
        @Guid,
        @DDL_Code,
        @DDL_NameColumn,
        @DDL_ValueColumn,
        @DDL_SqlQuery,
        @DDL_DefaultSortColumnName,
        @DDL_IsDefaultColumn,
        @DDL_IsDetailWindowed,
        @DDL_DetailPageURI,
        @DDL_SourceEntityTypeID,
        @DDL_InformationPageURI,
        @DDL_GroupColumn,
        @DDL_ColourHexColumn,
        @DDL_ExternalSearchPageUrl;
END;

CLOSE DropDownListDefinitions_Cursor;
DEALLOCATE DropDownListDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyDropDownListDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Drop-down list definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   10. Labels
   ========================================================= */

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyLabels',
    @StepStatus = N'Succeeded',
    @Message = N'Labels are applied through SCore.LanguageLabels and SCore.LanguageLabelTranslations handlers.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations"]}';

UPDATE SMigration.Metadata_Run
SET
    RunStatus = N'AppliedUiMetadata',
    AppliedOnUtc = SYSUTCDATETIME()
WHERE Guid = @RunGuid
  AND RowStatus NOT IN (0,254);

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyMetadataComplete',
    @StepStatus = N'Succeeded',
    @Message = N'Core and UI metadata apply handlers completed.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations","SCore.EntityQueries","SCore.EntityProperties","SCore.EntityQueryParameters","SUserInterface.GridDefinitions","SUserInterface.GridViewDefinitions","SUserInterface.GridViewColumnDefinitions","SUserInterface.DropDownListDefinitions"]}';

COMMIT TRANSACTION;
END;
GO
