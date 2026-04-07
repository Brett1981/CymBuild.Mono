CREATE TABLE [SSop].[Contracts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Contracts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Contracts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AccountID] [int] NOT NULL CONSTRAINT [DF_Contracts_AccountID] DEFAULT (-1),
  [StartDate] [date] NOT NULL CONSTRAINT [DF_Contracts_StartDate] DEFAULT (getdate()),
  [EndDate] [date] NULL,
  [NextReviewDate] [date] NOT NULL CONSTRAINT [DF_Contracts_NextReviewDate] DEFAULT (getdate()),
  [SignatoryId] [int] NOT NULL CONSTRAINT [DF_Contracts_SignatoryId] DEFAULT (-1),
  [Details] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Contracts_Details] DEFAULT (''),
  [PriceListId] [int] NOT NULL CONSTRAINT [DF_Contracts_PriceListId] DEFAULT (-1),
  [MinValueOfWork] [decimal](19, 2) NOT NULL DEFAULT (0),
  [MaxValueOfWork] [decimal](19, 2) NOT NULL DEFAULT (0),
  [HasCustomTerms] [bit] NOT NULL DEFAULT (0),
  [ContractTypeId] [int] NOT NULL DEFAULT (-1),
  [CommercialReviewUndertakenByUserId] [int] NOT NULL DEFAULT (-1),
  CONSTRAINT [PK_Contracts] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Contracts_Guid]
  ON [SSop].[Contracts] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

ALTER TABLE [SSop].[Contracts]
  ADD CONSTRAINT [FK_Contracts_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

ALTER TABLE [SSop].[Contracts]
  ADD CONSTRAINT [FK_Contracts_CommercialReviewUndertakenByUserId] FOREIGN KEY ([CommercialReviewUndertakenByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contracts_ContractTypeId] FOREIGN KEY ([ContractTypeId]) REFERENCES [SSop].[ContractTypes] ([ID])
GO

ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contracts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[Contracts]
  NOCHECK CONSTRAINT [FK_Contracts_DataObjects]
GO

ALTER TABLE [SSop].[Contracts]
  ADD CONSTRAINT [FK_Contracts_Identities] FOREIGN KEY ([SignatoryId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SSop].[Contracts]
  ADD CONSTRAINT [FK_Contracts_PriceLists] FOREIGN KEY ([PriceListId]) REFERENCES [SSop].[PriceLists] ([ID])
GO

ALTER TABLE [SSop].[Contracts]
  ADD CONSTRAINT [FK_Contracts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO