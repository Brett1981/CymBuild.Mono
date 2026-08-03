PRINT (N'Create table [SMigration].[Metadata_ExecutionLog]')
GO
PRINT (N'Create table [SMigration].[Metadata_ExecutionLog]')
GO
CREATE TABLE [SMigration].[Metadata_ExecutionLog] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_ExecutionLog_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [StepName] [nvarchar](100) NOT NULL,
  [StepStatus] [nvarchar](30) NOT NULL,
  [Message] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Metadata_ExecutionLog_Message] DEFAULT (N''),
  [DetailsJson] [nvarchar](max) NOT NULL CONSTRAINT [DF_Metadata_ExecutionLog_DetailsJson] DEFAULT (N'{}'),
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_ExecutionLog_CreatedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_ExecutionLog] on table [SMigration].[Metadata_ExecutionLog]')
GO
ALTER TABLE [SMigration].[Metadata_ExecutionLog] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_ExecutionLog] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_ExecutionLog_Guid] on table [SMigration].[Metadata_ExecutionLog]')
GO
ALTER TABLE [SMigration].[Metadata_ExecutionLog] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_ExecutionLog_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Metadata_ExecutionLog_RunGuid] on table [SMigration].[Metadata_ExecutionLog]')
GO
CREATE INDEX [IX_Metadata_ExecutionLog_RunGuid]
  ON [SMigration].[Metadata_ExecutionLog] ([RunGuid], [CreatedOnUtc])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Metadata_ExecutionLog_RunGuid] on table [SMigration].[Metadata_ExecutionLog]')
GO