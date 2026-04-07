PRINT (N'Create table [SFin].[InvoiceScheduleTrigger]')
GO
CREATE TABLE [SFin].[InvoiceScheduleTrigger] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceScheduleTrigger_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceScheduleTrigger_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_InvoiceScheduleTrigger_Name] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceScheduleTrigger] on table [SFin].[InvoiceScheduleTrigger]')
GO
ALTER TABLE [SFin].[InvoiceScheduleTrigger] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceScheduleTrigger] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleTrigger_DataObjects] on table [SFin].[InvoiceScheduleTrigger]')
GO
ALTER TABLE [SFin].[InvoiceScheduleTrigger] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleTrigger_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceScheduleTrigger_DataObjects] on table [SFin].[InvoiceScheduleTrigger]')
GO
ALTER TABLE [SFin].[InvoiceScheduleTrigger]
  NOCHECK CONSTRAINT [FK_InvoiceScheduleTrigger_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleTrigger_RowStatus] on table [SFin].[InvoiceScheduleTrigger]')
GO
ALTER TABLE [SFin].[InvoiceScheduleTrigger] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleTrigger_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO