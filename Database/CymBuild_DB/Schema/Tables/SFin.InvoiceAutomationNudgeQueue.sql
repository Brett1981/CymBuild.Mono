PRINT (N'Create table [SFin].[InvoiceAutomationNudgeQueue]')
GO
CREATE TABLE [SFin].[InvoiceAutomationNudgeQueue] (
  [ID] [int] IDENTITY,
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_InvoiceAutomationNudgeQueue_Created] DEFAULT (sysutcdatetime()),
  [Source] [nvarchar](50) NOT NULL,
  [EntityGuid] [uniqueidentifier] NULL,
  [EntityId] [int] NULL,
  [ProcessedDateTimeUTC] [datetime2] NULL,
  [ProcessAttempt] [int] NOT NULL CONSTRAINT [DF_InvoiceAutomationNudgeQueue_Attempt] DEFAULT (0),
  [LastError] [nvarchar](4000) NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceAutomationNudgeQueue] on table [SFin].[InvoiceAutomationNudgeQueue]')
GO
ALTER TABLE [SFin].[InvoiceAutomationNudgeQueue] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceAutomationNudgeQueue] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_InvoiceAutomationNudgeQueue_Unprocessed] on table [SFin].[InvoiceAutomationNudgeQueue]')
GO
CREATE INDEX [IX_InvoiceAutomationNudgeQueue_Unprocessed]
  ON [SFin].[InvoiceAutomationNudgeQueue] ([ProcessedDateTimeUTC], [CreatedDateTimeUTC])
  INCLUDE ([Source], [EntityId], [EntityGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO