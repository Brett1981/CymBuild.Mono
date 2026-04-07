CREATE TABLE [SCrm].[AccountAddresses] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountAddresses_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountAddresses_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AccountID] [int] NOT NULL CONSTRAINT [DF_AccountAddresses_AccountID] DEFAULT (-1),
  [AddressID] [int] NOT NULL CONSTRAINT [DF_AccountAddresses_AddressID] DEFAULT (-1),
  [IsMain] [bit] NOT NULL CONSTRAINT [DF_AccountAddresses_IsMain] DEFAULT (0),
  CONSTRAINT [PK_AccountAddresses] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE INDEX [IX_AccountAddresses_AccountID]
  ON [SCrm].[AccountAddresses] ([AccountID])
  INCLUDE ([RowStatus], [Guid], [AddressID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_AccountAddresses_AccountID_AddressID]
  ON [SCrm].[AccountAddresses] ([AccountID], [AddressID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_AccountAddresses_Guid]
  ON [SCrm].[AccountAddresses] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[AccountAddresses]
  ADD CONSTRAINT [FK_AccountAddresses_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCrm].[AccountAddresses]
  ADD CONSTRAINT [FK_AccountAddresses_Addresses] FOREIGN KEY ([AddressID]) REFERENCES [SCrm].[Addresses] ([ID])
GO

ALTER TABLE [SCrm].[AccountAddresses] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountAddresses_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[AccountAddresses]
  NOCHECK CONSTRAINT [FK_AccountAddresses_DataObjects]
GO

ALTER TABLE [SCrm].[AccountAddresses]
  ADD CONSTRAINT [FK_AccountAddresses_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO