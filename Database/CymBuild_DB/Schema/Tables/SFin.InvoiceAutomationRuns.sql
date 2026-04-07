PRINT (N'Create table [SFin].[InvoiceAutomationRuns]')
GO
PRINT (N'Create table [SFin].[InvoiceAutomationRuns]')
GO
CREATE TABLE [SFin].[InvoiceAutomationRuns] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [StartedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_StartedDateTimeUTC] DEFAULT (getutcdate()),
  [CompletedDateTimeUTC] [datetime2] NULL,
  [EnvironmentName] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_EnvironmentName] DEFAULT (N''),
  [TriggeredByUserId] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_TriggeredByUserId] DEFAULT (-1),
  [CreatedCount] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_CreatedCount] DEFAULT (0),
  [SkippedCount] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_SkippedCount] DEFAULT (0),
  [BlockedCount] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_BlockedCount] DEFAULT (0),
  [ReconciledCount] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_ReconciledCount] DEFAULT (0),
  [ErrorCount] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_ErrorCount] DEFAULT (0),
  [InvoiceBatchGuid] [uniqueidentifier] NULL,
  [Notes] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_Notes] DEFAULT (N''),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_LegacySystemID] DEFAULT (-1),
  [WasBatchCreated] [bit] NOT NULL CONSTRAINT [DF_InvoiceAutomationRuns_WasBatchCreated] DEFAULT (0)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceAutomationRuns] on table [SFin].[InvoiceAutomationRuns]')
GO
ALTER TABLE [SFin].[InvoiceAutomationRuns] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceAutomationRuns] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_UQ_InvoiceAutomationRuns_Guid] on table [SFin].[InvoiceAutomationRuns]')
GO
CREATE UNIQUE INDEX [IX_UQ_InvoiceAutomationRuns_Guid]
  ON [SFin].[InvoiceAutomationRuns] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_InvoiceAutomationRuns_DataObjects] on table [SFin].[InvoiceAutomationRuns]')
GO
ALTER TABLE [SFin].[InvoiceAutomationRuns] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceAutomationRuns_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceAutomationRuns_DataObjects] on table [SFin].[InvoiceAutomationRuns]')
GO
ALTER TABLE [SFin].[InvoiceAutomationRuns]
  NOCHECK CONSTRAINT [FK_InvoiceAutomationRuns_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceAutomationRuns_RowStatus] on table [SFin].[InvoiceAutomationRuns]')
GO
ALTER TABLE [SFin].[InvoiceAutomationRuns] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceAutomationRuns_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO