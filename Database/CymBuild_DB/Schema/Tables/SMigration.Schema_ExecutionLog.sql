PRINT (N'Create table [SMigration].[Schema_ExecutionLog]')
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Schema_ExecutionLog_Run_Active] on table [SMigration].[Schema_ExecutionLog]')
GO
PRINT (N'Create table [SMigration].[Schema_ExecutionLog]')
GO
CREATE TABLE [SMigration].[Schema_ExecutionLog] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Schema_ExecutionLog_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [StepName] [nvarchar](100) NOT NULL,
  [StepStatus] [nvarchar](30) NOT NULL,
  [Message] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Schema_ExecutionLog_Message] DEFAULT (N''),
  [DetailsJson] [nvarchar](max) NOT NULL CONSTRAINT [DF_Schema_ExecutionLog_DetailsJson] DEFAULT (N'{}'),
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Schema_ExecutionLog_CreatedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Schema_ExecutionLog] on table [SMigration].[Schema_ExecutionLog]')
GO
ALTER TABLE [SMigration].[Schema_ExecutionLog] WITH NOCHECK
  ADD CONSTRAINT [PK_Schema_ExecutionLog] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Schema_ExecutionLog_Guid] on table [SMigration].[Schema_ExecutionLog]')
GO
ALTER TABLE [SMigration].[Schema_ExecutionLog] WITH NOCHECK
  ADD CONSTRAINT [UQ_Schema_ExecutionLog_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Schema_ExecutionLog_Run_Active] on table [SMigration].[Schema_ExecutionLog]')
GO
CREATE INDEX [IX_Schema_ExecutionLog_Run_Active]
  ON [SMigration].[Schema_ExecutionLog] ([RunGuid], [ID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO