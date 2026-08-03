PRINT (N'Create table [SMigration].[Metadata_IdentityMapIgnoredIssues]')
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create unique filtered index [UX_Metadata_IdentityMapIgnoredIssues_ActiveScope] on table [SMigration].[Metadata_IdentityMapIgnoredIssues]')
GO


PRINT (N'Create index [IX_Metadata_IdentityMapIgnoredIssues_DatabaseTable] on table [SMigration].[Metadata_IdentityMapIgnoredIssues]')
GO
PRINT (N'Create table [SMigration].[Metadata_IdentityMapIgnoredIssues]')
GO
CREATE TABLE [SMigration].[Metadata_IdentityMapIgnoredIssues] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_IdentityMapIgnoredIssues_RowStatus] DEFAULT (1),
  [DatabaseName] [sysname] NOT NULL,
  [ServerName] [nvarchar](255) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapIgnoredIssues_ServerName] DEFAULT (N''),
  [EnvironmentName] [nvarchar](20) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapIgnoredIssues_EnvironmentName] DEFAULT (N''),
  [RegistryGuid] [uniqueidentifier] NOT NULL,
  [SchemaName] [nvarchar](128) NOT NULL,
  [TableName] [nvarchar](128) NOT NULL,
  [SourceRowGuid] [uniqueidentifier] NOT NULL,
  [IssueCode] [nvarchar](50) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapIgnoredIssues_IssueCode] DEFAULT (N'TargetMissing'),
  [StableIssueKey] [nvarchar](800) NOT NULL,
  [Reason] [nvarchar](500) NOT NULL CONSTRAINT [DF_Metadata_IdentityMapIgnoredIssues_Reason] DEFAULT (N''),
  [IgnoredByUserId] [int] NOT NULL CONSTRAINT [DF_Metadata_IdentityMapIgnoredIssues_IgnoredByUserId] DEFAULT (-1),
  [IgnoredOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_IdentityMapIgnoredIssues_IgnoredOnUtc] DEFAULT (sysutcdatetime()),
  [UnignoredByUserId] [int] NULL,
  [UnignoredOnUtc] [datetime2] NULL,
  [LastSeenRunGuid] [uniqueidentifier] NULL,
  [LastSeenOnUtc] [datetime2] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_IdentityMapIgnoredIssues] on table [SMigration].[Metadata_IdentityMapIgnoredIssues]')
GO
ALTER TABLE [SMigration].[Metadata_IdentityMapIgnoredIssues] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_IdentityMapIgnoredIssues] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_IdentityMapIgnoredIssues_Guid] on table [SMigration].[Metadata_IdentityMapIgnoredIssues]')
GO
ALTER TABLE [SMigration].[Metadata_IdentityMapIgnoredIssues] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_IdentityMapIgnoredIssues_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_Metadata_IdentityMapIgnoredIssues_DatabaseTable] on table [SMigration].[Metadata_IdentityMapIgnoredIssues]')
GO
CREATE INDEX [IX_Metadata_IdentityMapIgnoredIssues_DatabaseTable]
  ON [SMigration].[Metadata_IdentityMapIgnoredIssues] ([DatabaseName], [SchemaName], [TableName], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_Metadata_IdentityMapIgnoredIssues_ActiveScope] on table [SMigration].[Metadata_IdentityMapIgnoredIssues]')
GO
CREATE UNIQUE INDEX [UX_Metadata_IdentityMapIgnoredIssues_ActiveScope]
  ON [SMigration].[Metadata_IdentityMapIgnoredIssues] ([DatabaseName], [RegistryGuid], [SourceRowGuid], [IssueCode])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO