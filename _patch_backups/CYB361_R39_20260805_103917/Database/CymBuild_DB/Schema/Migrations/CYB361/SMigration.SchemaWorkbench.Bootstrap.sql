/*
    CYB-361 R35 - Schema Migration Workbench bootstrap

    Purpose:
      Idempotently install the minimum SMigration objects required by the
      Schema Migration workbench and controlled deployment runner.

    Governance:
      - Run only through tools/SchemaDeployment/Initialize-CymBuildSchemaMigration.ps1
        or the future controlled deployment worker.
      - Do not execute from the Blazor browser session.
      - Existing incompatible objects are rejected rather than altered or replaced.
      - No business data or workflow status is changed.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'[SCore].[DataObjects]', N'U') IS NULL
    THROW 51350, 'Schema Migration bootstrap requires [SCore].[DataObjects].', 1;

IF OBJECT_ID(N'[SCore].[EntityTypes]', N'U') IS NULL
    THROW 51351, 'Schema Migration bootstrap requires [SCore].[EntityTypes].', 1;

IF OBJECT_ID(N'[SCore].[EntityHobts]', N'U') IS NULL
    THROW 51352, 'Schema Migration bootstrap requires [SCore].[EntityHobts].', 1;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
BEGIN
    EXEC sys.sp_executesql N'CREATE SCHEMA [SMigration];';
END;
GO

IF OBJECT_ID(N'[SMigration].[Schema_Run]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_Run]
    (
        [ID] BIGINT IDENTITY(1,1) NOT NULL,
        [Guid] UNIQUEIDENTIFIER NOT NULL,
        [RowStatus] TINYINT NOT NULL CONSTRAINT [DF_Schema_Run_RowStatus] DEFAULT (1),
        [SourceEnvironment] NVARCHAR(20) NOT NULL,
        [TargetEnvironment] NVARCHAR(20) NOT NULL,
        [SourceServerName] NVARCHAR(255) NOT NULL,
        [SourceDatabaseName] NVARCHAR(255) NOT NULL,
        [TargetServerName] NVARCHAR(255) NOT NULL,
        [TargetDatabaseName] NVARCHAR(255) NOT NULL,
        [JiraReference] NVARCHAR(50) NOT NULL CONSTRAINT [DF_Schema_Run_JiraReference] DEFAULT (N''),
        [ReleaseReference] NVARCHAR(100) NOT NULL CONSTRAINT [DF_Schema_Run_ReleaseReference] DEFAULT (N''),
        [RunStatus] NVARCHAR(30) NOT NULL,
        [IsReviewed] BIT NOT NULL CONSTRAINT [DF_Schema_Run_IsReviewed] DEFAULT (0),
        [CreatedOnUtc] DATETIME2(7) NOT NULL CONSTRAINT [DF_Schema_Run_CreatedOnUtc] DEFAULT (SYSUTCDATETIME()),
        [ComparedOnUtc] DATETIME2(7) NULL,
        [ValidatedOnUtc] DATETIME2(7) NULL,
        [ReviewedOnUtc] DATETIME2(7) NULL,
        [AppliedOnUtc] DATETIME2(7) NULL,
        [CreatedByUserId] INT NOT NULL CONSTRAINT [DF_Schema_Run_CreatedByUserId] DEFAULT (-1),
        [ReviewedByUserId] INT NOT NULL CONSTRAINT [DF_Schema_Run_ReviewedByUserId] DEFAULT (-1),
        [DeploymentReference] NVARCHAR(100) NOT NULL CONSTRAINT [DF_Schema_Run_DeploymentReference] DEFAULT (N''),
        [Notes] NVARCHAR(2000) NOT NULL CONSTRAINT [DF_Schema_Run_Notes] DEFAULT (N''),
        [SummaryJson] NVARCHAR(MAX) NOT NULL CONSTRAINT [DF_Schema_Run_SummaryJson] DEFAULT (N'{}'),
        CONSTRAINT [PK_Schema_Run] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_Run_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
END;
GO

IF OBJECT_ID(N'[SMigration].[Schema_ObjectComparisons]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_ObjectComparisons]
    (
        [ID] BIGINT IDENTITY(1,1) NOT NULL,
        [Guid] UNIQUEIDENTIFIER NOT NULL,
        [RowStatus] TINYINT NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_RowStatus] DEFAULT (1),
        [RunGuid] UNIQUEIDENTIFIER NOT NULL,
        [ObjectType] NVARCHAR(50) NOT NULL,
        [SchemaName] NVARCHAR(128) NOT NULL,
        [ObjectName] NVARCHAR(512) NOT NULL,
        [ParentObjectName] NVARCHAR(512) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_ParentObjectName] DEFAULT (N''),
        [DifferenceType] NVARCHAR(30) NOT NULL,
        [SourceHash] NVARCHAR(128) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_SourceHash] DEFAULT (N''),
        [TargetHash] NVARCHAR(128) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_TargetHash] DEFAULT (N''),
        [SourceDefinition] NVARCHAR(MAX) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_SourceDefinition] DEFAULT (N''),
        [TargetDefinition] NVARCHAR(MAX) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_TargetDefinition] DEFAULT (N''),
        [IsDeployable] BIT NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_IsDeployable] DEFAULT (0),
        [IsDestructiveRisk] BIT NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_IsDestructiveRisk] DEFAULT (0),
        [Notes] NVARCHAR(2000) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_Notes] DEFAULT (N''),
        [CreatedOnUtc] DATETIME2(7) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_CreatedOnUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Schema_ObjectComparisons] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_ObjectComparisons_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
END;
GO

IF OBJECT_ID(N'[SMigration].[Schema_ValidationIssues]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_ValidationIssues]
    (
        [ID] BIGINT IDENTITY(1,1) NOT NULL,
        [Guid] UNIQUEIDENTIFIER NOT NULL,
        [RowStatus] TINYINT NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_RowStatus] DEFAULT (1),
        [RunGuid] UNIQUEIDENTIFIER NOT NULL,
        [ComparisonGuid] UNIQUEIDENTIFIER NULL,
        [Severity] NVARCHAR(10) NOT NULL,
        [IssueCode] NVARCHAR(100) NOT NULL,
        [IssueMessage] NVARCHAR(2000) NOT NULL,
        [ObjectType] NVARCHAR(50) NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_ObjectType] DEFAULT (N''),
        [SchemaName] NVARCHAR(128) NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_SchemaName] DEFAULT (N''),
        [ObjectName] NVARCHAR(512) NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_ObjectName] DEFAULT (N''),
        [DetailsJson] NVARCHAR(MAX) NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_DetailsJson] DEFAULT (N'{}'),
        [CreatedOnUtc] DATETIME2(7) NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_CreatedOnUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Schema_ValidationIssues] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_ValidationIssues_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
END;
GO

IF OBJECT_ID(N'[SMigration].[Schema_ExecutionLog]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_ExecutionLog]
    (
        [ID] BIGINT IDENTITY(1,1) NOT NULL,
        [Guid] UNIQUEIDENTIFIER NOT NULL,
        [RowStatus] TINYINT NOT NULL CONSTRAINT [DF_Schema_ExecutionLog_RowStatus] DEFAULT (1),
        [RunGuid] UNIQUEIDENTIFIER NOT NULL,
        [StepName] NVARCHAR(100) NOT NULL,
        [StepStatus] NVARCHAR(30) NOT NULL,
        [Message] NVARCHAR(2000) NOT NULL CONSTRAINT [DF_Schema_ExecutionLog_Message] DEFAULT (N''),
        [DetailsJson] NVARCHAR(MAX) NOT NULL CONSTRAINT [DF_Schema_ExecutionLog_DetailsJson] DEFAULT (N'{}'),
        [CreatedOnUtc] DATETIME2(7) NOT NULL CONSTRAINT [DF_Schema_ExecutionLog_CreatedOnUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Schema_ExecutionLog] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_ExecutionLog_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
END;
GO

IF OBJECT_ID(N'[SMigration].[Schema_RunSelections]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_RunSelections]
    (
        [ID] BIGINT IDENTITY(1,1) NOT NULL,
        [Guid] UNIQUEIDENTIFIER NOT NULL,
        [RowStatus] TINYINT NOT NULL CONSTRAINT [DF_Schema_RunSelections_RowStatus] DEFAULT (1),
        [RunGuid] UNIQUEIDENTIFIER NOT NULL,
        [ComparisonGuid] UNIQUEIDENTIFIER NULL,
        [ObjectType] NVARCHAR(50) NOT NULL,
        [SchemaName] NVARCHAR(128) NOT NULL,
        [ObjectName] NVARCHAR(512) NOT NULL,
        [ParentObjectName] NVARCHAR(512) NOT NULL CONSTRAINT [DF_Schema_RunSelections_ParentObjectName] DEFAULT (N''),
        [IsSelected] BIT NOT NULL,
        [SelectionNote] NVARCHAR(2000) NOT NULL CONSTRAINT [DF_Schema_RunSelections_SelectionNote] DEFAULT (N''),
        [SelectedByUserId] INT NOT NULL CONSTRAINT [DF_Schema_RunSelections_SelectedByUserId] DEFAULT (-1),
        [SelectedOnUtc] DATETIME2(7) NOT NULL CONSTRAINT [DF_Schema_RunSelections_SelectedOnUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Schema_RunSelections] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_RunSelections_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY];
END;
GO

/* Reject partial or incompatible pre-existing table shapes. */
DECLARE @ExpectedColumns TABLE
(
    [TableName] SYSNAME NOT NULL,
    [ColumnName] SYSNAME NOT NULL,
    [TypeName] SYSNAME NOT NULL,
    [MaxLength] SMALLINT NULL,
    [IsNullable] BIT NOT NULL,
    [IsIdentity] BIT NOT NULL,
    PRIMARY KEY ([TableName], [ColumnName])
);

INSERT INTO @ExpectedColumns
(
    [TableName],
    [ColumnName],
    [TypeName],
    [MaxLength],
    [IsNullable],
    [IsIdentity]
)
VALUES
    (N'Schema_Run', N'ID', N'bigint', 8, 0, 1),
    (N'Schema_Run', N'Guid', N'uniqueidentifier', 16, 0, 0),
    (N'Schema_Run', N'RowStatus', N'tinyint', 1, 0, 0),
    (N'Schema_Run', N'SourceEnvironment', N'nvarchar', 40, 0, 0),
    (N'Schema_Run', N'TargetEnvironment', N'nvarchar', 40, 0, 0),
    (N'Schema_Run', N'SourceServerName', N'nvarchar', 510, 0, 0),
    (N'Schema_Run', N'SourceDatabaseName', N'nvarchar', 510, 0, 0),
    (N'Schema_Run', N'TargetServerName', N'nvarchar', 510, 0, 0),
    (N'Schema_Run', N'TargetDatabaseName', N'nvarchar', 510, 0, 0),
    (N'Schema_Run', N'JiraReference', N'nvarchar', 100, 0, 0),
    (N'Schema_Run', N'ReleaseReference', N'nvarchar', 200, 0, 0),
    (N'Schema_Run', N'RunStatus', N'nvarchar', 60, 0, 0),
    (N'Schema_Run', N'IsReviewed', N'bit', 1, 0, 0),
    (N'Schema_Run', N'CreatedOnUtc', N'datetime2', 8, 0, 0),
    (N'Schema_Run', N'ComparedOnUtc', N'datetime2', 8, 1, 0),
    (N'Schema_Run', N'ValidatedOnUtc', N'datetime2', 8, 1, 0),
    (N'Schema_Run', N'ReviewedOnUtc', N'datetime2', 8, 1, 0),
    (N'Schema_Run', N'AppliedOnUtc', N'datetime2', 8, 1, 0),
    (N'Schema_Run', N'CreatedByUserId', N'int', 4, 0, 0),
    (N'Schema_Run', N'ReviewedByUserId', N'int', 4, 0, 0),
    (N'Schema_Run', N'DeploymentReference', N'nvarchar', 200, 0, 0),
    (N'Schema_Run', N'Notes', N'nvarchar', 4000, 0, 0),
    (N'Schema_Run', N'SummaryJson', N'nvarchar', -1, 0, 0),

    (N'Schema_ObjectComparisons', N'ID', N'bigint', 8, 0, 1),
    (N'Schema_ObjectComparisons', N'Guid', N'uniqueidentifier', 16, 0, 0),
    (N'Schema_ObjectComparisons', N'RowStatus', N'tinyint', 1, 0, 0),
    (N'Schema_ObjectComparisons', N'RunGuid', N'uniqueidentifier', 16, 0, 0),
    (N'Schema_ObjectComparisons', N'ObjectType', N'nvarchar', 100, 0, 0),
    (N'Schema_ObjectComparisons', N'SchemaName', N'nvarchar', 256, 0, 0),
    (N'Schema_ObjectComparisons', N'ObjectName', N'nvarchar', 1024, 0, 0),
    (N'Schema_ObjectComparisons', N'ParentObjectName', N'nvarchar', 1024, 0, 0),
    (N'Schema_ObjectComparisons', N'DifferenceType', N'nvarchar', 60, 0, 0),
    (N'Schema_ObjectComparisons', N'SourceHash', N'nvarchar', 256, 0, 0),
    (N'Schema_ObjectComparisons', N'TargetHash', N'nvarchar', 256, 0, 0),
    (N'Schema_ObjectComparisons', N'SourceDefinition', N'nvarchar', -1, 0, 0),
    (N'Schema_ObjectComparisons', N'TargetDefinition', N'nvarchar', -1, 0, 0),
    (N'Schema_ObjectComparisons', N'IsDeployable', N'bit', 1, 0, 0),
    (N'Schema_ObjectComparisons', N'IsDestructiveRisk', N'bit', 1, 0, 0),
    (N'Schema_ObjectComparisons', N'Notes', N'nvarchar', 4000, 0, 0),
    (N'Schema_ObjectComparisons', N'CreatedOnUtc', N'datetime2', 8, 0, 0),

    (N'Schema_ValidationIssues', N'ID', N'bigint', 8, 0, 1),
    (N'Schema_ValidationIssues', N'Guid', N'uniqueidentifier', 16, 0, 0),
    (N'Schema_ValidationIssues', N'RowStatus', N'tinyint', 1, 0, 0),
    (N'Schema_ValidationIssues', N'RunGuid', N'uniqueidentifier', 16, 0, 0),
    (N'Schema_ValidationIssues', N'ComparisonGuid', N'uniqueidentifier', 16, 1, 0),
    (N'Schema_ValidationIssues', N'Severity', N'nvarchar', 20, 0, 0),
    (N'Schema_ValidationIssues', N'IssueCode', N'nvarchar', 200, 0, 0),
    (N'Schema_ValidationIssues', N'IssueMessage', N'nvarchar', 4000, 0, 0),
    (N'Schema_ValidationIssues', N'ObjectType', N'nvarchar', 100, 0, 0),
    (N'Schema_ValidationIssues', N'SchemaName', N'nvarchar', 256, 0, 0),
    (N'Schema_ValidationIssues', N'ObjectName', N'nvarchar', 1024, 0, 0),
    (N'Schema_ValidationIssues', N'DetailsJson', N'nvarchar', -1, 0, 0),
    (N'Schema_ValidationIssues', N'CreatedOnUtc', N'datetime2', 8, 0, 0),

    (N'Schema_ExecutionLog', N'ID', N'bigint', 8, 0, 1),
    (N'Schema_ExecutionLog', N'Guid', N'uniqueidentifier', 16, 0, 0),
    (N'Schema_ExecutionLog', N'RowStatus', N'tinyint', 1, 0, 0),
    (N'Schema_ExecutionLog', N'RunGuid', N'uniqueidentifier', 16, 0, 0),
    (N'Schema_ExecutionLog', N'StepName', N'nvarchar', 200, 0, 0),
    (N'Schema_ExecutionLog', N'StepStatus', N'nvarchar', 60, 0, 0),
    (N'Schema_ExecutionLog', N'Message', N'nvarchar', 4000, 0, 0),
    (N'Schema_ExecutionLog', N'DetailsJson', N'nvarchar', -1, 0, 0),
    (N'Schema_ExecutionLog', N'CreatedOnUtc', N'datetime2', 8, 0, 0),

    (N'Schema_RunSelections', N'ID', N'bigint', 8, 0, 1),
    (N'Schema_RunSelections', N'Guid', N'uniqueidentifier', 16, 0, 0),
    (N'Schema_RunSelections', N'RowStatus', N'tinyint', 1, 0, 0),
    (N'Schema_RunSelections', N'RunGuid', N'uniqueidentifier', 16, 0, 0),
    (N'Schema_RunSelections', N'ComparisonGuid', N'uniqueidentifier', 16, 1, 0),
    (N'Schema_RunSelections', N'ObjectType', N'nvarchar', 100, 0, 0),
    (N'Schema_RunSelections', N'SchemaName', N'nvarchar', 256, 0, 0),
    (N'Schema_RunSelections', N'ObjectName', N'nvarchar', 1024, 0, 0),
    (N'Schema_RunSelections', N'ParentObjectName', N'nvarchar', 1024, 0, 0),
    (N'Schema_RunSelections', N'IsSelected', N'bit', 1, 0, 0),
    (N'Schema_RunSelections', N'SelectionNote', N'nvarchar', 4000, 0, 0),
    (N'Schema_RunSelections', N'SelectedByUserId', N'int', 4, 0, 0),
    (N'Schema_RunSelections', N'SelectedOnUtc', N'datetime2', 8, 0, 0);

DECLARE @IncompatibleColumns NVARCHAR(MAX);

SELECT
    @IncompatibleColumns = STRING_AGG(
        CONVERT(NVARCHAR(MAX), QUOTENAME(N'SMigration') + N'.' + QUOTENAME(ec.[TableName]) + N'.' + QUOTENAME(ec.[ColumnName])),
        N', '
    ) WITHIN GROUP (ORDER BY ec.[TableName], ec.[ColumnName])
FROM @ExpectedColumns AS ec
LEFT JOIN sys.tables AS tb
    ON tb.[name] = ec.[TableName]
   AND tb.[schema_id] = SCHEMA_ID(N'SMigration')
LEFT JOIN sys.columns AS cl
    ON cl.[object_id] = tb.[object_id]
   AND cl.[name] = ec.[ColumnName]
LEFT JOIN sys.types AS ty
    ON ty.[user_type_id] = cl.[user_type_id]
WHERE cl.[column_id] IS NULL
   OR ty.[name] <> ec.[TypeName]
   OR cl.[max_length] <> ec.[MaxLength]
   OR cl.[is_nullable] <> ec.[IsNullable]
   OR cl.[is_identity] <> ec.[IsIdentity];

IF @IncompatibleColumns IS NOT NULL
BEGIN
    DECLARE @ShapeError NVARCHAR(2048) =
        N'Schema Migration bootstrap found missing or incompatible columns: ' + @IncompatibleColumns +
        N'. Use a reviewed source-controlled schema migration; the bootstrap will not alter existing table shapes.';
    THROW 51353, @ShapeError, 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.[name] = N'IX_Schema_ObjectComparisons_Run_Active'
      AND i.[object_id] = OBJECT_ID(N'[SMigration].[Schema_ObjectComparisons]', N'U')
)
BEGIN
    CREATE INDEX [IX_Schema_ObjectComparisons_Run_Active]
        ON [SMigration].[Schema_ObjectComparisons]
        (
            [RunGuid],
            [DifferenceType],
            [ObjectType],
            [SchemaName],
            [ObjectName]
        )
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.[name] = N'UX_Schema_ObjectComparisons_Run_Key_Active'
      AND i.[object_id] = OBJECT_ID(N'[SMigration].[Schema_ObjectComparisons]', N'U')
)
BEGIN
    CREATE UNIQUE INDEX [UX_Schema_ObjectComparisons_Run_Key_Active]
        ON [SMigration].[Schema_ObjectComparisons]
        (
            [RunGuid],
            [ObjectType],
            [SchemaName],
            [ObjectName],
            [ParentObjectName]
        )
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.[name] = N'IX_Schema_ValidationIssues_Run_Active'
      AND i.[object_id] = OBJECT_ID(N'[SMigration].[Schema_ValidationIssues]', N'U')
)
BEGIN
    CREATE INDEX [IX_Schema_ValidationIssues_Run_Active]
        ON [SMigration].[Schema_ValidationIssues]
        (
            [RunGuid],
            [Severity],
            [ObjectType],
            [SchemaName],
            [ObjectName]
        )
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.[name] = N'IX_Schema_ExecutionLog_Run_Active'
      AND i.[object_id] = OBJECT_ID(N'[SMigration].[Schema_ExecutionLog]', N'U')
)
BEGIN
    CREATE INDEX [IX_Schema_ExecutionLog_Run_Active]
        ON [SMigration].[Schema_ExecutionLog]
        (
            [RunGuid],
            [ID]
        )
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.[name] = N'IX_Schema_RunSelections_Run_Active'
      AND i.[object_id] = OBJECT_ID(N'[SMigration].[Schema_RunSelections]', N'U')
)
BEGIN
    CREATE INDEX [IX_Schema_RunSelections_Run_Active]
        ON [SMigration].[Schema_RunSelections]
        (
            [RunGuid],
            [ObjectType],
            [SchemaName],
            [ObjectName],
            [ParentObjectName]
        )
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[SchemaDataObject_Ensure]
(
    @Guid UNIQUEIDENTIFIER,
    @SchemeName NVARCHAR(255),
    @ObjectName NVARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EntityTypeId INT;

    SELECT TOP (1)
        @EntityTypeId = et.[ID]
    FROM [SCore].[EntityHobts] AS eh
    INNER JOIN [SCore].[EntityTypes] AS et
        ON et.[ID] = eh.[EntityTypeID]
    WHERE eh.[SchemaName] = @SchemeName
      AND eh.[ObjectName] = @ObjectName
      AND eh.[RowStatus] <> 0
      AND eh.[RowStatus] <> 254
      AND et.[RowStatus] <> 0
      AND et.[RowStatus] <> 254
    ORDER BY et.[ID];

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = et.[ID]
        FROM [SCore].[EntityTypes] AS et
        WHERE et.[Name] = N'EntityTypes'
          AND et.[RowStatus] <> 0
          AND et.[RowStatus] <> 254
        ORDER BY et.[ID];
    END;

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = et.[ID]
        FROM [SCore].[EntityTypes] AS et
        WHERE et.[RowStatus] <> 0
          AND et.[RowStatus] <> 254
        ORDER BY et.[ID];
    END;

    IF @EntityTypeId IS NULL
        THROW 51354, 'No active SCore.EntityTypes row exists to support Schema Migration DataObjects creation.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [SCore].[DataObjects] AS d
        WHERE d.[Guid] = @Guid
          AND d.[RowStatus] <> 0
          AND d.[RowStatus] <> 254
    )
    BEGIN
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM [SCore].[DataObjects] AS d
        WHERE d.[Guid] = @Guid
    )
    BEGIN
        THROW 51355, 'The requested Schema Migration DataObject Guid already exists but is inactive. It will not be reactivated by the bootstrap helper.', 1;
    END;

    INSERT INTO [SCore].[DataObjects]
    (
        [Guid],
        [RowStatus],
        [EntityTypeId]
    )
    VALUES
    (
        @Guid,
        1,
        @EntityTypeId
    );
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
                    FROM [SMigration].[Schema_RunSelections] AS rs
                    WHERE rs.[RunGuid] = @RunGuid
                      AND rs.[RowStatus] <> 0
                      AND rs.[RowStatus] <> 254
                ) THEN CONVERT(BIT, 1)
                ELSE CONVERT(BIT, 0)
            END
    );

    SELECT
        c.[Guid] AS [ComparisonGuid],
        c.[ObjectType],
        c.[SchemaName],
        c.[ObjectName],
        c.[ParentObjectName],
        c.[DifferenceType],
        c.[SourceHash],
        c.[TargetHash],
        c.[SourceDefinition],
        c.[TargetDefinition],
        c.[IsDeployable],
        c.[IsDestructiveRisk],
        CASE
            WHEN @HasExplicitSelection = 0 THEN CONVERT(BIT, 1)
            ELSE ISNULL(sel.[IsSelected], CONVERT(BIT, 0))
        END AS [IsSelected],
        @HasExplicitSelection AS [HasExplicitSelection]
    FROM [SMigration].[Schema_ObjectComparisons] AS c
    OUTER APPLY
    (
        SELECT TOP (1)
            rs.[IsSelected]
        FROM [SMigration].[Schema_RunSelections] AS rs
        WHERE rs.[RunGuid] = c.[RunGuid]
          AND rs.[ObjectType] = c.[ObjectType]
          AND rs.[SchemaName] = c.[SchemaName]
          AND rs.[ObjectName] = c.[ObjectName]
          AND rs.[ParentObjectName] = c.[ParentObjectName]
          AND rs.[RowStatus] <> 0
          AND rs.[RowStatus] <> 254
        ORDER BY rs.[ID] DESC
    ) AS sel
    WHERE c.[RunGuid] = @RunGuid
      AND c.[RowStatus] <> 0
      AND c.[RowStatus] <> 254
      AND c.[IsDeployable] = 1
      AND c.[DifferenceType] <> N'Equal'
      AND
      (
          @HasExplicitSelection = 0
          OR ISNULL(sel.[IsSelected], CONVERT(BIT, 0)) = 1
      )
    ORDER BY
        CASE c.[ObjectType]
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
        c.[SchemaName],
        c.[ObjectName];
