PRINT (N'Create table [SFin].[TransactionBatchTransitions]')
GO
CREATE TABLE [SFin].[TransactionBatchTransitions] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_TransactionBatchTransitions_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_TransactionBatchTransitions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [TransactionID] [bigint] NOT NULL,
  [TransactionGuid] [uniqueidentifier] NOT NULL,
  [OldBatched] [bit] NOT NULL,
  [NewBatched] [bit] NOT NULL,
  [DateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_TransactionBatchTransitions_DateTimeUTC] DEFAULT (sysutcdatetime()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_TransactionBatchTransitions_CreatedByUserId] DEFAULT (-1),
  [SurveyorUserId] [int] NOT NULL CONSTRAINT [DF_TransactionBatchTransitions_SurveyorUserId] DEFAULT (-1),
  [Comment] [nvarchar](max) NULL,
  [IsImported] [bit] NOT NULL CONSTRAINT [DF_TransactionBatchTransitions_IsImported] DEFAULT (0),
  [SourceTransactionRowVersion] [binary](8) NOT NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TransactionBatchTransitions] on table [SFin].[TransactionBatchTransitions]')
GO
ALTER TABLE [SFin].[TransactionBatchTransitions] WITH NOCHECK
  ADD CONSTRAINT [PK_TransactionBatchTransitions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_TransactionBatchTransitions_Guid] on table [SFin].[TransactionBatchTransitions]')
GO
ALTER TABLE [SFin].[TransactionBatchTransitions] WITH NOCHECK
  ADD CONSTRAINT [UQ_TransactionBatchTransitions_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_TransactionBatchTransitions_SourceRowVersion] on table [SFin].[TransactionBatchTransitions]')
GO
CREATE UNIQUE INDEX [UX_TransactionBatchTransitions_SourceRowVersion]
  ON [SFin].[TransactionBatchTransitions] ([TransactionGuid], [SourceTransactionRowVersion])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_TransactionBatchTransitions_CreatedBy] on table [SFin].[TransactionBatchTransitions]')
GO
ALTER TABLE [SFin].[TransactionBatchTransitions] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionBatchTransitions_CreatedBy] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionBatchTransitions_DataObjects] on table [SFin].[TransactionBatchTransitions]')
GO
ALTER TABLE [SFin].[TransactionBatchTransitions] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionBatchTransitions_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_TransactionBatchTransitions_DataObjects] on table [SFin].[TransactionBatchTransitions]')
GO
ALTER TABLE [SFin].[TransactionBatchTransitions]
  NOCHECK CONSTRAINT [FK_TransactionBatchTransitions_DataObjects]
GO

PRINT (N'Create foreign key [FK_TransactionBatchTransitions_RowStatus] on table [SFin].[TransactionBatchTransitions]')
GO
ALTER TABLE [SFin].[TransactionBatchTransitions] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionBatchTransitions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionBatchTransitions_Surveyor] on table [SFin].[TransactionBatchTransitions]')
GO
ALTER TABLE [SFin].[TransactionBatchTransitions] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionBatchTransitions_Surveyor] FOREIGN KEY ([SurveyorUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionBatchTransitions_Transactions] on table [SFin].[TransactionBatchTransitions]')
GO
ALTER TABLE [SFin].[TransactionBatchTransitions] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionBatchTransitions_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID])
GO