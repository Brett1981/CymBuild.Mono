SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas AS s
    WHERE s.name = N'SMigration'
)
BEGIN
    EXEC sys.sp_executesql N'CREATE SCHEMA [SMigration]';
END;
GO

IF OBJECT_ID(N'SMigration.SchemaDataObject_Ensure', N'P') IS NULL
BEGIN
    EXEC sys.sp_executesql N'
CREATE PROCEDURE [SMigration].[SchemaDataObject_Ensure]
(
    @Guid       UNIQUEIDENTIFIER,
    @SchemeName NVARCHAR(255),
    @ObjectName NVARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EntityTypeId INT = NULL;

    SELECT TOP (1)
        @EntityTypeId = et.ID
    FROM SCore.EntityHobts AS eh
    INNER JOIN SCore.EntityTypes AS et
        ON et.ID = eh.EntityTypeID
    WHERE eh.SchemaName = @SchemeName
      AND eh.ObjectName = @ObjectName
      AND eh.RowStatus NOT IN (0,254)
      AND et.RowStatus NOT IN (0,254)
    ORDER BY et.ID;

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = et.ID
        FROM SCore.EntityTypes AS et
        WHERE et.Name = N''EntityTypes''
          AND et.RowStatus NOT IN (0,254)
        ORDER BY et.ID;
    END;

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = et.ID
        FROM SCore.EntityTypes AS et
        WHERE et.RowStatus NOT IN (0,254)
        ORDER BY et.ID;
    END;

    IF @EntityTypeId IS NULL
    BEGIN
        ;THROW 51260, ''No active SCore.EntityTypes row exists to support Schema migration DataObjects creation.'', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.DataObjects AS d
        WHERE d.Guid = @Guid
    )
    BEGIN
        INSERT INTO SCore.DataObjects
        (
            Guid,
            RowStatus,
            EntityTypeId
        )
        VALUES
        (
            @Guid,
            1,
            @EntityTypeId
        );
    END
    ELSE
    BEGIN
        UPDATE SCore.DataObjects
        SET
            RowStatus = CASE WHEN RowStatus IN (0,254) THEN 1 ELSE RowStatus END,
            EntityTypeId = ISNULL(EntityTypeId, @EntityTypeId)
        WHERE Guid = @Guid;
    END;
END;';
END;
GO

IF OBJECT_ID(N'SMigration.Schema_Run', N'U') IS NULL
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
        CONSTRAINT [PK_Schema_Run] PRIMARY KEY CLUSTERED ([ID]),
        CONSTRAINT [UQ_Schema_Run_Guid] UNIQUE ([Guid])
    );
END;
GO

IF OBJECT_ID(N'SMigration.Schema_ObjectComparisons', N'U') IS NULL
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
        CONSTRAINT [PK_Schema_ObjectComparisons] PRIMARY KEY CLUSTERED ([ID]),
        CONSTRAINT [UQ_Schema_ObjectComparisons_Guid] UNIQUE ([Guid])
    );
END;
GO

IF OBJECT_ID(N'SMigration.Schema_ValidationIssues', N'U') IS NULL
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
        CONSTRAINT [PK_Schema_ValidationIssues] PRIMARY KEY CLUSTERED ([ID]),
        CONSTRAINT [UQ_Schema_ValidationIssues_Guid] UNIQUE ([Guid])
    );
END;
GO

IF OBJECT_ID(N'SMigration.Schema_ExecutionLog', N'U') IS NULL
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
        CONSTRAINT [PK_Schema_ExecutionLog] PRIMARY KEY CLUSTERED ([ID]),
        CONSTRAINT [UQ_Schema_ExecutionLog_Guid] UNIQUE ([Guid])
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.name = N'IX_Schema_ObjectComparisons_Run_Active'
      AND i.object_id = OBJECT_ID(N'SMigration.Schema_ObjectComparisons')
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
    WHERE [RowStatus] <> 0 AND [RowStatus] <> 254;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.name = N'UX_Schema_ObjectComparisons_Run_Key_Active'
      AND i.object_id = OBJECT_ID(N'SMigration.Schema_ObjectComparisons')
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
    WHERE [RowStatus] <> 0 AND [RowStatus] <> 254;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.name = N'IX_Schema_ValidationIssues_Run_Active'
      AND i.object_id = OBJECT_ID(N'SMigration.Schema_ValidationIssues')
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
    WHERE [RowStatus] <> 0 AND [RowStatus] <> 254;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.name = N'IX_Schema_ExecutionLog_Run_Active'
      AND i.object_id = OBJECT_ID(N'SMigration.Schema_ExecutionLog')
)
BEGIN
    CREATE INDEX [IX_Schema_ExecutionLog_Run_Active]
    ON [SMigration].[Schema_ExecutionLog]
    (
        [RunGuid],
        [ID]
    )
    WHERE [RowStatus] <> 0 AND [RowStatus] <> 254;
END;
GO
