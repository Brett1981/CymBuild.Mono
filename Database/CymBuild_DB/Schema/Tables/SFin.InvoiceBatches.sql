PRINT (N'Create table [SFin].[InvoiceBatches]')
GO
CREATE TABLE [SFin].[InvoiceBatches] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceBatches_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceBatches_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_InvoiceBatches_CreatedDateTimeUTC] DEFAULT (getutcdate()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_InvoiceBatches_CreatedByUserId] DEFAULT (-1),
  [AutomationRunGuid] [uniqueidentifier] NULL,
  [CreatedCount] [int] NOT NULL CONSTRAINT [DF_InvoiceBatches_CreatedCount] DEFAULT (0),
  [Notes] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceBatches_Notes] DEFAULT (N''),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL CONSTRAINT [DF_InvoiceBatches_LegacySystemID] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceBatches] on table [SFin].[InvoiceBatches]')
GO
ALTER TABLE [SFin].[InvoiceBatches] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceBatches] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_InvoiceBatches_AutomationRunGuid] on table [SFin].[InvoiceBatches]')
GO
CREATE INDEX [IX_InvoiceBatches_AutomationRunGuid]
  ON [SFin].[InvoiceBatches] ([AutomationRunGuid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_InvoiceBatches_Guid] on table [SFin].[InvoiceBatches]')
GO
CREATE UNIQUE INDEX [IX_UQ_InvoiceBatches_Guid]
  ON [SFin].[InvoiceBatches] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_InvoiceBatches_DataObjects] on table [SFin].[InvoiceBatches]')
GO
ALTER TABLE [SFin].[InvoiceBatches] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceBatches_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceBatches_DataObjects] on table [SFin].[InvoiceBatches]')
GO
ALTER TABLE [SFin].[InvoiceBatches]
  NOCHECK CONSTRAINT [FK_InvoiceBatches_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceBatches_InvoiceAutomationRuns] on table [SFin].[InvoiceBatches]')
GO
ALTER TABLE [SFin].[InvoiceBatches] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceBatches_InvoiceAutomationRuns] FOREIGN KEY ([AutomationRunGuid]) REFERENCES [SFin].[InvoiceAutomationRuns] ([Guid])
GO

PRINT (N'Create foreign key [FK_InvoiceBatches_RowStatus] on table [SFin].[InvoiceBatches]')
GO
ALTER TABLE [SFin].[InvoiceBatches] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceBatches_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO