CREATE TABLE [SCrm].[AccountContacts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountContacts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountContacts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AccountID] [int] NOT NULL CONSTRAINT [DF_AccountContacts_AccountID] DEFAULT (-1),
  [ContactID] [int] NOT NULL CONSTRAINT [DF_AccountContacts_ContactID] DEFAULT (-1),
  [PrimaryAccountAddressID] [int] NOT NULL CONSTRAINT [DF_AccountContacts_PrimaryAccountAddressID] DEFAULT (-1),
  CONSTRAINT [PK_AccountContacts] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_AccountContacts_Account]
  ON [SCrm].[AccountContacts] ([AccountID], [ContactID], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_AccountContacts_Guid]
  ON [SCrm].[AccountContacts] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[AccountContacts]
  ADD CONSTRAINT [FK_AccountContacts_AccountAddresses] FOREIGN KEY ([PrimaryAccountAddressID]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

ALTER TABLE [SCrm].[AccountContacts]
  ADD CONSTRAINT [FK_AccountContacts_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCrm].[AccountContacts]
  ADD CONSTRAINT [FK_AccountContacts_Contacts] FOREIGN KEY ([ContactID]) REFERENCES [SCrm].[Contacts] ([ID])
GO

ALTER TABLE [SCrm].[AccountContacts] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountContacts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[AccountContacts]
  NOCHECK CONSTRAINT [FK_AccountContacts_DataObjects]
GO

ALTER TABLE [SCrm].[AccountContacts]
  ADD CONSTRAINT [FK_AccountContacts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO