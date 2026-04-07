PRINT (N'Create table [SFin].[InvoicePaymentStatus]')
GO
CREATE TABLE [SFin].[InvoicePaymentStatus] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_InvoicePaymentStatus_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_InvoicePaymentStatus_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DEFAULT_InvoicePaymentStatus_Name] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoicePaymentStatus_ID] on table [SFin].[InvoicePaymentStatus]')
GO
ALTER TABLE [SFin].[InvoicePaymentStatus] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoicePaymentStatus_ID] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_InvoicePaymentStatus_DataObjects] on table [SFin].[InvoicePaymentStatus]')
GO
ALTER TABLE [SFin].[InvoicePaymentStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoicePaymentStatus_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoicePaymentStatus_DataObjects] on table [SFin].[InvoicePaymentStatus]')
GO
ALTER TABLE [SFin].[InvoicePaymentStatus]
  NOCHECK CONSTRAINT [FK_InvoicePaymentStatus_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoicePaymentStatus_RowStatus] on table [SFin].[InvoicePaymentStatus]')
GO
ALTER TABLE [SFin].[InvoicePaymentStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoicePaymentStatus_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO