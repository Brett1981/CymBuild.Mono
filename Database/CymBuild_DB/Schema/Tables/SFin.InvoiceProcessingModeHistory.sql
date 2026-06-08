PRINT (N'Create table [SFin].[InvoiceProcessingModeHistory]')
GO
CREATE TABLE [SFin].[InvoiceProcessingModeHistory] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_IPMH_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_IPMH_Guid] DEFAULT (newid()),
  [JobId] [int] NOT NULL CONSTRAINT [DF_InvoiceProcessingModeHistory_JobId] DEFAULT (-1),
  [JobGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceProcessingModeHistory_JobGuid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [OldMode] [tinyint] NULL,
  [NewMode] [tinyint] NULL,
  [ChangedDateTimeUTC] [datetime2] NULL CONSTRAINT [DF_IPMH_ChangedUTC] DEFAULT (sysutcdatetime()),
  [ChangedByUserId] [int] NOT NULL CONSTRAINT [DF_IPMH_ChangedByUserId] DEFAULT (-1),
  [ChangedByUserGuid] [uniqueidentifier] NULL,
  [Reason] [nvarchar](500) NOT NULL CONSTRAINT [DF_IPMH_Reason] DEFAULT (N''),
  [Source] [nvarchar](50) NOT NULL CONSTRAINT [DF_IPMH_Source] DEFAULT (N'UI')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_IPMH] on table [SFin].[InvoiceProcessingModeHistory]')
GO
ALTER TABLE [SFin].[InvoiceProcessingModeHistory] WITH NOCHECK
  ADD CONSTRAINT [PK_IPMH] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_IPMH_Jobs] on table [SFin].[InvoiceProcessingModeHistory]')
GO
ALTER TABLE [SFin].[InvoiceProcessingModeHistory] WITH NOCHECK
  ADD CONSTRAINT [FK_IPMH_Jobs] FOREIGN KEY ([JobId]) REFERENCES [SJob].[Jobs] ([ID])
GO