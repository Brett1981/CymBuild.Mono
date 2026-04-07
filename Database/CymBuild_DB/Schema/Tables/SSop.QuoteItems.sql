PRINT (N'Create table [SSop].[QuoteItems]')
GO
CREATE TABLE [SSop].[QuoteItems] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteItems_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_QuoteItems_QuoteId] DEFAULT (-1),
  [QuoteSectionId] [int] NOT NULL CONSTRAINT [DF_QuoteItems_QuoteSectionId] DEFAULT (-1),
  [ProductId] [int] NOT NULL CONSTRAINT [DF_QuoteItems_ProductId] DEFAULT (-1),
  [Details] [nvarchar](2000) NOT NULL CONSTRAINT [DF_QuoteItems_Details] DEFAULT (''),
  [Net] [decimal](19, 2) NOT NULL CONSTRAINT [DF_QuoteItems_Net] DEFAULT (0),
  [VatRate] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteItems_Vat] DEFAULT (0),
  [DoNotConsolidateJob] [bit] NOT NULL CONSTRAINT [DF_QuoteItems_DoNotConsolidateJob] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_QuoteItems_SortOrder] DEFAULT (0),
  [Quantity] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteItems_Quantity] DEFAULT (0),
  [CreatedJobId] [int] NOT NULL CONSTRAINT [DF_QuoteItems_CreatedJobId] DEFAULT (-1),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL CONSTRAINT [DF__QuoteItem__Legac__116CF100] DEFAULT (-1),
  [ProvideAtStageID] [int] NOT NULL CONSTRAINT [DF_QuoteItems_ProvideAtStageID] DEFAULT (-1),
  [NumberOfSiteVisits] [int] NOT NULL CONSTRAINT [DF__QuoteItem__Numbe__3AEEF4D7] DEFAULT (0),
  [NumberOfMeetings] [int] NOT NULL CONSTRAINT [DF__QuoteItem__Numbe__3BE31910] DEFAULT (0),
  [InvoicingSchedule] [int] NOT NULL CONSTRAINT [DF_QuoteItems_InvoicingSchedule] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_QuoteItems] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [PK_QuoteItems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_QuoteItems_CreatedJobID] on table [SSop].[QuoteItems]')
GO
CREATE INDEX [IX_QuoteItems_CreatedJobID]
  ON [SSop].[QuoteItems] ([QuoteId], [CreatedJobId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_QuoteItems_CurrentQuotes] on table [SSop].[QuoteItems]')
GO
CREATE INDEX [IX_QuoteItems_CurrentQuotes]
  ON [SSop].[QuoteItems] ([QuoteId], [CreatedJobId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [CreatedJobId]<(0))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_QuoteItems_QuoteId] on table [SSop].[QuoteItems]')
GO
CREATE INDEX [IX_QuoteItems_QuoteId]
  ON [SSop].[QuoteItems] ([QuoteId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_QuoteItems_QuoteId_CreatedJobId] on table [SSop].[QuoteItems]')
GO
CREATE INDEX [IX_QuoteItems_QuoteId_CreatedJobId]
  ON [SSop].[QuoteItems] ([QuoteId], [CreatedJobId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_QuoteItems_DataObjects] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_QuoteItems_DataObjects] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems]
  NOCHECK CONSTRAINT [FK_QuoteItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_QuoteItems_InvoicingSchedule] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_InvoicingSchedule] FOREIGN KEY ([InvoicingSchedule]) REFERENCES [SFin].[InvoiceSchedules] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteItems_Jobs] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_Jobs] FOREIGN KEY ([CreatedJobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteItems_Products] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_Products] FOREIGN KEY ([ProductId]) REFERENCES [SProd].[Products] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteItems_QuoteSections] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_QuoteSections] FOREIGN KEY ([QuoteSectionId]) REFERENCES [SSop].[QuoteSections] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_QuoteItems_RibaStages] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_RibaStages] FOREIGN KEY ([ProvideAtStageID]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteItems_RowStatus] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO