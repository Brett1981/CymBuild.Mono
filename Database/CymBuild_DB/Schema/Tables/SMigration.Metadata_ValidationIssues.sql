PRINT (N'Create table [SMigration].[Metadata_ValidationIssues]')
GO
CREATE TABLE [SMigration].[Metadata_ValidationIssues] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_ValidationIssues_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [RegistryGuid] [uniqueidentifier] NULL,
  [SourceRowGuid] [uniqueidentifier] NULL,
  [Severity] [nvarchar](20) NOT NULL,
  [IssueCode] [nvarchar](100) NOT NULL,
  [IssueMessage] [nvarchar](2000) NOT NULL,
  [DetailsJson] [nvarchar](max) NOT NULL CONSTRAINT [DF_Metadata_ValidationIssues_DetailsJson] DEFAULT (N'{}'),
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_ValidationIssues_CreatedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_ValidationIssues] on table [SMigration].[Metadata_ValidationIssues]')
GO
ALTER TABLE [SMigration].[Metadata_ValidationIssues] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_ValidationIssues] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_ValidationIssues_Guid] on table [SMigration].[Metadata_ValidationIssues]')
GO
ALTER TABLE [SMigration].[Metadata_ValidationIssues] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_ValidationIssues_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Metadata_ValidationIssues_RunGuid] on table [SMigration].[Metadata_ValidationIssues]')
GO
CREATE INDEX [IX_Metadata_ValidationIssues_RunGuid]
  ON [SMigration].[Metadata_ValidationIssues] ([RunGuid], [Severity], [IssueCode])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO