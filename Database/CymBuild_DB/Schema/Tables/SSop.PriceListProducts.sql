CREATE TABLE [SSop].[PriceListProducts] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_PriceListProducts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_PriceListProducts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [PriceListId] [int] NOT NULL CONSTRAINT [DF_PriceListProducts_PriceListId] DEFAULT (-1),
  [ProductId] [int] NOT NULL CONSTRAINT [DF_PriceListProducts_ProductId] DEFAULT (-1),
  [Price] [decimal](9, 2) NOT NULL CONSTRAINT [DF_PriceListProducts_Price] DEFAULT (0),
  CONSTRAINT [PK_PriceListProducts] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

ALTER TABLE [SSop].[PriceListProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_PriceListProducts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[PriceListProducts]
  NOCHECK CONSTRAINT [FK_PriceListProducts_DataObjects]
GO

ALTER TABLE [SSop].[PriceListProducts]
  ADD CONSTRAINT [FK_PriceListProducts_PriceLists] FOREIGN KEY ([PriceListId]) REFERENCES [SSop].[PriceLists] ([ID])
GO

ALTER TABLE [SSop].[PriceListProducts]
  ADD CONSTRAINT [FK_PriceListProducts_Products] FOREIGN KEY ([ProductId]) REFERENCES [SProd].[Products] ([ID])
GO

ALTER TABLE [SSop].[PriceListProducts]
  ADD CONSTRAINT [FK_PriceListProducts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO