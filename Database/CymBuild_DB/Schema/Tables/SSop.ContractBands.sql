PRINT (N'Create table [SSop].[ContractBands]')
GO
CREATE TABLE [SSop].[ContractBands] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_ContractBands_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_ContractBands_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ContractId] [int] NOT NULL CONSTRAINT [DC_ContractBands_ContractId] DEFAULT (-1),
  [PriceListId] [int] NOT NULL CONSTRAINT [DF_ContractBands_PriveListId] DEFAULT (-1),
  [MinValueOfWork] [decimal](19, 2) NOT NULL CONSTRAINT [DF_ContractBands_MinValue] DEFAULT (0),
  [MaxValueOfWork] [decimal](19, 2) NOT NULL CONSTRAINT [DF_ContractBands_MaxValue] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ContractBands_ID] on table [SSop].[ContractBands]')
GO
ALTER TABLE [SSop].[ContractBands] WITH NOCHECK
  ADD CONSTRAINT [PK_ContractBands_ID] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_ContractBands_ContractId] on table [SSop].[ContractBands]')
GO
ALTER TABLE [SSop].[ContractBands] WITH NOCHECK
  ADD CONSTRAINT [FK_ContractBands_ContractId] FOREIGN KEY ([ContractId]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_ContractBands_Guid] on table [SSop].[ContractBands]')
GO
ALTER TABLE [SSop].[ContractBands] WITH NOCHECK
  ADD CONSTRAINT [FK_ContractBands_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_ContractBands_Guid] on table [SSop].[ContractBands]')
GO
ALTER TABLE [SSop].[ContractBands]
  NOCHECK CONSTRAINT [FK_ContractBands_Guid]
GO

PRINT (N'Create foreign key [FK_ContractBands_PriceListId] on table [SSop].[ContractBands]')
GO
ALTER TABLE [SSop].[ContractBands] WITH NOCHECK
  ADD CONSTRAINT [FK_ContractBands_PriceListId] FOREIGN KEY ([PriceListId]) REFERENCES [SSop].[PriceLists] ([ID])
GO

PRINT (N'Create foreign key [FK_ContractBands_RowStatus] on table [SSop].[ContractBands]')
GO
ALTER TABLE [SSop].[ContractBands] WITH NOCHECK
  ADD CONSTRAINT [FK_ContractBands_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO