/*
    CYB-361 R7D per-object deployment checkpoints and verification evidence.

    A checkpoint is unique per attempt, comparison and phase. The runner creates the
    DataObjects row before inserting the checkpoint and updates the operational result
    in place while retaining every prior attempt.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF SCHEMA_ID(N'SMigration') IS NULL
    THROW 51441, 'Table [SMigration].[Schema_DeploymentObjectCheckpoints] requires schema [SMigration].', 1;
GO

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
GO

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
GO

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
GO
