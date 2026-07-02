PRINT (N'Create table [SMigration].[Metadata_IgnoredRecords]')
GO
CREATE TABLE [SMigration].[Metadata_IgnoredRecords] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_IgnoredRecords_RowStatus] DEFAULT (1),
  [DatabaseName] [sysname] NOT NULL,
  [ServerName] [nvarchar](255) NOT NULL CONSTRAINT [DF_Metadata_IgnoredRecords_ServerName] DEFAULT (N''),
  [EnvironmentName] [nvarchar](20) NOT NULL CONSTRAINT [DF_Metadata_IgnoredRecords_EnvironmentName] DEFAULT (N''),
  [RegistryGuid] [uniqueidentifier] NOT NULL,
  [SchemaName] [nvarchar](128) NOT NULL,
  [TableName] [nvarchar](128) NOT NULL,
  [SourceRowGuid] [uniqueidentifier] NOT NULL,
  [StableRecordKey] [nvarchar](600) NOT NULL,
  [DifferenceType] [nvarchar](30) NOT NULL CONSTRAINT [DF_Metadata_IgnoredRecords_DifferenceType] DEFAULT (N''),
  [IgnoreScope] [nvarchar](30) NOT NULL CONSTRAINT [DF_Metadata_IgnoredRecords_IgnoreScope] DEFAULT (N'TargetDatabase'),
  [Reason] [nvarchar](500) NOT NULL CONSTRAINT [DF_Metadata_IgnoredRecords_Reason] DEFAULT (N''),
  [IgnoredByUserId] [int] NOT NULL CONSTRAINT [DF_Metadata_IgnoredRecords_IgnoredByUserId] DEFAULT (-1),
  [IgnoredOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_IgnoredRecords_IgnoredOnUtc] DEFAULT (sysutcdatetime()),
  [UnignoredByUserId] [int] NULL,
  [UnignoredOnUtc] [datetime2] NULL,
  [LastSeenRunGuid] [uniqueidentifier] NULL,
  [LastSeenOnUtc] [datetime2] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_IgnoredRecords] on table [SMigration].[Metadata_IgnoredRecords]')
GO
ALTER TABLE [SMigration].[Metadata_IgnoredRecords] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_IgnoredRecords] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_IgnoredRecords_Guid] on table [SMigration].[Metadata_IgnoredRecords]')
GO
ALTER TABLE [SMigration].[Metadata_IgnoredRecords] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_IgnoredRecords_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create unique filtered index [UX_Metadata_IgnoredRecords_ActiveScope] on table [SMigration].[Metadata_IgnoredRecords]')
GO
CREATE UNIQUE INDEX [UX_Metadata_IgnoredRecords_ActiveScope]
  ON [SMigration].[Metadata_IgnoredRecords] ([DatabaseName], [RegistryGuid], [SourceRowGuid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Metadata_IgnoredRecords_DatabaseTable] on table [SMigration].[Metadata_IgnoredRecords]')
GO
CREATE INDEX [IX_Metadata_IgnoredRecords_DatabaseTable]
  ON [SMigration].[Metadata_IgnoredRecords] ([DatabaseName], [SchemaName], [TableName], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO
