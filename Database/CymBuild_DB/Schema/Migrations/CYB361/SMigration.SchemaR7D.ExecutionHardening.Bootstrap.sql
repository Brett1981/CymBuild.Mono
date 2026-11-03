/*
    CYB-361 R7D execution-hardening bootstrap.

    Installs the persistent deployment-attempt and per-object checkpoint tables used by
    the controlled schema runner. This script is idempotent and executes inside the API
    bootstrap transaction and application lock. It does not alter application schema or
    business data.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF SCHEMA_ID(N'SMigration') IS NULL
    THROW 51442, 'R7D execution hardening requires schema [SMigration].', 1;

IF OBJECT_ID(N'[SMigration].[Schema_Run]', N'U') IS NULL
    THROW 51443, 'R7D execution hardening requires [SMigration].[Schema_Run].', 1;

IF OBJECT_ID(N'[SMigration].[SchemaDataObject_Ensure]', N'P') IS NULL
    THROW 51444, 'R7D execution hardening requires [SMigration].[SchemaDataObject_Ensure].', 1;

IF OBJECT_ID(N'[SMigration].[Schema_DeploymentAttempts]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_DeploymentAttempts]
    (
        [ID] BIGINT IDENTITY(1,1) NOT NULL,
        [Guid] UNIQUEIDENTIFIER NOT NULL,
        [RowStatus] TINYINT NOT NULL CONSTRAINT [DF_Schema_DeploymentAttempts_RowStatus] DEFAULT (1),
        [RunGuid] UNIQUEIDENTIFIER NOT NULL,
        [AttemptNumber] INT NOT NULL,
        [ExecutionId] NVARCHAR(150) NOT NULL,
        [TargetServerName] NVARCHAR(255) NOT NULL,
        [TargetDatabaseName] NVARCHAR(255) NOT NULL,
        [ReleaseReference] NVARCHAR(100) NOT NULL CONSTRAINT [DF_Schema_DeploymentAttempts_ReleaseReference] DEFAULT (N''),
        [DeploymentReference] NVARCHAR(100) NOT NULL CONSTRAINT [DF_Schema_DeploymentAttempts_DeploymentReference] DEFAULT (N''),
        [LockResource] NVARCHAR(255) NOT NULL,
        [PlanFingerprint] CHAR(64) NOT NULL,
        [ExpectedObjectCount] INT NOT NULL,
        [AttemptStatus] NVARCHAR(30) NOT NULL,
        [StartedOnUtc] DATETIME2(7) NOT NULL CONSTRAINT [DF_Schema_DeploymentAttempts_StartedOnUtc] DEFAULT (SYSUTCDATETIME()),
        [CompletedOnUtc] DATETIME2(7) NULL,
        [FailureMessage] NVARCHAR(2000) NOT NULL CONSTRAINT [DF_Schema_DeploymentAttempts_FailureMessage] DEFAULT (N''),
        [SummaryJson] NVARCHAR(MAX) NOT NULL CONSTRAINT [DF_Schema_DeploymentAttempts_SummaryJson] DEFAULT (N'{}'),
        CONSTRAINT [PK_Schema_DeploymentAttempts] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_DeploymentAttempts_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS indexDefinition
    WHERE indexDefinition.[object_id] = OBJECT_ID(N'[SMigration].[Schema_DeploymentAttempts]', N'U')
      AND indexDefinition.[name] = N'UX_Schema_DeploymentAttempts_Run_Attempt_Active'
)
BEGIN
    CREATE UNIQUE INDEX [UX_Schema_DeploymentAttempts_Run_Attempt_Active]
        ON [SMigration].[Schema_DeploymentAttempts] ([RunGuid], [AttemptNumber])
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS indexDefinition
    WHERE indexDefinition.[object_id] = OBJECT_ID(N'[SMigration].[Schema_DeploymentAttempts]', N'U')
      AND indexDefinition.[name] = N'IX_Schema_DeploymentAttempts_Target_Active'
)
BEGIN
    CREATE INDEX [IX_Schema_DeploymentAttempts_Target_Active]
        ON [SMigration].[Schema_DeploymentAttempts] ([TargetDatabaseName], [StartedOnUtc])
        INCLUDE ([RunGuid], [AttemptStatus], [DeploymentReference], [PlanFingerprint])
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;

IF OBJECT_ID(N'[SMigration].[Schema_DeploymentObjectCheckpoints]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_DeploymentObjectCheckpoints]
    (
        [ID] BIGINT IDENTITY(1,1) NOT NULL,
        [Guid] UNIQUEIDENTIFIER NOT NULL,
        [RowStatus] TINYINT NOT NULL CONSTRAINT [DF_Schema_DeploymentObjectCheckpoints_RowStatus] DEFAULT (1),
        [RunGuid] UNIQUEIDENTIFIER NOT NULL,
        [AttemptGuid] UNIQUEIDENTIFIER NOT NULL,
        [ComparisonGuid] UNIQUEIDENTIFIER NOT NULL,
        [ObjectType] NVARCHAR(50) NOT NULL,
        [SchemaName] NVARCHAR(128) NOT NULL,
        [ObjectName] NVARCHAR(512) NOT NULL,
        [ParentObjectName] NVARCHAR(512) NOT NULL CONSTRAINT [DF_Schema_DeploymentObjectCheckpoints_ParentObjectName] DEFAULT (N''),
        [CheckpointPhase] NVARCHAR(30) NOT NULL,
        [CheckpointStatus] NVARCHAR(30) NOT NULL,
        [ExpectedHash] NVARCHAR(128) NOT NULL CONSTRAINT [DF_Schema_DeploymentObjectCheckpoints_ExpectedHash] DEFAULT (N''),
        [ObservedHash] NVARCHAR(128) NOT NULL CONSTRAINT [DF_Schema_DeploymentObjectCheckpoints_ObservedHash] DEFAULT (N''),
        [Message] NVARCHAR(2000) NOT NULL CONSTRAINT [DF_Schema_DeploymentObjectCheckpoints_Message] DEFAULT (N''),
        [DetailsJson] NVARCHAR(MAX) NOT NULL CONSTRAINT [DF_Schema_DeploymentObjectCheckpoints_DetailsJson] DEFAULT (N'{}'),
        [CreatedOnUtc] DATETIME2(7) NOT NULL CONSTRAINT [DF_Schema_DeploymentObjectCheckpoints_CreatedOnUtc] DEFAULT (SYSUTCDATETIME()),
        [UpdatedOnUtc] DATETIME2(7) NOT NULL CONSTRAINT [DF_Schema_DeploymentObjectCheckpoints_UpdatedOnUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Schema_DeploymentObjectCheckpoints] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_DeploymentObjectCheckpoints_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS indexDefinition
    WHERE indexDefinition.[object_id] = OBJECT_ID(N'[SMigration].[Schema_DeploymentObjectCheckpoints]', N'U')
      AND indexDefinition.[name] = N'UX_Schema_DeploymentObjectCheckpoints_Attempt_Object_Phase_Active'
)
BEGIN
    CREATE UNIQUE INDEX [UX_Schema_DeploymentObjectCheckpoints_Attempt_Object_Phase_Active]
        ON [SMigration].[Schema_DeploymentObjectCheckpoints]
        (
            [AttemptGuid],
            [ComparisonGuid],
            [CheckpointPhase]
        )
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS indexDefinition
    WHERE indexDefinition.[object_id] = OBJECT_ID(N'[SMigration].[Schema_DeploymentObjectCheckpoints]', N'U')
      AND indexDefinition.[name] = N'IX_Schema_DeploymentObjectCheckpoints_Run_Active'
)
BEGIN
    CREATE INDEX [IX_Schema_DeploymentObjectCheckpoints_Run_Active]
        ON [SMigration].[Schema_DeploymentObjectCheckpoints] ([RunGuid], [AttemptGuid], [ID])
        INCLUDE ([ComparisonGuid], [CheckpointPhase], [CheckpointStatus], [ObservedHash])
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;

/*
    R7D audit records are platform-managed entities. Give each audit table its own
    deterministic EntityType and main EntityHoBT before any attempt/checkpoint
    DataObject is created. Existing audit DataObjects created by the earlier fallback
    contract are repaired to the exact owner without changing workflow state.
*/
DECLARE @R7DOwnership TABLE
(
    [TableName] SYSNAME NOT NULL PRIMARY KEY,
    [EntityTypeGuid] UNIQUEIDENTIFIER NOT NULL,
    [EntityTypeName] NVARCHAR(250) NOT NULL,
    [EntityHoBTGuid] UNIQUEIDENTIFIER NOT NULL
);

INSERT INTO @R7DOwnership
(
    [TableName],
    [EntityTypeGuid],
    [EntityTypeName],
    [EntityHoBTGuid]
)
VALUES
    (
        N'Schema_DeploymentAttempts',
        'D7A10001-3610-47D0-A001-000000000001',
        N'Schema Deployment Attempts',
        'D7A10001-3610-47D0-A002-000000000001'
    ),
    (
        N'Schema_DeploymentObjectCheckpoints',
        'D7A10002-3610-47D0-A001-000000000002',
        N'Schema Deployment Object Checkpoints',
        'D7A10002-3610-47D0-A002-000000000002'
    );

DECLARE @EntityTypesOwnerId INT;
DECLARE @EntityHobtsOwnerId INT;
DECLARE @LegacyFallbackEntityTypeId INT;
DECLARE @TechnicalLanguageLabelId INT;
DECLARE @TechnicalIconId INT;

SELECT TOP (1)
    @EntityTypesOwnerId = entityHobt.[EntityTypeID]
FROM [SCore].[EntityHobts] AS entityHobt
INNER JOIN [SCore].[EntityTypes] AS entityType
    ON entityType.[ID] = entityHobt.[EntityTypeID]
WHERE entityHobt.[SchemaName] = N'SCore'
  AND entityHobt.[ObjectName] = N'EntityTypes'
  AND entityHobt.[RowStatus] <> 0
  AND entityHobt.[RowStatus] <> 254
  AND entityType.[RowStatus] <> 0
  AND entityType.[RowStatus] <> 254
ORDER BY entityHobt.[ID];

SELECT TOP (1)
    @EntityHobtsOwnerId = entityHobt.[EntityTypeID]
FROM [SCore].[EntityHobts] AS entityHobt
INNER JOIN [SCore].[EntityTypes] AS entityType
    ON entityType.[ID] = entityHobt.[EntityTypeID]
WHERE entityHobt.[SchemaName] = N'SCore'
  AND entityHobt.[ObjectName] = N'EntityHobts'
  AND entityHobt.[RowStatus] <> 0
  AND entityHobt.[RowStatus] <> 254
  AND entityType.[RowStatus] <> 0
  AND entityType.[RowStatus] <> 254
ORDER BY entityHobt.[ID];

/*
    Reproduce the exact fallback order used by the pre-R7D strict helper. This
    identifies only the historical owner that may legitimately exist on audit
    DataObjects created before exact audit EntityTypes and EntityHoBTs existed.
*/
SELECT TOP (1)
    @LegacyFallbackEntityTypeId = entityType.[ID]
FROM [SCore].[EntityTypes] AS entityType
WHERE entityType.[Name] = N'EntityTypes'
  AND entityType.[RowStatus] <> 0
  AND entityType.[RowStatus] <> 254
ORDER BY entityType.[ID];

IF @LegacyFallbackEntityTypeId IS NULL
BEGIN
    SELECT TOP (1)
        @LegacyFallbackEntityTypeId = entityType.[ID]
    FROM [SCore].[EntityTypes] AS entityType
    WHERE entityType.[RowStatus] <> 0
      AND entityType.[RowStatus] <> 254
    ORDER BY entityType.[ID];
