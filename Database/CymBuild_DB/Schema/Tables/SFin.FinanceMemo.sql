CREATE TABLE [SFin].[FinanceMemo] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_FinanceMemo_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_FinanceMemo_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [TransactionID] [bigint] NOT NULL CONSTRAINT [DF_FinanceMemo_TransactionID] DEFAULT (-1),
  [AccountID] [int] NOT NULL CONSTRAINT [DF_FinanceMemo_AccountID] DEFAULT (-1),
  [JobID] [int] NOT NULL CONSTRAINT [DF_FinanceMemo_JobID] DEFAULT (-1),
  [Memo] [nvarchar](max) NOT NULL CONSTRAINT [DF_FinanceMemo_Memo] DEFAULT (''),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_FinanceMemo_CreatedDateTime] DEFAULT (getutcdate()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_FinanceMemo_CreatedByUserId] DEFAULT (-1),
  [LegacyId] [bigint] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  CONSTRAINT [PK_FinanceMemo] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [IX_FinanceMemo_AccountId]
  ON [SFin].[FinanceMemo] ([RowStatus], [AccountID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_FinanceMemo_JobId]
  ON [SFin].[FinanceMemo] ([JobID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_FinanceMemo_Guid]
  ON [SFin].[FinanceMemo] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[FinanceMemo]
  ADD CONSTRAINT [FK_FinanceMemo_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

ALTER TABLE [SFin].[FinanceMemo] WITH NOCHECK
  ADD CONSTRAINT [FK_FinanceMemo_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[FinanceMemo]
  NOCHECK CONSTRAINT [FK_FinanceMemo_DataObjects]
GO

ALTER TABLE [SFin].[FinanceMemo]
  ADD CONSTRAINT [FK_FinanceMemo_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SFin].[FinanceMemo]
  ADD CONSTRAINT [FK_FinanceMemo_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID])
GO

ALTER TABLE [SFin].[FinanceMemo]
  ADD CONSTRAINT [FK_FinanceMemo_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SFin].[FinanceMemo]
  ADD CONSTRAINT [FK_FinanceMemo_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID])
GO