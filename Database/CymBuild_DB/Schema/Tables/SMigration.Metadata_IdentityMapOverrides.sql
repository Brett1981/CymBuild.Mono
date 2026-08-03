PRINT (N'Create table [SMigration].[Metadata_IdentityMapOverrides]')
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create unique filtered index [UX_Metadata_IdentityMapOverrides_ActiveScope] on table [SMigration].[Metadata_IdentityMapOverrides]')
GO


PRINT (N'Create index [IX_Metadata_IdentityMapOverrides_DatabaseTable] on table [SMigration].[Metadata_IdentityMapOverrides]')
GO
PRINT (N'Create table [SMigration].[Metadata_IdentityMapOverrides]')
GO
CREATE TABLE [SMigration].[Metadata_IdentityMapOverrides] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_RowStatus] DEFAULT (1),
  [DatabaseName] [sysname] NOT NULL,
  [ServerName] [nvarchar](255) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_ServerName] DEFAULT (N''),
  [EnvironmentName] [nvarchar](20) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_EnvironmentName] DEFAULT (N''),
  [RegistryGuid] [uniqueidentifier] NOT NULL,
  [SchemaName] [nvarchar](128) NOT NULL,
  [TableName] [nvarchar](128) NOT NULL,
  [SourceRowGuid] [uniqueidentifier] NOT NULL,
  [TargetRowGuid] [uniqueidentifier] NOT NULL,
  [TargetRowId] [bigint] NULL,
  [TargetDisplayName] [nvarchar](500) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_TargetDisplayName] DEFAULT (N''),
  [StableOverrideKey] [nvarchar](800) NOT NULL,
  [Reason] [nvarchar](500) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_Reason] DEFAULT (N''),
  [MappedByUserId] [int] NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_MappedByUserId] DEFAULT (-1),
  [MappedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_IdentityMapOverrides_MappedOnUtc] DEFAULT (sysutcdatetime()),
  [UnmappedByUserId] [int] NULL,
  [UnmappedOnUtc] [datetime2] NULL,
  [LastSeenRunGuid] [uniqueidentifier] NULL,
  [LastSeenOnUtc] [datetime2] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_IdentityMapOverrides] on table [SMigration].[Metadata_IdentityMapOverrides]')
GO
ALTER TABLE [SMigration].[Metadata_IdentityMapOverrides] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_IdentityMapOverrides] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_IdentityMapOverrides_Guid] on table [SMigration].[Metadata_IdentityMapOverrides]')
GO
ALTER TABLE [SMigration].[Metadata_IdentityMapOverrides] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_IdentityMapOverrides_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_Metadata_IdentityMapOverrides_DatabaseTable] on table [SMigration].[Metadata_IdentityMapOverrides]')
GO
CREATE INDEX [IX_Metadata_IdentityMapOverrides_DatabaseTable]
  ON [SMigration].[Metadata_IdentityMapOverrides] ([DatabaseName], [SchemaName], [TableName], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_Metadata_IdentityMapOverrides_ActiveScope] on table [SMigration].[Metadata_IdentityMapOverrides]')
GO
CREATE UNIQUE INDEX [UX_Metadata_IdentityMapOverrides_ActiveScope]
  ON [SMigration].[Metadata_IdentityMapOverrides] ([DatabaseName], [RegistryGuid], [SourceRowGuid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO