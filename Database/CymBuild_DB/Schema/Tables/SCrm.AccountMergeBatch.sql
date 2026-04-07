CREATE TABLE [SCrm].[AccountMergeBatch] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountMergeBatch_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountMergeBatch_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SourceAccountId] [int] NOT NULL CONSTRAINT [DF_AccountMergeBatch_SourceAccountId] DEFAULT (-1),
  [TargetAccountId] [int] NOT NULL CONSTRAINT [DF_AccountMergeBatch_TargetAccountId] DEFAULT (-1),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_AccountMergeBatch_CreatedByUserId] DEFAULT (-1),
  [CheckedByUserId] [int] NOT NULL CONSTRAINT [DF_AccountMergeBatch_CheckedByUserId] DEFAULT (-1),
  [IsComplete] [bit] NOT NULL CONSTRAINT [DF_AccountMergeBatch_IsComplete] DEFAULT (0),
  CONSTRAINT [PK_AccountMergeBatch] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_AccountMergeBatch_Guid]
  ON [SCrm].[AccountMergeBatch] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[AccountMergeBatch]
  ADD CONSTRAINT [FK_AccountMergeBatch_Accounts] FOREIGN KEY ([SourceAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

ALTER TABLE [SCrm].[AccountMergeBatch]
  ADD CONSTRAINT [FK_AccountMergeBatch_Accounts1] FOREIGN KEY ([TargetAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

ALTER TABLE [SCrm].[AccountMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountMergeBatch_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[AccountMergeBatch]
  NOCHECK CONSTRAINT [FK_AccountMergeBatch_DataObjects]
GO

ALTER TABLE [SCrm].[AccountMergeBatch]
  ADD CONSTRAINT [FK_AccountMergeBatch_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SCrm].[AccountMergeBatch]
  ADD CONSTRAINT [FK_AccountMergeBatch_Identities1] FOREIGN KEY ([CheckedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SCrm].[AccountMergeBatch]
  ADD CONSTRAINT [FK_AccountMergeBatch_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO