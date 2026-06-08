PRINT (N'Create table [SMigration].[Metadata_Run]')
GO
CREATE TABLE [SMigration].[Metadata_Run] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_Run_RowStatus] DEFAULT (1),
  [SourceEnvironment] [nvarchar](20) NOT NULL,
  [TargetEnvironment] [nvarchar](20) NOT NULL,
  [SourceServerName] [nvarchar](255) NOT NULL,
  [SourceDatabaseName] [nvarchar](255) NOT NULL,
  [TargetServerName] [nvarchar](255) NOT NULL,
  [TargetDatabaseName] [nvarchar](255) NOT NULL,
  [RunStatus] [nvarchar](30) NOT NULL,
  [IsValidateOnly] [bit] NOT NULL CONSTRAINT [DF_Metadata_Run_IsValidateOnly] DEFAULT (1),
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_Run_CreatedOnUtc] DEFAULT (sysutcdatetime()),
  [ValidatedOnUtc] [datetime2] NULL,
  [AppliedOnUtc] [datetime2] NULL,
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_Metadata_Run_CreatedByUserId] DEFAULT (-1),
  [SummaryJson] [nvarchar](max) NOT NULL CONSTRAINT [DF_Metadata_Run_SummaryJson] DEFAULT (N'{}')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_Run] on table [SMigration].[Metadata_Run]')
GO
ALTER TABLE [SMigration].[Metadata_Run] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_Run] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_Run_Guid] on table [SMigration].[Metadata_Run]')
GO
ALTER TABLE [SMigration].[Metadata_Run] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_Run_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO