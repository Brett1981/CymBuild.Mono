PRINT (N'Create table [SJob].[JobRibaStageFees]')
GO
CREATE TABLE [SJob].[JobRibaStageFees] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobRibaStageFees_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobRibaStageFees_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL,
  [RibaStageID] [int] NOT NULL,
  [CreatedFromQuoteItemID] [bigint] NOT NULL,
  [AgreedFee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_JobRibaStageFees_AgreedFee] DEFAULT (0),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_JobRibaStageFees_CreatedDateTimeUTC] DEFAULT (sysutcdatetime()),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DF_JobRibaStageFees_CreatedByUserID] DEFAULT (-1),
  [LastUpdatedDateTimeUTC] [datetime2] NULL,
  [LastUpdatedByUserID] [int] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_JobRibaStageFees] on table [SJob].[JobRibaStageFees]')
GO
ALTER TABLE [SJob].[JobRibaStageFees] WITH NOCHECK
  ADD CONSTRAINT [PK_JobRibaStageFees] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_JobRibaStageFees_Guid] on table [SJob].[JobRibaStageFees]')
GO
ALTER TABLE [SJob].[JobRibaStageFees] WITH NOCHECK
  ADD CONSTRAINT [UQ_JobRibaStageFees_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_JobRibaStageFees_Job_Stage_Active] on table [SJob].[JobRibaStageFees]')
GO
CREATE INDEX [IX_JobRibaStageFees_Job_Stage_Active]
  ON [SJob].[JobRibaStageFees] ([JobID], [RibaStageID])
  INCLUDE ([AgreedFee], [CreatedFromQuoteItemID], [Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_JobRibaStageFees_QuoteItem_Active] on table [SJob].[JobRibaStageFees]')
GO
CREATE UNIQUE INDEX [UX_JobRibaStageFees_QuoteItem_Active]
  ON [SJob].[JobRibaStageFees] ([CreatedFromQuoteItemID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_JobRibaStageFees_DataObjects] on table [SJob].[JobRibaStageFees]')
GO
ALTER TABLE [SJob].[JobRibaStageFees] WITH NOCHECK
  ADD CONSTRAINT [FK_JobRibaStageFees_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Create foreign key [FK_JobRibaStageFees_Jobs] on table [SJob].[JobRibaStageFees]')
GO
ALTER TABLE [SJob].[JobRibaStageFees] WITH NOCHECK
  ADD CONSTRAINT [FK_JobRibaStageFees_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_JobRibaStageFees_QuoteItems] on table [SJob].[JobRibaStageFees]')
GO
ALTER TABLE [SJob].[JobRibaStageFees] WITH NOCHECK
  ADD CONSTRAINT [FK_JobRibaStageFees_QuoteItems] FOREIGN KEY ([CreatedFromQuoteItemID]) REFERENCES [SSop].[QuoteItems] ([ID])
GO

PRINT (N'Create foreign key [FK_JobRibaStageFees_RibaStages] on table [SJob].[JobRibaStageFees]')
GO
ALTER TABLE [SJob].[JobRibaStageFees] WITH NOCHECK
  ADD CONSTRAINT [FK_JobRibaStageFees_RibaStages] FOREIGN KEY ([RibaStageID]) REFERENCES [SJob].[RibaStages] ([ID])
GO