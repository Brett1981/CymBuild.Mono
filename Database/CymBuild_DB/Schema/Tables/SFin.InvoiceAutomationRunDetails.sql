PRINT (N'Create table [SFin].[InvoiceAutomationRunDetails]')
GO
CREATE TABLE [SFin].[InvoiceAutomationRunDetails] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AutomationRunGuid] [uniqueidentifier] NULL,
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_InvoiceScheduleId] DEFAULT (-1),
  [SourceType] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_SourceType] DEFAULT (N''),
  [SourceGuid] [uniqueidentifier] NULL,
  [SourceIntId] [int] NULL,
  [InstanceType] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_InstanceType] DEFAULT (N''),
  [InstanceKey] [nvarchar](200) NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_InstanceKey] DEFAULT (N''),
  [Outcome] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_Outcome] DEFAULT (N''),
  [Message] [nvarchar](4000) NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_Message] DEFAULT (N''),
  [InvoiceRequestGuid] [uniqueidentifier] NULL,
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_CreatedDateTimeUTC] DEFAULT (getutcdate()),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationRunDetails_LegacySystemID] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceAutomationRunDetails] on table [SFin].[InvoiceAutomationRunDetails]')
GO
ALTER TABLE [SFin].[InvoiceAutomationRunDetails] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceAutomationRunDetails] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_InvoiceAutomationRunDetails_Run] on table [SFin].[InvoiceAutomationRunDetails]')
GO
CREATE INDEX [IX_InvoiceAutomationRunDetails_Run]
  ON [SFin].[InvoiceAutomationRunDetails] ([AutomationRunGuid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_InvoiceAutomationRunDetails_Guid] on table [SFin].[InvoiceAutomationRunDetails]')
GO
CREATE UNIQUE INDEX [IX_UQ_InvoiceAutomationRunDetails_Guid]
  ON [SFin].[InvoiceAutomationRunDetails] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_InvoiceAutomationRunDetails_DataObjects] on table [SFin].[InvoiceAutomationRunDetails]')
GO
ALTER TABLE [SFin].[InvoiceAutomationRunDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceAutomationRunDetails_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceAutomationRunDetails_DataObjects] on table [SFin].[InvoiceAutomationRunDetails]')
GO
ALTER TABLE [SFin].[InvoiceAutomationRunDetails]
  NOCHECK CONSTRAINT [FK_InvoiceAutomationRunDetails_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceAutomationRunDetails_InvoiceAutomationRuns] on table [SFin].[InvoiceAutomationRunDetails]')
GO
ALTER TABLE [SFin].[InvoiceAutomationRunDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceAutomationRunDetails_InvoiceAutomationRuns] FOREIGN KEY ([AutomationRunGuid]) REFERENCES [SFin].[InvoiceAutomationRuns] ([Guid])
GO

PRINT (N'Create foreign key [FK_InvoiceAutomationRunDetails_RowStatus] on table [SFin].[InvoiceAutomationRunDetails]')
GO
ALTER TABLE [SFin].[InvoiceAutomationRunDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceAutomationRunDetails_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO