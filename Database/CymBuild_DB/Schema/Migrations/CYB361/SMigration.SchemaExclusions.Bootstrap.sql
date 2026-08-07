/*
    CYB-361 R39 - source-authoritative Schema Migration exclusions bootstrap.

    Installs the persistent exclusion registry used by the Schema Migration workbench.
    The registry is operational configuration only; it does not alter application schema.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
    THROW 51400, 'Schema exclusions bootstrap requires schema [SMigration]. Run the Schema Migration workbench bootstrap first.', 1;

IF OBJECT_ID(N'[SMigration].[SchemaDataObject_Ensure]', N'P') IS NULL
    THROW 51401, 'Schema exclusions bootstrap requires [SMigration].[SchemaDataObject_Ensure].', 1;

IF OBJECT_ID(N'[SCore].[DataObjects]', N'U') IS NULL
    THROW 51402, 'Schema exclusions bootstrap requires [SCore].[DataObjects].', 1;
GO


IF OBJECT_ID(N'[SMigration].[Schema_ExcludedObjects]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_ExcludedObjects]
    (
        [ID] BIGINT IDENTITY(1,1) NOT NULL,
        [Guid] UNIQUEIDENTIFIER NOT NULL,
        [RowStatus] TINYINT NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_RowStatus] DEFAULT (1),
        [StableObjectKey] NVARCHAR(1300) NOT NULL,
        [StableObjectKeyHash] BINARY(32) NOT NULL,
        [ObjectType] NVARCHAR(50) NOT NULL,
        [SchemaName] NVARCHAR(128) NOT NULL,
        [ObjectName] NVARCHAR(512) NOT NULL,
        [ParentObjectName] NVARCHAR(512) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_ParentObjectName] DEFAULT (N''),
        [ExclusionScope] NVARCHAR(30) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_ExclusionScope] DEFAULT (N'AllDatabases'),
        [Reason] NVARCHAR(2000) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_Reason] DEFAULT (N''),
        [OriginServerName] NVARCHAR(255) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_OriginServerName] DEFAULT (N''),
        [OriginDatabaseName] NVARCHAR(255) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_OriginDatabaseName] DEFAULT (N''),
        [ExcludedByUserId] INT NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_ExcludedByUserId] DEFAULT (-1),
        [ExcludedOnUtc] DATETIME2(7) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_ExcludedOnUtc] DEFAULT (SYSUTCDATETIME()),
        [UnexcludedByUserId] INT NULL,
        [UnexcludedOnUtc] DATETIME2(7) NULL,
        [LastSeenRunGuid] UNIQUEIDENTIFIER NULL,
        [LastSeenOnUtc] DATETIME2(7) NULL,
        CONSTRAINT [PK_Schema_ExcludedObjects] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_ExcludedObjects_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY];
END;
GO

DECLARE @ExpectedColumns TABLE
(
    [ColumnName] SYSNAME NOT NULL PRIMARY KEY,
    [TypeName] SYSNAME NOT NULL,
    [MaxLength] SMALLINT NOT NULL,
    [IsNullable] BIT NOT NULL,
    [IsIdentity] BIT NOT NULL
);

INSERT INTO @ExpectedColumns
(
    [ColumnName],
    [TypeName],
    [MaxLength],
    [IsNullable],
    [IsIdentity]
)
VALUES
    (N'ID', N'bigint', 8, 0, 1),
    (N'Guid', N'uniqueidentifier', 16, 0, 0),
    (N'RowStatus', N'tinyint', 1, 0, 0),
    (N'StableObjectKey', N'nvarchar', 2600, 0, 0),
    (N'StableObjectKeyHash', N'binary', 32, 0, 0),
    (N'ObjectType', N'nvarchar', 100, 0, 0),
    (N'SchemaName', N'nvarchar', 256, 0, 0),
    (N'ObjectName', N'nvarchar', 1024, 0, 0),
    (N'ParentObjectName', N'nvarchar', 1024, 0, 0),
    (N'ExclusionScope', N'nvarchar', 60, 0, 0),
    (N'Reason', N'nvarchar', 4000, 0, 0),
    (N'OriginServerName', N'nvarchar', 510, 0, 0),
    (N'OriginDatabaseName', N'nvarchar', 510, 0, 0),
    (N'ExcludedByUserId', N'int', 4, 0, 0),
    (N'ExcludedOnUtc', N'datetime2', 8, 0, 0),
    (N'UnexcludedByUserId', N'int', 4, 1, 0),
    (N'UnexcludedOnUtc', N'datetime2', 8, 1, 0),
    (N'LastSeenRunGuid', N'uniqueidentifier', 16, 1, 0),
    (N'LastSeenOnUtc', N'datetime2', 8, 1, 0);

DECLARE @IncompatibleColumns NVARCHAR(MAX);
SELECT
    @IncompatibleColumns = STRING_AGG(QUOTENAME(expected.[ColumnName]), N', ')
FROM @ExpectedColumns AS expected
LEFT JOIN sys.columns AS columnDefinition
    ON columnDefinition.[object_id] = OBJECT_ID(N'[SMigration].[Schema_ExcludedObjects]', N'U')
   AND columnDefinition.[name] = expected.[ColumnName]
LEFT JOIN sys.types AS typeDefinition
    ON typeDefinition.[user_type_id] = columnDefinition.[user_type_id]
WHERE columnDefinition.[column_id] IS NULL
   OR typeDefinition.[name] <> expected.[TypeName]
   OR columnDefinition.[max_length] <> expected.[MaxLength]
   OR columnDefinition.[is_nullable] <> expected.[IsNullable]
   OR columnDefinition.[is_identity] <> expected.[IsIdentity];

IF @IncompatibleColumns IS NOT NULL
BEGIN
    DECLARE @ShapeError NVARCHAR(2048) =
        N'Schema exclusions bootstrap found missing or incompatible columns: ' + @IncompatibleColumns +
        N'. Use a reviewed source-controlled schema migration; the bootstrap will not alter an existing table shape.';
    THROW 51403, @ShapeError, 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS indexDefinition
    WHERE indexDefinition.[name] = N'UX_Schema_ExcludedObjects_StableObjectKeyHash'
      AND indexDefinition.[object_id] = OBJECT_ID(N'[SMigration].[Schema_ExcludedObjects]', N'U')
)
BEGIN
    CREATE UNIQUE INDEX [UX_Schema_ExcludedObjects_StableObjectKeyHash]
        ON [SMigration].[Schema_ExcludedObjects] ([StableObjectKeyHash])
        WITH (FILLFACTOR = 80);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS indexDefinition
    WHERE indexDefinition.[name] = N'IX_Schema_ExcludedObjects_Active'
      AND indexDefinition.[object_id] = OBJECT_ID(N'[SMigration].[Schema_ExcludedObjects]', N'U')
)
BEGIN
    CREATE INDEX [IX_Schema_ExcludedObjects_Active]
        ON [SMigration].[Schema_ExcludedObjects]
        (
            [ObjectType],
            [SchemaName]
        )
        INCLUDE
        (
            [ObjectName],
            [ParentObjectName],
            [StableObjectKey],
            [Reason],
            [ExclusionScope]
        )
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[SchemaExcludedObject_Apply]
(
    @Guid UNIQUEIDENTIFIER OUTPUT,
    @ObjectType NVARCHAR(50),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(512),
    @ParentObjectName NVARCHAR(512) = N'',
    @Reason NVARCHAR(2000) = N'',
    @IsExcluded BIT,
    @OriginServerName NVARCHAR(255) = N'',
    @OriginDatabaseName NVARCHAR(255) = N'',
    @ActorUserId INT = -1,
    @LastSeenRunGuid UNIQUEIDENTIFIER = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ObjectType = LTRIM(RTRIM(ISNULL(@ObjectType, N'')));
    SET @SchemaName = LTRIM(RTRIM(ISNULL(@SchemaName, N'')));
    SET @ObjectName = LTRIM(RTRIM(ISNULL(@ObjectName, N'')));
    SET @ParentObjectName = LTRIM(RTRIM(ISNULL(@ParentObjectName, N'')));
    SET @Reason = LTRIM(RTRIM(ISNULL(@Reason, N'')));

    IF @ObjectType = N'' OR @SchemaName = N'' OR @ObjectName = N''
        THROW 51410, 'Schema exclusion requires object type, schema name and object name.', 1;

    IF ISNULL(@IsExcluded, 0) = 1 AND @Reason = N''
        THROW 51411, 'Schema exclusion requires an audit reason.', 1;

    DECLARE @StableObjectKey NVARCHAR(1300) = CONCAT
    (
        UPPER(@ObjectType COLLATE Latin1_General_100_CI_AS), N'|',
        UPPER(@SchemaName COLLATE Latin1_General_100_CI_AS), N'|',
        UPPER(@ObjectName COLLATE Latin1_General_100_CI_AS), N'|',
        UPPER(@ParentObjectName COLLATE Latin1_General_100_CI_AS)
    );
    DECLARE @StableObjectKeyHash BINARY(32) = HASHBYTES(N'SHA2_256', CONVERT(VARBINARY(MAX), @StableObjectKey));
    DECLARE @ExistingGuid UNIQUEIDENTIFIER;
    DECLARE @ExistingStableObjectKey NVARCHAR(1300);
    DECLARE @StartedTransaction BIT = 0;

    IF @@TRANCOUNT = 0
    BEGIN
        BEGIN TRANSACTION;
        SET @StartedTransaction = 1;
    END;

    BEGIN TRY
        SELECT TOP (1)
            @ExistingGuid = excluded.[Guid],
            @ExistingStableObjectKey = excluded.[StableObjectKey]
        FROM [SMigration].[Schema_ExcludedObjects] AS excluded WITH (UPDLOCK, HOLDLOCK)
        WHERE excluded.[StableObjectKeyHash] = @StableObjectKeyHash
        ORDER BY excluded.[ID];

        IF @ExistingGuid IS NOT NULL
           AND @ExistingStableObjectKey <> @StableObjectKey
            THROW 51412, 'Schema exclusion stable-key hash collision detected. No exclusion was changed.', 1;

        SET @Guid = COALESCE(@ExistingGuid, NULLIF(@Guid, '00000000-0000-0000-0000-000000000000'), NEWID());

        IF ISNULL(@IsExcluded, 0) = 1
        BEGIN
            EXEC [SMigration].[SchemaDataObject_Ensure]
                @Guid = @Guid,
                @SchemeName = N'SMigration',
                @ObjectName = N'Schema_ExcludedObjects';

            IF EXISTS
            (
                SELECT 1
                FROM [SMigration].[Schema_ExcludedObjects] AS excluded
                WHERE excluded.[Guid] = @Guid
            )
            BEGIN
                UPDATE [SMigration].[Schema_ExcludedObjects]
                SET
                    [RowStatus] = 1,
                    [StableObjectKey] = @StableObjectKey,
                    [StableObjectKeyHash] = @StableObjectKeyHash,
                    [ObjectType] = @ObjectType,
                    [SchemaName] = @SchemaName,
                    [ObjectName] = @ObjectName,
                    [ParentObjectName] = @ParentObjectName,
                    [ExclusionScope] = N'AllDatabases',
                    [Reason] = @Reason,
                    [OriginServerName] = ISNULL(@OriginServerName, N''),
                    [OriginDatabaseName] = ISNULL(@OriginDatabaseName, N''),
                    [ExcludedByUserId] = ISNULL(@ActorUserId, -1),
                    [ExcludedOnUtc] = SYSUTCDATETIME(),
                    [UnexcludedByUserId] = NULL,
                    [UnexcludedOnUtc] = NULL,
                    [LastSeenRunGuid] = @LastSeenRunGuid,
                    [LastSeenOnUtc] = SYSUTCDATETIME()
                WHERE [Guid] = @Guid;
            END
            ELSE
            BEGIN
                INSERT INTO [SMigration].[Schema_ExcludedObjects]
                (
                    [Guid],
                    [RowStatus],
                    [StableObjectKey],
                    [StableObjectKeyHash],
                    [ObjectType],
                    [SchemaName],
                    [ObjectName],
                    [ParentObjectName],
                    [ExclusionScope],
                    [Reason],
                    [OriginServerName],
                    [OriginDatabaseName],
                    [ExcludedByUserId],
                    [ExcludedOnUtc],
                    [UnexcludedByUserId],
                    [UnexcludedOnUtc],
                    [LastSeenRunGuid],
                    [LastSeenOnUtc]
                )
                VALUES
                (
                    @Guid,
                    1,
                    @StableObjectKey,
                    @StableObjectKeyHash,
                    @ObjectType,
                    @SchemaName,
                    @ObjectName,
                    @ParentObjectName,
                    N'AllDatabases',
                    @Reason,
                    ISNULL(@OriginServerName, N''),
                    ISNULL(@OriginDatabaseName, N''),
                    ISNULL(@ActorUserId, -1),
                    SYSUTCDATETIME(),
                    NULL,
                    NULL,
                    @LastSeenRunGuid,
                    SYSUTCDATETIME()
                );
            END;
        END
        ELSE IF @ExistingGuid IS NOT NULL
        BEGIN
            EXEC [SCore].[DeleteDataObject]
                @Guid = @ExistingGuid;

            UPDATE [SMigration].[Schema_ExcludedObjects]
            SET
                [RowStatus] = 254,
                [UnexcludedByUserId] = ISNULL(@ActorUserId, -1),
                [UnexcludedOnUtc] = SYSUTCDATETIME(),
                [LastSeenRunGuid] = @LastSeenRunGuid,
                [LastSeenOnUtc] = SYSUTCDATETIME()
            WHERE [Guid] = @ExistingGuid
              AND [RowStatus] <> 0
              AND [RowStatus] <> 254;

            SET @Guid = @ExistingGuid;
        END;

        IF @StartedTransaction = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @StartedTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[SchemaExcludedObjects_List]
(
    @IncludeInactive BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        excluded.[Guid],
        excluded.[ObjectType],
        excluded.[SchemaName],
        excluded.[ObjectName],
        excluded.[ParentObjectName],
        excluded.[StableObjectKey],
        excluded.[Reason],
        excluded.[ExclusionScope],
        excluded.[OriginServerName],
        excluded.[OriginDatabaseName],
        excluded.[ExcludedByUserId],
        CONVERT(NVARCHAR(30), excluded.[ExcludedOnUtc], 126) AS [ExcludedOnUtc],
        CONVERT(NVARCHAR(30), excluded.[UnexcludedOnUtc], 126) AS [UnexcludedOnUtc],
        excluded.[LastSeenRunGuid],
        CONVERT(NVARCHAR(30), excluded.[LastSeenOnUtc], 126) AS [LastSeenOnUtc],
        excluded.[RowStatus]
    FROM [SMigration].[Schema_ExcludedObjects] AS excluded
    WHERE ISNULL(@IncludeInactive, 0) = 1
       OR
       (
           excluded.[RowStatus] <> 0
           AND excluded.[RowStatus] <> 254
       )
    ORDER BY
        excluded.[ObjectType],
        excluded.[SchemaName],
        excluded.[ObjectName],
        excluded.[ParentObjectName];
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[SchemaDeploymentPlan_Get]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HasExplicitSelection BIT =
    (
        SELECT
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM [SMigration].[Schema_RunSelections] AS selection
                    WHERE selection.[RunGuid] = @RunGuid
                      AND selection.[RowStatus] <> 0
                      AND selection.[RowStatus] <> 254
                ) THEN CONVERT(BIT, 1)
                ELSE CONVERT(BIT, 0)
            END
    );

    SELECT
        comparison.[Guid] AS [ComparisonGuid],
        comparison.[ObjectType],
        comparison.[SchemaName],
        comparison.[ObjectName],
        comparison.[ParentObjectName],
        comparison.[DifferenceType],
        comparison.[SourceHash],
        comparison.[TargetHash],
        comparison.[SourceDefinition],
        comparison.[TargetDefinition],
        comparison.[IsDeployable],
        comparison.[IsDestructiveRisk],
        CASE
            WHEN @HasExplicitSelection = 0 THEN CONVERT(BIT, CASE WHEN comparison.[IsDestructiveRisk] = 1 THEN 0 ELSE 1 END)
            ELSE ISNULL(selectionState.[IsSelected], CONVERT(BIT, 0))
        END AS [IsSelected],
        @HasExplicitSelection AS [HasExplicitSelection]
    FROM [SMigration].[Schema_ObjectComparisons] AS comparison
    OUTER APPLY
    (
        SELECT TOP (1)
            selection.[IsSelected]
        FROM [SMigration].[Schema_RunSelections] AS selection
        WHERE selection.[RunGuid] = comparison.[RunGuid]
          AND selection.[ObjectType] = comparison.[ObjectType]
          AND selection.[SchemaName] = comparison.[SchemaName]
          AND selection.[ObjectName] = comparison.[ObjectName]
          AND selection.[ParentObjectName] = comparison.[ParentObjectName]
          AND selection.[RowStatus] <> 0
          AND selection.[RowStatus] <> 254
        ORDER BY selection.[ID] DESC
    ) AS selectionState
    WHERE comparison.[RunGuid] = @RunGuid
      AND comparison.[RowStatus] <> 0
      AND comparison.[RowStatus] <> 254
      AND comparison.[IsDeployable] = 1
      AND comparison.[DifferenceType] <> N'Equal'
      AND
      (
          @HasExplicitSelection = 1
          OR comparison.[IsDestructiveRisk] = 0
      )
      AND
      (
          @HasExplicitSelection = 0
          OR ISNULL(selectionState.[IsSelected], CONVERT(BIT, 0)) = 1
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM [SMigration].[Schema_ExcludedObjects] AS excluded
          WHERE excluded.[ObjectType] = comparison.[ObjectType]
            AND excluded.[SchemaName] = comparison.[SchemaName]
            AND excluded.[ObjectName] = comparison.[ObjectName]
            AND excluded.[ParentObjectName] = comparison.[ParentObjectName]
            AND excluded.[RowStatus] <> 0
            AND excluded.[RowStatus] <> 254
      )
    ORDER BY
        CASE comparison.[ObjectType]
            WHEN N'Schema' THEN 10
            WHEN N'TableType' THEN 20
            WHEN N'Table' THEN 30
            WHEN N'Sequence' THEN 40
            WHEN N'Constraint' THEN 50
            WHEN N'Index' THEN 60
            WHEN N'View' THEN 70
            WHEN N'Function' THEN 80
            WHEN N'StoredProcedure' THEN 90
            WHEN N'Trigger' THEN 100
            ELSE 900
        END,
        comparison.[SchemaName],
        comparison.[ObjectName];
END;
GO


IF OBJECT_ID(N'[SMigration].[Schema_ExcludedObjects]', N'U') IS NULL
    THROW 51420, 'Schema exclusions table bootstrap verification failed.', 1;

IF OBJECT_ID(N'[SMigration].[SchemaExcludedObject_Apply]', N'P') IS NULL
    THROW 51421, 'Schema exclusions apply procedure bootstrap verification failed.', 1;

IF OBJECT_ID(N'[SMigration].[SchemaExcludedObjects_List]', N'P') IS NULL
    THROW 51422, 'Schema exclusions list procedure bootstrap verification failed.', 1;
GO