END;

SELECT
    @TechnicalLanguageLabelId = entityType.[LanguageLabelID],
    @TechnicalIconId = entityType.[IconId]
FROM [SCore].[EntityTypes] AS entityType
WHERE entityType.[ID] = @EntityTypesOwnerId;

IF @EntityTypesOwnerId IS NULL
   OR @EntityHobtsOwnerId IS NULL
   OR @LegacyFallbackEntityTypeId IS NULL
   OR @TechnicalLanguageLabelId IS NULL
   OR @TechnicalIconId IS NULL
    THROW 51447, 'R7D audit ownership requires exact active SCore.EntityTypes and SCore.EntityHobts metadata ownership and a resolvable historical fallback.', 1;

DECLARE @AuditTableName SYSNAME;
DECLARE @AuditEntityTypeGuid UNIQUEIDENTIFIER;
DECLARE @AuditEntityTypeName NVARCHAR(250);
DECLARE @AuditEntityHoBTGuid UNIQUEIDENTIFIER;
DECLARE @AuditEntityTypeId INT;

DECLARE R7DOwnershipCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        ownership.[TableName],
        ownership.[EntityTypeGuid],
        ownership.[EntityTypeName],
        ownership.[EntityHoBTGuid]
    FROM @R7DOwnership AS ownership
    ORDER BY ownership.[TableName];

OPEN R7DOwnershipCursor;
FETCH NEXT FROM R7DOwnershipCursor
INTO @AuditTableName, @AuditEntityTypeGuid, @AuditEntityTypeName, @AuditEntityHoBTGuid;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM [SCore].[EntityTypes] AS entityType
        WHERE (entityType.[Guid] = @AuditEntityTypeGuid OR entityType.[Name] = @AuditEntityTypeName)
          AND (entityType.[Guid] <> @AuditEntityTypeGuid OR entityType.[Name] <> @AuditEntityTypeName)
    )
        THROW 51448, 'R7D audit EntityType stable identity conflicts with existing metadata.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [SCore].[DataObjects] AS dataObject
        WHERE dataObject.[Guid] = @AuditEntityTypeGuid
    )
    AND NOT EXISTS
    (
        SELECT 1
        FROM [SCore].[EntityTypes] AS entityType
        WHERE entityType.[Guid] = @AuditEntityTypeGuid
    )
        THROW 51456, 'R7D audit EntityType Guid already belongs to an unrelated DataObject.', 1;

    EXEC [SMigration].[SchemaDataObject_Ensure]
        @Guid = @AuditEntityTypeGuid,
        @SchemeName = N'SCore',
        @ObjectName = N'EntityTypes',
        @RequireExactEntityType = 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [SCore].[EntityTypes] AS entityType
        WHERE entityType.[Guid] = @AuditEntityTypeGuid
    )
    BEGIN
        INSERT INTO [SCore].[EntityTypes]
        (
            [RowStatus],
            [Guid],
            [Name],
            [IsReadOnlyOffline],
            [IsRequiredSystemData],
            [HasDocuments],
            [LanguageLabelID],
            [DoNotTrackChanges],
            [IsRootEntity],
            [DetailPageUrl],
            [IconId],
            [IsMetaData],
            [IsDeletable],
            [IsOnBoarding]
        )
        VALUES
        (
            1,
            @AuditEntityTypeGuid,
            @AuditEntityTypeName,
            0,
            1,
            0,
            @TechnicalLanguageLabelId,
            1,
            0,
            N'',
            @TechnicalIconId,
            1,
            0,
            0
        );
    END;

    SET @AuditEntityTypeId = NULL;

    SELECT
        @AuditEntityTypeId = entityType.[ID]
    FROM [SCore].[EntityTypes] AS entityType
    WHERE entityType.[Guid] = @AuditEntityTypeGuid
      AND entityType.[Name] = @AuditEntityTypeName
      AND entityType.[RowStatus] <> 0
      AND entityType.[RowStatus] <> 254;

    IF @AuditEntityTypeId IS NULL
        THROW 51449, 'R7D audit EntityType is missing or inactive after ownership bootstrap.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [SCore].[EntityHobts] AS entityHobt
        WHERE
            (
                entityHobt.[Guid] = @AuditEntityHoBTGuid
                OR
                (
                    entityHobt.[SchemaName] = N'SMigration'
                    AND entityHobt.[ObjectName] = @AuditTableName
                    AND entityHobt.[RowStatus] <> 0
                    AND entityHobt.[RowStatus] <> 254
                )
            )
          AND
            (
                entityHobt.[Guid] <> @AuditEntityHoBTGuid
                OR entityHobt.[SchemaName] <> N'SMigration'
                OR entityHobt.[ObjectName] <> @AuditTableName
                OR entityHobt.[EntityTypeID] <> @AuditEntityTypeId
            )
    )
        THROW 51450, 'R7D audit EntityHoBT stable identity conflicts with existing metadata.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [SCore].[DataObjects] AS dataObject
        WHERE dataObject.[Guid] = @AuditEntityHoBTGuid
    )
    AND NOT EXISTS
    (
        SELECT 1
        FROM [SCore].[EntityHobts] AS entityHobt
        WHERE entityHobt.[Guid] = @AuditEntityHoBTGuid
    )
        THROW 51457, 'R7D audit EntityHoBT Guid already belongs to an unrelated DataObject.', 1;

    EXEC [SMigration].[SchemaDataObject_Ensure]
        @Guid = @AuditEntityHoBTGuid,
        @SchemeName = N'SCore',
        @ObjectName = N'EntityHobts',
        @RequireExactEntityType = 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [SCore].[EntityHobts] AS entityHobt
        WHERE entityHobt.[Guid] = @AuditEntityHoBTGuid
    )
    BEGIN
        INSERT INTO [SCore].[EntityHobts]
        (
            [RowStatus],
            [Guid],
            [SchemaName],
            [ObjectName],
            [EntityTypeID],
            [ObjectType],
            [IsMainHoBT],
            [IsReadOnlyOffline]
        )
        VALUES
        (
            1,
            @AuditEntityHoBTGuid,
            N'SMigration',
            @AuditTableName,
            @AuditEntityTypeId,
            N'U',
            1,
            0
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [SCore].[EntityHobts] AS entityHobt
        WHERE entityHobt.[Guid] = @AuditEntityHoBTGuid
          AND entityHobt.[SchemaName] = N'SMigration'
          AND entityHobt.[ObjectName] = @AuditTableName
          AND entityHobt.[EntityTypeID] = @AuditEntityTypeId
          AND entityHobt.[ObjectType] = N'U'
          AND entityHobt.[IsMainHoBT] = 1
          AND entityHobt.[RowStatus] <> 0
          AND entityHobt.[RowStatus] <> 254
    )
        THROW 51451, 'R7D audit EntityHoBT is missing, inactive or incorrectly owned after bootstrap.', 1;

    FETCH NEXT FROM R7DOwnershipCursor
    INTO @AuditTableName, @AuditEntityTypeGuid, @AuditEntityTypeName, @AuditEntityHoBTGuid;
END;

CLOSE R7DOwnershipCursor;
DEALLOCATE R7DOwnershipCursor;

DECLARE @AttemptEntityTypeId INT;
DECLARE @CheckpointEntityTypeId INT;

SELECT
    @AttemptEntityTypeId = entityHobt.[EntityTypeID]
FROM [SCore].[EntityHobts] AS entityHobt
WHERE entityHobt.[SchemaName] = N'SMigration'
  AND entityHobt.[ObjectName] = N'Schema_DeploymentAttempts'
  AND entityHobt.[Guid] = 'D7A10001-3610-47D0-A002-000000000001'
  AND entityHobt.[RowStatus] <> 0
  AND entityHobt.[RowStatus] <> 254;

SELECT
    @CheckpointEntityTypeId = entityHobt.[EntityTypeID]
FROM [SCore].[EntityHobts] AS entityHobt
WHERE entityHobt.[SchemaName] = N'SMigration'
  AND entityHobt.[ObjectName] = N'Schema_DeploymentObjectCheckpoints'
  AND entityHobt.[Guid] = 'D7A10002-3610-47D0-A002-000000000002'
  AND entityHobt.[RowStatus] <> 0
  AND entityHobt.[RowStatus] <> 254;

INSERT INTO [SCore].[DataObjects]
(
    [Guid],
    [RowStatus],
    [EntityTypeId]
)
SELECT
    attempt.[Guid],
    1,
    @AttemptEntityTypeId
FROM [SMigration].[Schema_DeploymentAttempts] AS attempt
WHERE NOT EXISTS
(
    SELECT 1
    FROM [SCore].[DataObjects] AS dataObject
    WHERE dataObject.[Guid] = attempt.[Guid]
);

INSERT INTO [SCore].[DataObjects]
(
    [Guid],
    [RowStatus],
    [EntityTypeId]
)
SELECT
    [checkpoint].[Guid],
    1,
    @CheckpointEntityTypeId
FROM [SMigration].[Schema_DeploymentObjectCheckpoints] AS [checkpoint]
WHERE NOT EXISTS
(
    SELECT 1
    FROM [SCore].[DataObjects] AS dataObject
    WHERE dataObject.[Guid] = [checkpoint].[Guid]
);

IF EXISTS
(
    SELECT 1
    FROM [SMigration].[Schema_DeploymentAttempts] AS attempt
    INNER JOIN [SCore].[DataObjects] AS dataObject
        ON dataObject.[Guid] = attempt.[Guid]
    WHERE dataObject.[EntityTypeId] <> @AttemptEntityTypeId
      AND dataObject.[EntityTypeId] <> @LegacyFallbackEntityTypeId
)
    THROW 51454, 'R7D deployment-attempt DataObject has an unexpected existing EntityType and will not be reassigned.', 1;

IF EXISTS
(
    SELECT 1
    FROM [SMigration].[Schema_DeploymentObjectCheckpoints] AS [checkpoint]
    INNER JOIN [SCore].[DataObjects] AS dataObject
        ON dataObject.[Guid] = [checkpoint].[Guid]
    WHERE dataObject.[EntityTypeId] <> @CheckpointEntityTypeId
      AND dataObject.[EntityTypeId] <> @LegacyFallbackEntityTypeId
)
    THROW 51455, 'R7D deployment-checkpoint DataObject has an unexpected existing EntityType and will not be reassigned.', 1;

UPDATE dataObject
SET dataObject.[EntityTypeId] = @AttemptEntityTypeId
FROM [SCore].[DataObjects] AS dataObject
INNER JOIN [SMigration].[Schema_DeploymentAttempts] AS attempt
    ON attempt.[Guid] = dataObject.[Guid]
WHERE dataObject.[EntityTypeId] = @LegacyFallbackEntityTypeId;

UPDATE dataObject
SET dataObject.[EntityTypeId] = @CheckpointEntityTypeId
FROM [SCore].[DataObjects] AS dataObject
INNER JOIN [SMigration].[Schema_DeploymentObjectCheckpoints] AS [checkpoint]
    ON [checkpoint].[Guid] = dataObject.[Guid]
WHERE dataObject.[EntityTypeId] = @LegacyFallbackEntityTypeId;

