PRINT (N'Create table [SJob].[JobStages]')
GO
CREATE TABLE [SJob].[JobStages] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobRIBAStages_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobRIBAStages_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DF_JobRIBAStages_JobID] DEFAULT (-1),
  [RIBAStageID] [int] NOT NULL CONSTRAINT [DF_JobStages_RIBAStageID] DEFAULT (-1),
  [Number] [int] NOT NULL CONSTRAINT [DF_JobStages_Number] DEFAULT (0),
  [Description] [nvarchar](500) NOT NULL CONSTRAINT [DF_JobStages_Description] DEFAULT (''),
  [StartDateTime] [datetime2] NULL,
  [EndDateTime] [datetime2] NULL,
  [CompletedDateTimeUTC] [datetime2] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_JobRIBAStages] on table [SJob].[JobStages]')
GO
ALTER TABLE [SJob].[JobStages] WITH NOCHECK
  ADD CONSTRAINT [PK_JobRIBAStages] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_JobStages_DataObjects] on table [SJob].[JobStages]')
GO
ALTER TABLE [SJob].[JobStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobStages_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_JobStages_DataObjects] on table [SJob].[JobStages]')
GO
ALTER TABLE [SJob].[JobStages]
  NOCHECK CONSTRAINT [FK_JobStages_DataObjects]
GO

PRINT (N'Create foreign key [FK_JobStages_Jobs] on table [SJob].[JobStages]')
GO
ALTER TABLE [SJob].[JobStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobStages_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_JobStages_RIBAStages] on table [SJob].[JobStages]')
GO
ALTER TABLE [SJob].[JobStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobStages_RIBAStages] FOREIGN KEY ([RIBAStageID]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_JobStages_RowStatus] on table [SJob].[JobStages]')
GO
ALTER TABLE [SJob].[JobStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobStages_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO