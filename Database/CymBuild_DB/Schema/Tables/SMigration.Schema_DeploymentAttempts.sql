/*
    CYB-361 R7D Schema deployment attempt audit.

    One active row is created for every controlled -Apply invocation after the target
    application lock is acquired. Operational attempt state is kept separately from
    Schema_Run so retries retain their complete history.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF SCHEMA_ID(N'SMigration') IS NULL
    THROW 51440, 'Table [SMigration].[Schema_DeploymentAttempts] requires schema [SMigration].', 1;
GO

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
GO

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
GO

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
GO
