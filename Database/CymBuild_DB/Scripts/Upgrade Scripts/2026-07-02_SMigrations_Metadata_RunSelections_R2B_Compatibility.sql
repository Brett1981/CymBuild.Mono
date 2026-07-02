/*
    CI/CD-safe idempotent compatibility repair for Metadata Migration Workbench R2.

    Purpose:
    - Ensures SMigration.Metadata_RunSelections exists before R2 dashboard / staged-row reads.
    - Safe to run repeatedly in DEV/QA/UAT deployment pipelines.
    - Does not change metadata apply behaviour.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [SMigration] AUTHORIZATION [dbo];');
END;
GO

IF OBJECT_ID(N'SMigration.Metadata_RunSelections', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Metadata_RunSelections]
    (
        [ID] [bigint] IDENTITY(1,1) NOT NULL,
        [Guid] [uniqueidentifier] NOT NULL,
        [RowStatus] [tinyint] NOT NULL,
        [RunGuid] [uniqueidentifier] NOT NULL,
        [RegistryGuid] [uniqueidentifier] NOT NULL,
        [SourceRowGuid] [uniqueidentifier] NOT NULL,
        [DifferenceType] [nvarchar](30) NOT NULL,
        [SelectionSource] [nvarchar](30) NOT NULL,
        [SelectedByUserId] [int] NOT NULL,
        [SelectedOnUtc] [datetime2](7) NOT NULL,
        CONSTRAINT [PK_Metadata_RunSelections] PRIMARY KEY CLUSTERED ([ID] ASC) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Metadata_RunSelections_Guid] UNIQUE NONCLUSTERED ([Guid] ASC) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Metadata_RunSelections_Run_Table_Row] UNIQUE NONCLUSTERED ([RunGuid] ASC, [RegistryGuid] ASC, [SourceRowGuid] ASC) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY];
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints AS dc
    WHERE dc.name = N'DF_Metadata_RunSelections_RowStatus'
      AND dc.parent_object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections')
)
BEGIN
    ALTER TABLE [SMigration].[Metadata_RunSelections]
    ADD CONSTRAINT [DF_Metadata_RunSelections_RowStatus] DEFAULT (1) FOR [RowStatus];
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints AS dc
    WHERE dc.name = N'DF_Metadata_RunSelections_SelectionSource'
      AND dc.parent_object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections')
)
BEGIN
    ALTER TABLE [SMigration].[Metadata_RunSelections]
    ADD CONSTRAINT [DF_Metadata_RunSelections_SelectionSource] DEFAULT (N'Manual') FOR [SelectionSource];
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints AS dc
    WHERE dc.name = N'DF_Metadata_RunSelections_SelectedByUserId'
      AND dc.parent_object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections')
)
BEGIN
    ALTER TABLE [SMigration].[Metadata_RunSelections]
    ADD CONSTRAINT [DF_Metadata_RunSelections_SelectedByUserId] DEFAULT (-1) FOR [SelectedByUserId];
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints AS dc
    WHERE dc.name = N'DF_Metadata_RunSelections_SelectedOnUtc'
      AND dc.parent_object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections')
)
BEGIN
    ALTER TABLE [SMigration].[Metadata_RunSelections]
    ADD CONSTRAINT [DF_Metadata_RunSelections_SelectedOnUtc] DEFAULT (SYSUTCDATETIME()) FOR [SelectedOnUtc];
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.name = N'IX_Metadata_RunSelections_RunGuid'
      AND i.object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections')
)
BEGIN
    CREATE INDEX [IX_Metadata_RunSelections_RunGuid]
    ON [SMigration].[Metadata_RunSelections]
    (
        [RunGuid],
        [RegistryGuid],
        [DifferenceType]
    )
    WHERE ([RowStatus] <> 0 AND [RowStatus] <> 254)
    WITH (FILLFACTOR = 80)
    ON [PRIMARY];
END;
GO