END;
GO

/* Final object-level verification. */
IF SCHEMA_ID(N'SMigration') IS NULL
    THROW 51356, 'SMigration schema bootstrap verification failed.', 1;

IF OBJECT_ID(N'[SMigration].[Schema_Run]', N'U') IS NULL
    THROW 51357, 'SMigration.Schema_Run bootstrap verification failed.', 1;

IF OBJECT_ID(N'[SMigration].[Schema_ObjectComparisons]', N'U') IS NULL
    THROW 51358, 'SMigration.Schema_ObjectComparisons bootstrap verification failed.', 1;

IF OBJECT_ID(N'[SMigration].[Schema_ValidationIssues]', N'U') IS NULL
    THROW 51359, 'SMigration.Schema_ValidationIssues bootstrap verification failed.', 1;

IF OBJECT_ID(N'[SMigration].[Schema_ExecutionLog]', N'U') IS NULL
    THROW 51360, 'SMigration.Schema_ExecutionLog bootstrap verification failed.', 1;

IF OBJECT_ID(N'[SMigration].[Schema_RunSelections]', N'U') IS NULL
    THROW 51361, 'SMigration.Schema_RunSelections bootstrap verification failed.', 1;

IF OBJECT_ID(N'[SMigration].[SchemaDataObject_Ensure]', N'P') IS NULL
    THROW 51362, 'SMigration.SchemaDataObject_Ensure bootstrap verification failed.', 1;

IF OBJECT_ID(N'[SMigration].[SchemaDeploymentPlan_Get]', N'P') IS NULL
    THROW 51363, 'SMigration.SchemaDeploymentPlan_Get bootstrap verification failed.', 1;
GO