IF EXISTS
(
    SELECT 1
    FROM [SMigration].[Schema_DeploymentAttempts] AS attempt
    LEFT JOIN [SCore].[DataObjects] AS dataObject
        ON dataObject.[Guid] = attempt.[Guid]
    WHERE attempt.[RowStatus] <> 0
      AND attempt.[RowStatus] <> 254
      AND
      (
          dataObject.[Guid] IS NULL
          OR dataObject.[RowStatus] = 0
          OR dataObject.[RowStatus] = 254
          OR dataObject.[EntityTypeId] <> @AttemptEntityTypeId
      )
)
    THROW 51452, 'R7D active deployment-attempt DataObject ownership verification failed.', 1;

IF EXISTS
(
    SELECT 1
    FROM [SMigration].[Schema_DeploymentObjectCheckpoints] AS [checkpoint]
    LEFT JOIN [SCore].[DataObjects] AS dataObject
        ON dataObject.[Guid] = [checkpoint].[Guid]
    WHERE [checkpoint].[RowStatus] <> 0
      AND [checkpoint].[RowStatus] <> 254
      AND
      (
          dataObject.[Guid] IS NULL
          OR dataObject.[RowStatus] = 0
          OR dataObject.[RowStatus] = 254
          OR dataObject.[EntityTypeId] <> @CheckpointEntityTypeId
      )
)
    THROW 51453, 'R7D active deployment-checkpoint DataObject ownership verification failed.', 1;

DECLARE @RequiredColumns TABLE
(
    [TableName] SYSNAME NOT NULL,
    [ColumnName] SYSNAME NOT NULL
);

INSERT INTO @RequiredColumns ([TableName], [ColumnName])
VALUES
    (N'Schema_DeploymentAttempts', N'Guid'),
    (N'Schema_DeploymentAttempts', N'RunGuid'),
    (N'Schema_DeploymentAttempts', N'AttemptNumber'),
    (N'Schema_DeploymentAttempts', N'ExecutionId'),
    (N'Schema_DeploymentAttempts', N'PlanFingerprint'),
    (N'Schema_DeploymentAttempts', N'AttemptStatus'),
    (N'Schema_DeploymentAttempts', N'SummaryJson'),
    (N'Schema_DeploymentObjectCheckpoints', N'Guid'),
    (N'Schema_DeploymentObjectCheckpoints', N'RunGuid'),
    (N'Schema_DeploymentObjectCheckpoints', N'AttemptGuid'),
    (N'Schema_DeploymentObjectCheckpoints', N'ComparisonGuid'),
    (N'Schema_DeploymentObjectCheckpoints', N'CheckpointPhase'),
    (N'Schema_DeploymentObjectCheckpoints', N'CheckpointStatus'),
    (N'Schema_DeploymentObjectCheckpoints', N'ExpectedHash'),
    (N'Schema_DeploymentObjectCheckpoints', N'ObservedHash');

IF EXISTS
(
    SELECT requiredColumn.[TableName], requiredColumn.[ColumnName]
    FROM @RequiredColumns AS requiredColumn
    EXCEPT
    SELECT tableDefinition.[name], columnDefinition.[name]
    FROM sys.tables AS tableDefinition
    INNER JOIN sys.schemas AS schemaDefinition
        ON schemaDefinition.[schema_id] = tableDefinition.[schema_id]
    INNER JOIN sys.columns AS columnDefinition
        ON columnDefinition.[object_id] = tableDefinition.[object_id]
    WHERE schemaDefinition.[name] = N'SMigration'
)
BEGIN
    THROW 51445, 'R7D execution-hardening tables have an incompatible partial shape.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE [object_id] = OBJECT_ID(N'[SMigration].[Schema_DeploymentAttempts]', N'U')
      AND [name] = N'UX_Schema_DeploymentAttempts_Run_Attempt_Active'
)
OR NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE [object_id] = OBJECT_ID(N'[SMigration].[Schema_DeploymentObjectCheckpoints]', N'U')
      AND [name] = N'UX_Schema_DeploymentObjectCheckpoints_Attempt_Object_Phase_Active'
)
BEGIN
    THROW 51446, 'R7D execution-hardening index verification failed.', 1;
END;
