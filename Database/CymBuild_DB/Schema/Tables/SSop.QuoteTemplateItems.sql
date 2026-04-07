CREATE TABLE [SSop].[QuoteTemplateItems] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteTemplateSectionId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_QuoteSectionId] DEFAULT (-1),
  [ProductId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_ProductId] DEFAULT (-1),
  [Details] [nvarchar](2000) NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Details] DEFAULT (''),
  [Net] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Net] DEFAULT (0),
  [VatRate] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Vat] DEFAULT (0),
  [DoNotConsolidateJob] [bit] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_DoNotConsolidateJob] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_SortOrder] DEFAULT (0),
  [Quantity] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Quantity] DEFAULT (0),
  CONSTRAINT [PK_QuoteTemplateItems] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

ALTER TABLE [SSop].[QuoteTemplateItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[QuoteTemplateItems]
  NOCHECK CONSTRAINT [FK_QuoteTemplateItems_DataObjects]
GO

ALTER TABLE [SSop].[QuoteTemplateItems]
  ADD CONSTRAINT [FK_QuoteTemplateItems_Products] FOREIGN KEY ([ProductId]) REFERENCES [SProd].[Products] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplateItems]
  ADD CONSTRAINT [FK_QuoteTemplateItems_QuoteTemplateSections] FOREIGN KEY ([QuoteTemplateSectionId]) REFERENCES [SSop].[QuoteTemplateSections] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplateItems]
  ADD CONSTRAINT [FK_QuoteTemplateItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO