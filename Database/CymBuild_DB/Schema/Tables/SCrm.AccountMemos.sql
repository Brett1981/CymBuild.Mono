CREATE TABLE [SCrm].[AccountMemos] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountMemos_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountMemos_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AccountID] [int] NOT NULL CONSTRAINT [DF_AccountMemos_JobID] DEFAULT (-1),
  [Memo] [nvarchar](max) NOT NULL CONSTRAINT [DF_AccountMemos_Memo] DEFAULT (''),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_AccountMemos_CreatedDateTime] DEFAULT (getutcdate()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_AccountMemos_CreatedByUserId] DEFAULT (-1),
  CONSTRAINT [PK_AccountMemos] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [IX_AccountMemos_AccountID]
  ON [SCrm].[AccountMemos] ([AccountID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_AccountMemos_Guid]
  ON [SCrm].[AccountMemos] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[AccountMemos]
  ADD CONSTRAINT [FK_AccountMemos_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

ALTER TABLE [SCrm].[AccountMemos] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountMemos_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[AccountMemos]
  NOCHECK CONSTRAINT [FK_AccountMemos_DataObjects]
GO

ALTER TABLE [SCrm].[AccountMemos]
  ADD CONSTRAINT [FK_AccountMemos_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SCrm].[AccountMemos]
  ADD CONSTRAINT [FK_AccountMemos_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO