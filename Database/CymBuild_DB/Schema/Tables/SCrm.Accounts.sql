SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SCrm].[Accounts]')
GO
CREATE TABLE [SCrm].[Accounts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Accounts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Accounts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_Accounts_Number] DEFAULT (N''),
  [Code] [nvarchar](10) NOT NULL CONSTRAINT [DF_Accounts_Code] DEFAULT (N''),
  [AccountStatusID] [int] NOT NULL CONSTRAINT [DF_Accounts_AccountStatusID] DEFAULT (-1),
  [ParentAccountID] [int] NOT NULL CONSTRAINT [DF_Accounts_ParentAccountID] DEFAULT (-1),
  [IsPurchaseLedger] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsPurchaseLedger] DEFAULT (0),
  [IsSalesLedger] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsSalesLedger] DEFAULT (0),
  [IsLocalAuthority] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsLocalAuthority] DEFAULT (0),
  [IsFireAuthority] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsFireAuthority] DEFAULT (0),
  [IsWaterAuthority] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsWaterAuthority] DEFAULT (0),
  [IsDomesticClient] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsDomesticClient] DEFAULT (0),
  [LegacyID] [int] NULL,
  [RelationshipManagerUserId] [int] NOT NULL CONSTRAINT [DF_Accounts_RelationshipManagerUserId] DEFAULT (-1),
  [CompanyRegistrationNumber] [nvarchar](50) NOT NULL CONSTRAINT [DF_Accounts_CompanyRegistrationNumber] DEFAULT (''),
  [PriceListId] [int] NOT NULL CONSTRAINT [DF_Accounts_PriceListId] DEFAULT (-1),
  [MainAccountAddressId] [int] NOT NULL CONSTRAINT [DF_Accounts_MainAccountAddressId] DEFAULT (-1),
  [MainAccountContactId] [int] NOT NULL CONSTRAINT [DF_Accounts_MainAccountContactId] DEFAULT (-1),
  [DefaultCreditTermsId] [int] NOT NULL CONSTRAINT [DF_Accounts_DefaultCreditTermsId] DEFAULT (-1),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [BillingInstruction] [nvarchar](max) NULL,
  [ConcatenatedNameCode] AS (case when isnull([Code],'')='' then [Name] else ([Name]+' - ')+[Code] end) PERSISTED NOT NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Accounts] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [PK_Accounts] PRIMARY KEY CLUSTERED ([ID]) WITH (PAD_INDEX = ON, FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Account_FieAuthority] on table [SCrm].[Accounts]')
GO
CREATE INDEX [IX_Account_FieAuthority]
  ON [SCrm].[Accounts] ([IsFireAuthority])
  INCLUDE ([Guid], [Name])
  WHERE ([IsFireAuthority]=(1))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Account_LocalAuthority] on table [SCrm].[Accounts]')
GO
CREATE INDEX [IX_Account_LocalAuthority]
  ON [SCrm].[Accounts] ([IsLocalAuthority])
  INCLUDE ([Guid], [Name])
  WHERE ([IsLocalAuthority]=(1))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Account_WaterAuthority] on table [SCrm].[Accounts]')
GO
CREATE INDEX [IX_Account_WaterAuthority]
  ON [SCrm].[Accounts] ([IsWaterAuthority])
  INCLUDE ([Guid], [Name])
  WHERE ([IsWaterAuthority]=(1))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Accounts_List] on table [SCrm].[Accounts]')
GO
CREATE INDEX [IX_Accounts_List]
  ON [SCrm].[Accounts] ([Name], [RowStatus])
  INCLUDE ([Guid], [AccountStatusID], [RelationshipManagerUserId], [MainAccountAddressId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_Accounts_Code] on table [SCrm].[Accounts]')
GO
CREATE UNIQUE INDEX [IX_UQ_Accounts_Code]
  ON [SCrm].[Accounts] ([Code], [RowStatus])
  WHERE ([Code]<>'' AND [RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Accounts_Guid] on table [SCrm].[Accounts]')
GO
CREATE UNIQUE INDEX [IX_UQ_Accounts_Guid]
  ON [SCrm].[Accounts] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_Accounts_AccountAddresses] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_AccountAddresses] FOREIGN KEY ([MainAccountAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_AccountContacts] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_AccountContacts] FOREIGN KEY ([MainAccountContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_AccountStatus] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_AccountStatus] FOREIGN KEY ([AccountStatusID]) REFERENCES [SCrm].[AccountStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_CreditTerms] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_CreditTerms] FOREIGN KEY ([DefaultCreditTermsId]) REFERENCES [SFin].[CreditTerms] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_DataObjects] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Accounts_DataObjects] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts]
  NOCHECK CONSTRAINT [FK_Accounts_DataObjects]
GO

PRINT (N'Create foreign key [FK_Accounts_Identities] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_Identities] FOREIGN KEY ([RelationshipManagerUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_PriceLists] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_PriceLists] FOREIGN KEY ([PriceListId]) REFERENCES [SSop].[PriceLists] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_RowStatus] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create full-text index on table [SCrm].[Accounts]')
GO
CREATE FULLTEXT INDEX
  ON [SCrm].[Accounts]([Name] LANGUAGE 1033)
  KEY INDEX [PK_Accounts]
  ON [AccountName]
  WITH CHANGE_TRACKING AUTO, STOPLIST Honorifics
GO