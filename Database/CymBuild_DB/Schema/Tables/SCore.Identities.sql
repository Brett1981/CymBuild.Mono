SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [SCore].[Identities] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Identities_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Identities_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [FullName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Identities_FullName] DEFAULT (N''),
  [EmailAddress] [nvarchar](150) NOT NULL CONSTRAINT [DF_Tickets_EmailAddress] DEFAULT (N''),
  [UserGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Identities_UserGuid] DEFAULT (newid()),
  [JobTitle] [nvarchar](50) NOT NULL CONSTRAINT [DF_Identities_JobTitle] DEFAULT (''),
  [OriganisationalUnitId] [int] NOT NULL CONSTRAINT [DF_Identities_OriganisationalUnitId] DEFAULT (-1),
  [IsActive] [bit] NOT NULL CONSTRAINT [DF_Identities_IsActive] DEFAULT (0),
  [ContactId] [int] NOT NULL CONSTRAINT [DF__Identitie__Conta__6EE2037B] DEFAULT (-1),
  [BillableRate] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Identities_BillableRate] DEFAULT (0),
  [LoweredEmailAddress] AS (lower([EmailAddress])) PERSISTED,
  [Signature] [varbinary](max) NOT NULL CONSTRAINT [DF_Identities_Signature] DEFAULT (0x),
  CONSTRAINT [PK_Identities] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [IX_Identities_List]
  ON [SCore].[Identities] ([IsActive], [RowStatus])
  INCLUDE ([FullName], [Guid], [OriganisationalUnitId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [IsActive]=(1))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE INDEX [IX_Identities_LoweredEmailAddress]
  ON [SCore].[Identities] ([LoweredEmailAddress])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE INDEX [IX_Identities_Name]
  ON [SCore].[Identities] ([FullName], [IsActive], [RowStatus])
  WHERE ([RowStatus]<>(254) AND [RowStatus]<>(0))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Identities_EmailAddress]
  ON [SCore].[Identities] ([EmailAddress])
  INCLUDE ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Identities_Guid]
  ON [SCore].[Identities] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[Identities]
  ADD CONSTRAINT [FK_Identities_ContactId] FOREIGN KEY ([ContactId]) REFERENCES [SCrm].[Contacts] ([ID])
GO

ALTER TABLE [SCore].[Identities] WITH NOCHECK
  ADD CONSTRAINT [FK_Identities_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCore].[Identities]
  NOCHECK CONSTRAINT [FK_Identities_DataObjects]
GO

ALTER TABLE [SCore].[Identities]
  ADD CONSTRAINT [FK_Identities_OrganisationalUnits] FOREIGN KEY ([OriganisationalUnitId]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

ALTER TABLE [SCore].[Identities]
  ADD CONSTRAINT [FK_Identities_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Users mapped to their Entra ID''s', 'SCHEMA', N'SCore', 'TABLE', N'Identities'
GO