CREATE TABLE [SSop].[PriceLists] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_PriceLists_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_PriceLists_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_PriceLists_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DF_PriceLists_IsActive] DEFAULT (0),
  [UpliftOnStandardPrice] [decimal](9, 2) NOT NULL CONSTRAINT [DF_PriceLists_UpliftOnStandardPrice] DEFAULT (0),
  CONSTRAINT [PK_PriceLists] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

ALTER TABLE [SSop].[PriceLists] WITH NOCHECK
  ADD CONSTRAINT [FK_PriceLists_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[PriceLists]
  NOCHECK CONSTRAINT [FK_PriceLists_DataObjects]
GO

ALTER TABLE [SSop].[PriceLists]
  ADD CONSTRAINT [FK_PriceLists_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO