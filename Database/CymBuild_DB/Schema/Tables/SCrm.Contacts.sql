CREATE TABLE [SCrm].[Contacts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Contacts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Contacts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [PrimaryAccountID] [int] NOT NULL CONSTRAINT [DF_Contacts_AccountID] DEFAULT (-1),
  [PrimaryAddressID] [int] NOT NULL CONSTRAINT [DF_Contacts_PrimaryAddressID] DEFAULT (-1),
  [FirstName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Contacts_FirstName] DEFAULT (N''),
  [Initials] [nvarchar](10) NOT NULL CONSTRAINT [DF_Contacts_Initials] DEFAULT (''),
  [Surname] [nvarchar](250) NOT NULL CONSTRAINT [DF_Contacts_Surname] DEFAULT (N''),
  [PostNominals] [nvarchar](250) NOT NULL CONSTRAINT [DF_Contacts_PostNominals] DEFAULT (''),
  [TitleId] [smallint] NOT NULL CONSTRAINT [DF_Contacts_TitleID] DEFAULT (-1),
  [DisplayName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Contacts_DisplayName] DEFAULT (N''),
  [IsPerson] [bit] NOT NULL CONSTRAINT [DF_Contacts_IsPerson] DEFAULT (0),
  [PositionID] [int] NOT NULL CONSTRAINT [DF_Contacts_PositionID] DEFAULT (-1),
  [LegacyID] [int] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  CONSTRAINT [PK_Contacts] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE INDEX [IX_Contacts_DDL]
  ON [SCrm].[Contacts] ([DisplayName], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UX_Contacts_Guid]
  ON [SCrm].[Contacts] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[Contacts]
  ADD CONSTRAINT [FK_Contacts_Accounts] FOREIGN KEY ([PrimaryAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

ALTER TABLE [SCrm].[Contacts]
  ADD CONSTRAINT [FK_Contacts_Addresses] FOREIGN KEY ([PrimaryAddressID]) REFERENCES [SCrm].[Addresses] ([ID])
GO

ALTER TABLE [SCrm].[Contacts]
  ADD CONSTRAINT [FK_Contacts_ContactPositions] FOREIGN KEY ([PositionID]) REFERENCES [SCrm].[ContactPositions] ([ID])
GO

ALTER TABLE [SCrm].[Contacts]
  ADD CONSTRAINT [FK_Contacts_ContactTitles] FOREIGN KEY ([TitleId]) REFERENCES [SCrm].[ContactTitles] ([ID])
GO

ALTER TABLE [SCrm].[Contacts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contacts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

ALTER TABLE [SCrm].[Contacts]
  NOCHECK CONSTRAINT [FK_Contacts_DataObjects]
GO

ALTER TABLE [SCrm].[Contacts]
  ADD CONSTRAINT [FK_Contacts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SCrm].[Contacts]
  ADD CONSTRAINT [FK_Contacts_RowStatus1] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO