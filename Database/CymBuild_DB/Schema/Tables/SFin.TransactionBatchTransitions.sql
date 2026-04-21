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
  [SourceTransactionRowVersion] [binary](8) NOT NULL,
  CONSTRAINT [PK_TransactionBatchTransitions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
  CONSTRAINT [UQ_TransactionBatchTransitions_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [IX_TransactionBatchTransitions_TransactionGuid_IdDesc]
  ON [SFin].[TransactionBatchTransitions] ([TransactionGuid], [ID] DESC)
  INCLUDE ([OldBatched], [NewBatched], [DateTimeUTC], [Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [UX_TransactionBatchTransitions_SourceRowVersion]
  ON [SFin].[TransactionBatchTransitions] ([TransactionGuid], [SourceTransactionRowVersion])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
  ADD CONSTRAINT [FK_TransactionBatchTransitions_CreatedBy] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
  ADD CONSTRAINT [FK_TransactionBatchTransitions_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
  NOCHECK CONSTRAINT [FK_TransactionBatchTransitions_DataObjects]
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
  ADD CONSTRAINT [FK_TransactionBatchTransitions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
  ADD CONSTRAINT [FK_TransactionBatchTransitions_Surveyor] FOREIGN KEY ([SurveyorUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
  ADD CONSTRAINT [FK_TransactionBatchTransitions_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID])
GO