PRINT (N'Create table [SMigration].[Schema_Run]')
GO
PRINT (N'Create table [SMigration].[Schema_Run]')
GO
CREATE TABLE [SMigration].[Schema_Run] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Schema_Run_RowStatus] DEFAULT (1),
  [SourceEnvironment] [nvarchar](20) NOT NULL,
  [TargetEnvironment] [nvarchar](20) NOT NULL,
  [SourceServerName] [nvarchar](255) NOT NULL,
  [SourceDatabaseName] [nvarchar](255) NOT NULL,
  [TargetServerName] [nvarchar](255) NOT NULL,
  [TargetDatabaseName] [nvarchar](255) NOT NULL,
  [JiraReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Schema_Run_JiraReference] DEFAULT (N''),
  [ReleaseReference] [nvarchar](100) NOT NULL CONSTRAINT [DF_Schema_Run_ReleaseReference] DEFAULT (N''),
  [RunStatus] [nvarchar](30) NOT NULL,
  [IsReviewed] [bit] NOT NULL CONSTRAINT [DF_Schema_Run_IsReviewed] DEFAULT (0),
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Schema_Run_CreatedOnUtc] DEFAULT (sysutcdatetime()),
  [ComparedOnUtc] [datetime2] NULL,
  [ValidatedOnUtc] [datetime2] NULL,
  [ReviewedOnUtc] [datetime2] NULL,
  [AppliedOnUtc] [datetime2] NULL,
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_Schema_Run_CreatedByUserId] DEFAULT (-1),
  [ReviewedByUserId] [int] NOT NULL CONSTRAINT [DF_Schema_Run_ReviewedByUserId] DEFAULT (-1),
  [DeploymentReference] [nvarchar](100) NOT NULL CONSTRAINT [DF_Schema_Run_DeploymentReference] DEFAULT (N''),
  [Notes] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Schema_Run_Notes] DEFAULT (N''),
  [SummaryJson] [nvarchar](max) NOT NULL CONSTRAINT [DF_Schema_Run_SummaryJson] DEFAULT (N'{}')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Schema_Run] on table [SMigration].[Schema_Run]')
GO
ALTER TABLE [SMigration].[Schema_Run] WITH NOCHECK
  ADD CONSTRAINT [PK_Schema_Run] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Schema_Run_Guid] on table [SMigration].[Schema_Run]')
GO
ALTER TABLE [SMigration].[Schema_Run] WITH NOCHECK
  ADD CONSTRAINT [UQ_Schema_Run_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO