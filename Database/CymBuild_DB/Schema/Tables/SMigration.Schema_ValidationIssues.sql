PRINT (N'Create table [SMigration].[Schema_ValidationIssues]')
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Schema_ValidationIssues_Run_Active] on table [SMigration].[Schema_ValidationIssues]')
GO
PRINT (N'Create table [SMigration].[Schema_ValidationIssues]')
GO
CREATE TABLE [SMigration].[Schema_ValidationIssues] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [ComparisonGuid] [uniqueidentifier] NULL,
  [Severity] [nvarchar](10) NOT NULL,
  [IssueCode] [nvarchar](100) NOT NULL,
  [IssueMessage] [nvarchar](2000) NOT NULL,
  [ObjectType] [nvarchar](50) NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_ObjectType] DEFAULT (N''),
  [SchemaName] [nvarchar](128) NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_SchemaName] DEFAULT (N''),
  [ObjectName] [nvarchar](512) NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_ObjectName] DEFAULT (N''),
  [DetailsJson] [nvarchar](max) NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_DetailsJson] DEFAULT (N'{}'),
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Schema_ValidationIssues_CreatedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Schema_ValidationIssues] on table [SMigration].[Schema_ValidationIssues]')
GO
ALTER TABLE [SMigration].[Schema_ValidationIssues] WITH NOCHECK
  ADD CONSTRAINT [PK_Schema_ValidationIssues] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Schema_ValidationIssues_Guid] on table [SMigration].[Schema_ValidationIssues]')
GO
ALTER TABLE [SMigration].[Schema_ValidationIssues] WITH NOCHECK
  ADD CONSTRAINT [UQ_Schema_ValidationIssues_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Schema_ValidationIssues_Run_Active] on table [SMigration].[Schema_ValidationIssues]')
GO
CREATE INDEX [IX_Schema_ValidationIssues_Run_Active]
  ON [SMigration].[Schema_ValidationIssues] ([RunGuid], [Severity], [ObjectType], [SchemaName], [ObjectName])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO