PRINT (N'Create table [SJob].[FeeAmendmentRibaStages]')
GO
PRINT (N'Create table [SJob].[FeeAmendmentRibaStages]')
GO
CREATE TABLE [SJob].[FeeAmendmentRibaStages] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_FeeAmendmentRibaStages_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_FeeAmendmentRibaStages_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [FeeAmendmentID] [bigint] NOT NULL,
  [JobID] [int] NOT NULL,
  [RibaStageID] [int] NOT NULL,
  [FeeChange] [decimal](19, 2) NOT NULL CONSTRAINT [DF_FeeAmendmentRibaStages_FeeChange] DEFAULT (0),
  [MeetingChange] [decimal](19, 2) NOT NULL CONSTRAINT [DF_FeeAmendmentRibaStages_MeetingChange] DEFAULT (0),
  [VisitChange] [decimal](19, 2) NOT NULL CONSTRAINT [DF_FeeAmendmentRibaStages_VisitChange] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_FeeAmendmentRibaStages] on table [SJob].[FeeAmendmentRibaStages]')
GO
ALTER TABLE [SJob].[FeeAmendmentRibaStages] WITH NOCHECK
  ADD CONSTRAINT [PK_FeeAmendmentRibaStages] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_FeeAmendmentRibaStages_Guid] on table [SJob].[FeeAmendmentRibaStages]')
GO
ALTER TABLE [SJob].[FeeAmendmentRibaStages] WITH NOCHECK
  ADD CONSTRAINT [UQ_FeeAmendmentRibaStages_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_FeeAmendmentRibaStages_DataObjects] on table [SJob].[FeeAmendmentRibaStages]')
GO
ALTER TABLE [SJob].[FeeAmendmentRibaStages] WITH NOCHECK
  ADD CONSTRAINT [FK_FeeAmendmentRibaStages_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_FeeAmendmentRibaStages_DataObjects] on table [SJob].[FeeAmendmentRibaStages]')
GO
ALTER TABLE [SJob].[FeeAmendmentRibaStages]
  NOCHECK CONSTRAINT [FK_FeeAmendmentRibaStages_DataObjects]
GO

PRINT (N'Create foreign key [FK_FeeAmendmentRibaStages_FeeAmendment] on table [SJob].[FeeAmendmentRibaStages]')
GO
ALTER TABLE [SJob].[FeeAmendmentRibaStages] WITH NOCHECK
  ADD CONSTRAINT [FK_FeeAmendmentRibaStages_FeeAmendment] FOREIGN KEY ([FeeAmendmentID]) REFERENCES [SJob].[FeeAmendment] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_FeeAmendmentRibaStages_Jobs] on table [SJob].[FeeAmendmentRibaStages]')
GO
ALTER TABLE [SJob].[FeeAmendmentRibaStages] WITH NOCHECK
  ADD CONSTRAINT [FK_FeeAmendmentRibaStages_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_FeeAmendmentRibaStages_RibaStages] on table [SJob].[FeeAmendmentRibaStages]')
GO
ALTER TABLE [SJob].[FeeAmendmentRibaStages] WITH NOCHECK
  ADD CONSTRAINT [FK_FeeAmendmentRibaStages_RibaStages] FOREIGN KEY ([RibaStageID]) REFERENCES [SJob].[RibaStages] ([ID])
GO