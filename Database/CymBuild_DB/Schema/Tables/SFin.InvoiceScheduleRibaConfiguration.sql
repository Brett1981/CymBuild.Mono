PRINT (N'Create table [SFin].[InvoiceScheduleRibaConfiguration]')
GO
CREATE TABLE [SFin].[InvoiceScheduleRibaConfiguration] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceScheduleRibaConfiguration_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceScheduleRibaConfiguration_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RibaOnCompletion] [bit] NOT NULL CONSTRAINT [DF_InvoiceScheduleRibaConfiguration_RibaOnCompletion] DEFAULT (0),
  [RibaOnPartCompletion] [bit] NOT NULL CONSTRAINT [DF_InvoiceScheduleRibaConfiguration_RibaOnPartCompletion] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceScheduleRibaConfiguration] on table [SFin].[InvoiceScheduleRibaConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleRibaConfiguration] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceScheduleRibaConfiguration] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleRibaConfiguration_DataObjects] on table [SFin].[InvoiceScheduleRibaConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleRibaConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleRibaConfiguration_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceScheduleRibaConfiguration_DataObjects] on table [SFin].[InvoiceScheduleRibaConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleRibaConfiguration]
  NOCHECK CONSTRAINT [FK_InvoiceScheduleRibaConfiguration_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleRibaConfiguration_RowStatus] on table [SFin].[InvoiceScheduleRibaConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleRibaConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleRibaConfiguration_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO