/*
    CYB-584: "An insufficient number of arguments were supplied for ... SJob.ActivitiesValidate".

    CYB-333 added @RibaStageGuid and @IsPartOfAgreedFee to SJob.ActivitiesValidate and
    @IsPartOfAgreedFee to SJob.ActivitiesUpsert, but the two Activities EntityQueries (manual
    statements) were never updated. This brings CymBuild_Dev's metadata in line; the metadata
    migration then carries it DEV -> QA -> UAT. Do not run this on QA, UAT or LIVE.

    Safe to re-run. Stops (THROW) instead of guessing if DEV is not in the expected state.

    sqlcmd -S "10.100.34.114\general" -d CymBuild_Dev -E -C -b -f 65001 -i CYB-584_CymBuild_Dev_ActivityQueryMetadata.sql
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME() <> N'CymBuild_Dev'
    THROW 60584, N'CYB-584 metadata script is for CymBuild_Dev only. Other environments get it through the metadata migration.', 1;
GO

BEGIN TRANSACTION;

DECLARE @ValidateQueryGuid UNIQUEIDENTIFIER = '6ceb6ed0-88c7-4237-81ba-fea5d0c7c819',
        @UpsertQueryGuid   UNIQUEIDENTIFIER = '2149afc2-38c9-4080-9e6d-97b87571703e',
        @GuidTypeGuid      UNIQUEIDENTIFIER = '53c3df84-683d-4914-97a6-a2a4b753bbdf', -- UNIQUEIDENTIFIER
        @BitTypeGuid       UNIQUEIDENTIFIER = '05c7a29c-8271-4385-a0e3-c0f0e2d3bf9f', -- BIT
        @RibaStagePropertyGuid UNIQUEIDENTIFIER,
        @AgreedFeePropertyGuid UNIQUEIDENTIFIER;

/* 0. Preconditions: the CYB-333 schema is deployed and the entity properties exist. */
IF NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'SJob.ActivitiesValidate') AND name = N'@IsPartOfAgreedFee')
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'SJob.ActivitiesValidate') AND name = N'@RibaStageGuid')
    THROW 60585, N'SJob.ActivitiesValidate has no CYB-333 parameters here - deploy the 26.4 schema first.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'SJob.ActivitiesUpsert') AND name = N'@IsPartOfAgreedFee')
    THROW 60586, N'SJob.ActivitiesUpsert has no @IsPartOfAgreedFee parameter here - deploy the 26.4 schema first.', 1;

SELECT  @RibaStagePropertyGuid = ep.Guid
FROM    SCore.EntityProperties AS ep
JOIN    SCore.EntityHobts AS h ON (h.ID = ep.EntityHoBTID)
WHERE   h.SchemaName = N'SJob' AND h.ObjectName = N'Activities'
  AND   ep.Name = N'RibaStageId' AND ep.RowStatus NOT IN (0, 254);

SELECT  @AgreedFeePropertyGuid = ep.Guid
FROM    SCore.EntityProperties AS ep
JOIN    SCore.EntityHobts AS h ON (h.ID = ep.EntityHoBTID)
WHERE   h.SchemaName = N'SJob' AND h.ObjectName = N'Activities'
  AND   ep.Name = N'IsPartOfAgreedFee' AND ep.RowStatus NOT IN (0, 254);

IF @RibaStagePropertyGuid IS NULL
    THROW 60587, N'SJob.Activities.RibaStageId entity property not found - stop and inspect.', 1;

IF @AgreedFeePropertyGuid IS NULL
    THROW 60588, N'SJob.Activities.IsPartOfAgreedFee entity property not found. CYB-333 needs it on the Activity form (label, group, position) - create it in the metadata UI first, then re-run.', 1;

/* 1. Statements (manual - EntityQueryUpsert does not regenerate them). */
DECLARE @Queries TABLE (QueryGuid UNIQUEIDENTIFIER, Anchor NVARCHAR(200), Replacement NVARCHAR(400), DoneMarker NVARCHAR(100));
INSERT @Queries (QueryGuid, Anchor, Replacement, DoneMarker)
VALUES  (@ValidateQueryGuid, N'@ActivityTypeGuid)', N'@ActivityTypeGuid, @RibaStageGuid, @IsPartOfAgreedFee)', N'%@IsPartOfAgreedFee%'),
        (@UpsertQueryGuid,   N'@NewExpiryDate = @NewExpiryDate', N'@NewExpiryDate = @NewExpiryDate, @IsPartOfAgreedFee = @IsPartOfAgreedFee', N'%@IsPartOfAgreedFee%');

DECLARE @QGuid UNIQUEIDENTIFIER, @Anchor NVARCHAR(200), @Replacement NVARCHAR(400), @DoneMarker NVARCHAR(100),
        @Statement NVARCHAR(MAX), @Name NVARCHAR(250), @RowStatus TINYINT, @EntityTypeGuid UNIQUEIDENTIFIER, @HobtGuid UNIQUEIDENTIFIER,
        @IsDefaultCreate BIT, @IsDefaultRead BIT, @IsDefaultUpdate BIT, @IsDefaultDelete BIT, @IsScalarExecute BIT, @IsDefaultValidation BIT,
        @IsDefaultDataPills BIT, @IsMergeDocumentQuery BIT, @IsProgressData BIT, @SchemaName NVARCHAR(255), @ObjectName NVARCHAR(255),
        @Guid UNIQUEIDENTIFIER;

DECLARE query_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT QueryGuid, Anchor, Replacement, DoneMarker FROM @Queries;
OPEN query_cursor;
FETCH NEXT FROM query_cursor INTO @QGuid, @Anchor, @Replacement, @DoneMarker;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM SCore.EntityQueries WHERE Guid = @QGuid AND RowStatus NOT IN (0, 254))
        THROW 60589, N'Activities EntityQuery not found - stop and inspect.', 1;

    IF EXISTS (SELECT 1 FROM SCore.EntityQueries WHERE Guid = @QGuid AND Statement LIKE @DoneMarker)
        PRINT N'Statement already updated: ' + CONVERT(NVARCHAR(36), @QGuid);
    ELSE
    BEGIN
        -- REPLACE changes every occurrence, so the anchor must appear exactly once.
        IF NOT EXISTS (SELECT 1 FROM SCore.EntityQueries WHERE Guid = @QGuid
                       AND (DATALENGTH(Statement) - DATALENGTH(REPLACE(Statement, @Anchor, N''))) = DATALENGTH(@Anchor))
            THROW 60590, N'Activities EntityQuery statement anchor not found exactly once - statement has drifted, stop and inspect.', 1;

        SELECT  @Statement = REPLACE(eq.Statement, @Anchor, @Replacement),
                @Name = eq.Name, @RowStatus = eq.RowStatus, @EntityTypeGuid = et.Guid, @HobtGuid = h.Guid,
                @IsDefaultCreate = eq.IsDefaultCreate, @IsDefaultRead = eq.IsDefaultRead, @IsDefaultUpdate = eq.IsDefaultUpdate,
                @IsDefaultDelete = eq.IsDefaultDelete, @IsScalarExecute = eq.IsScalarExecute, @IsDefaultValidation = eq.IsDefaultValidation,
                @IsDefaultDataPills = eq.IsDefaultDataPills, @IsMergeDocumentQuery = eq.IsMergeDocumentQuery, @IsProgressData = eq.IsProgressData,
                @SchemaName = eq.SchemaName, @ObjectName = eq.ObjectName
        FROM    SCore.EntityQueries AS eq
        JOIN    SCore.EntityTypes AS et ON (et.ID = eq.EntityTypeID)
        JOIN    SCore.EntityHobts AS h ON (h.ID = eq.EntityHoBTID)
        WHERE   eq.Guid = @QGuid;

        SET @Guid = @QGuid;
        EXEC SCore.EntityQueryUpsert
             @Name = @Name, @RowStatus = @RowStatus, @Statement = @Statement, @EntityTypeGuid = @EntityTypeGuid,
             @IsDefaultCreate = @IsDefaultCreate, @IsDefaultRead = @IsDefaultRead, @IsDefaultUpdate = @IsDefaultUpdate,
             @IsDefaultDelete = @IsDefaultDelete, @IsScalarExecute = @IsScalarExecute, @IsDefaultValidation = @IsDefaultValidation,
             @EntityHoBTGuid = @HobtGuid, @IsDefaultDataPills = @IsDefaultDataPills, @IsMergeDocumentQuery = @IsMergeDocumentQuery,
             @IsProgressData = @IsProgressData, @SchemaName = @SchemaName, @ObjectName = @ObjectName,
             @IsManualStatement = 1, @Guid = @Guid OUTPUT;

        PRINT N'Statement updated: ' + @Name;
    END;

    FETCH NEXT FROM query_cursor INTO @QGuid, @Anchor, @Replacement, @DoneMarker;
END;
CLOSE query_cursor;
DEALLOCATE query_cursor;

/* 2. Parameter rows. Fixed Guids so DEV, QA and UAT end up with the same rows. */
DECLARE @Params TABLE (QueryGuid UNIQUEIDENTIFIER, Name NVARCHAR(250), ParamGuid UNIQUEIDENTIFIER, DataTypeGuid UNIQUEIDENTIFIER, PropertyGuid UNIQUEIDENTIFIER);
INSERT @Params (QueryGuid, Name, ParamGuid, DataTypeGuid, PropertyGuid)
VALUES  (@ValidateQueryGuid, N'@RibaStageGuid',     '663b46f5-89aa-4d72-a41b-61c1286328de', @GuidTypeGuid, @RibaStagePropertyGuid),
        (@ValidateQueryGuid, N'@IsPartOfAgreedFee', '5e087e6b-c08d-4513-8bd7-96404ee7c990', @BitTypeGuid,  @AgreedFeePropertyGuid),
        (@UpsertQueryGuid,   N'@IsPartOfAgreedFee', 'ee298109-5329-45bc-a0ef-190681363320', @BitTypeGuid,  @AgreedFeePropertyGuid);

DECLARE @PName NVARCHAR(250), @PGuid UNIQUEIDENTIFIER, @PType UNIQUEIDENTIFIER, @PProp UNIQUEIDENTIFIER;
DECLARE param_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT QueryGuid, Name, ParamGuid, DataTypeGuid, PropertyGuid FROM @Params;
OPEN param_cursor;
FETCH NEXT FROM param_cursor INTO @QGuid, @PName, @PGuid, @PType, @PProp;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Reuse an existing row for this name if one is already there.
    SELECT  @PGuid = eqp.Guid
    FROM    SCore.EntityQueryParameters AS eqp
    JOIN    SCore.EntityQueries AS eq ON (eq.ID = eqp.EntityQueryID)
    WHERE   eq.Guid = @QGuid AND eqp.Name = @PName;

    EXEC SCore.EntityQueryParameterUpsert
         @Name = @PName, @RowStatus = 1, @EntityQueryGuid = @QGuid,
         @EntityDataTypeGuid = @PType, @MappedEntityPropertyGuid = @PProp,
         @DefaultValue = N'', @IsInput = 1, @IsOutput = 0, @IsReturnColumn = 0,
         @Guid = @PGuid OUTPUT;

    PRINT N'Parameter upserted: ' + @PName;
    FETCH NEXT FROM param_cursor INTO @QGuid, @PName, @PGuid, @PType, @PProp;
END;
CLOSE param_cursor;
DEALLOCATE param_cursor;

COMMIT TRANSACTION;
GO

/* 3. Verification - every row should read OK. */
SELECT  N'Validate statement' AS [Check],
        CASE WHEN EXISTS (SELECT 1 FROM SCore.EntityQueries WHERE Guid = '6ceb6ed0-88c7-4237-81ba-fea5d0c7c819'
                          AND Statement LIKE N'%@RibaStageGuid%' AND Statement LIKE N'%@IsPartOfAgreedFee%') THEN N'OK' ELSE N'FAIL' END AS Result
UNION ALL
SELECT  N'Upsert statement',
        CASE WHEN EXISTS (SELECT 1 FROM SCore.EntityQueries WHERE Guid = '2149afc2-38c9-4080-9e6d-97b87571703e'
                          AND Statement LIKE N'%@IsPartOfAgreedFee = @IsPartOfAgreedFee%') THEN N'OK' ELSE N'FAIL' END
UNION ALL
SELECT  N'Parameters (3)',
        CASE WHEN (SELECT COUNT(*) FROM SCore.EntityQueryParameters AS p JOIN SCore.EntityQueries AS q ON (q.ID = p.EntityQueryID)
                   WHERE p.RowStatus NOT IN (0, 254)
                     AND ((q.Guid = '6ceb6ed0-88c7-4237-81ba-fea5d0c7c819' AND p.Name IN (N'@RibaStageGuid', N'@IsPartOfAgreedFee'))
                       OR (q.Guid = '2149afc2-38c9-4080-9e6d-97b87571703e' AND p.Name = N'@IsPartOfAgreedFee'))) = 3
             THEN N'OK' ELSE N'FAIL' END;
GO
