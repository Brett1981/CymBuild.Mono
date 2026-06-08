PRINT (N'Create table [SMigration].[Metadata_StagedRows]')
GO
CREATE TABLE [SMigration].[Metadata_StagedRows] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_StagedRows_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [RegistryGuid] [uniqueidentifier] NOT NULL,
  [SourceRowGuid] [uniqueidentifier] NOT NULL,
  [SourceRowId] [bigint] NULL,
  [SourceRowStatus] [tinyint] NULL,
  [SourcePayloadJson] [nvarchar](max) NOT NULL,
  [SourcePayloadHash] [varbinary](32) NOT NULL,
  [TargetPayloadJson] [nvarchar](max) NULL,
  [TargetPayloadHash] [varbinary](32) NULL,
  [DifferenceType] [nvarchar](30) NOT NULL,
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_StagedRows_CreatedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_StagedRows] on table [SMigration].[Metadata_StagedRows]')
GO
ALTER TABLE [SMigration].[Metadata_StagedRows] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_StagedRows] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_StagedRows_Guid] on table [SMigration].[Metadata_StagedRows]')
GO
ALTER TABLE [SMigration].[Metadata_StagedRows] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_StagedRows_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_StagedRows_Run_Table_Row] on table [SMigration].[Metadata_StagedRows]')
GO
ALTER TABLE [SMigration].[Metadata_StagedRows] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_StagedRows_Run_Table_Row] UNIQUE ([RunGuid], [RegistryGuid], [SourceRowGuid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Metadata_StagedRows_RunGuid] on table [SMigration].[Metadata_StagedRows]')
GO
CREATE INDEX [IX_Metadata_StagedRows_RunGuid]
  ON [SMigration].[Metadata_StagedRows] ([RunGuid], [RegistryGuid], [DifferenceType])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO