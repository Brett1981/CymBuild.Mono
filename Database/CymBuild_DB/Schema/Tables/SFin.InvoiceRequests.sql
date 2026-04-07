PRINT (N'Create table [SFin].[InvoiceRequests]')
GO
PRINT (N'Create table [SFin].[InvoiceRequests]')
GO
CREATE TABLE [SFin].[InvoiceRequests] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_InvoiceRequests_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_InvoiceRequests_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Notes] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceRequests_Notes] DEFAULT (''),
  [RequesterUserId] [int] NOT NULL CONSTRAINT [DF_InvoiceRequests_RequesterUserId] DEFAULT (-1),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_InvoiceRequests_CreatedDateTimeUTC] DEFAULT (getutcdate()),
  [JobId] [int] NOT NULL CONSTRAINT [DF_InvoiceRequests_JobId] DEFAULT (-1),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [InvoicingType] [nvarchar](10) NOT NULL DEFAULT (N''),
  [ExpectedDate] [date] NULL,
  [ManualStatus] [bit] NOT NULL DEFAULT (0),
  [InvoicePaymentStatusID] [bigint] NOT NULL CONSTRAINT [DF_InvoiceRequests_InvoicePaymentStatusID] DEFAULT (-1),
  [IsAutomated] [bit] NOT NULL CONSTRAINT [DF_InvoiceRequests_IsAutomated] DEFAULT (0),
  [IsZeroValuePlaceholder] [bit] NOT NULL CONSTRAINT [DF_InvoiceRequests_IsZeroValuePlaceholder] DEFAULT (0),
  [ReconciliationRequired] [bit] NOT NULL CONSTRAINT [DF_InvoiceRequests_ReconciliationRequired] DEFAULT (0),
  [ReconciliationReason] [nvarchar](200) NOT NULL CONSTRAINT [DF_InvoiceRequests_ReconciliationReason] DEFAULT (N''),
  [SourceType] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceRequests_SourceType] DEFAULT (N''),
  [SourceGuid] [uniqueidentifier] NULL,
  [SourceIntId] [int] NULL,
  [AutomationRunGuid] [uniqueidentifier] NULL,
  [InvoiceBatchGuid] [uniqueidentifier] NULL,
  [BlockedReason] [nvarchar](200) NOT NULL CONSTRAINT [DF_InvoiceRequests_BlockedReason] DEFAULT (N''),
  [FinanceAccountGuid] [uniqueidentifier] NULL,
  [IsMerged] [bit] NOT NULL CONSTRAINT [DF_InvoiceRequests_IsMerged] DEFAULT (0),
  CONSTRAINT [PK_InvoiceRequests] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [IX_InvoiceRequests_AutomationRunGuid]
  ON [SFin].[InvoiceRequests] ([AutomationRunGuid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [AutomationRunGuid] IS NOT NULL)
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_InvoiceRequests_InvoiceBatchGuid]
  ON [SFin].[InvoiceRequests] ([InvoiceBatchGuid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [InvoiceBatchGuid] IS NOT NULL)
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_InvoiceRequests_Job]
  ON [SFin].[InvoiceRequests] ([JobId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_InvoiceRequest_Guid]
  ON [SFin].[InvoiceRequests] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [UX_InvoiceRequests_MonthConfig_Active]
  ON [SFin].[InvoiceRequests] ([JobId], [SourceGuid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [SourceType]=N'MonthConfig' AND [SourceGuid] IS NOT NULL)
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [UX_InvoiceRequests_PercentageConfig_Active]
  ON [SFin].[InvoiceRequests] ([JobId], [SourceGuid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [SourceType]=N'PercentageConfig' AND [SourceGuid] IS NOT NULL)
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [UX_InvoiceRequests_TriggerInstance_Active]
  ON [SFin].[InvoiceRequests] ([JobId], [SourceGuid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [SourceType]=N'TriggerInstance' AND [SourceGuid] IS NOT NULL)
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[InvoiceRequests]
  NOCHECK CONSTRAINT [FK_InvoiceRequests_DataObjects]
GO

ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_Identities1] FOREIGN KEY ([RequesterUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_InvoiceAutomationRuns] FOREIGN KEY ([AutomationRunGuid]) REFERENCES [SFin].[InvoiceAutomationRuns] ([Guid])
GO

ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_InvoiceBatches] FOREIGN KEY ([InvoiceBatchGuid]) REFERENCES [SFin].[InvoiceBatches] ([Guid])
GO

ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_InvoicePaymentStatus] FOREIGN KEY ([InvoicePaymentStatusID]) REFERENCES [SFin].[InvoicePaymentStatus] ([ID])
GO

ALTER TABLE [SFin].[InvoiceRequests]
  NOCHECK CONSTRAINT [FK_InvoiceRequests_InvoicePaymentStatus]
GO

ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_Jobs] FOREIGN KEY ([JobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO