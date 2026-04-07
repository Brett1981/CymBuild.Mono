PRINT (N'Create table [SSop].[InvoiceSchedules]')
GO
CREATE TABLE [SSop].[InvoiceSchedules] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceSchedules_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_InvoiceSchedules_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceSchedules_Name] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceSchedules] on table [SSop].[InvoiceSchedules]')
GO
ALTER TABLE [SSop].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceSchedules] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create unique key [UQ__InvoiceSchedules_Guid] on table [SSop].[InvoiceSchedules]')
GO
ALTER TABLE [SSop].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [UQ__InvoiceSchedules_Guid] UNIQUE ([Guid])
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_DataObjects] on table [SSop].[InvoiceSchedules]')
GO
ALTER TABLE [SSop].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedules_DataObjects] on table [SSop].[InvoiceSchedules]')
GO
ALTER TABLE [SSop].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_RowStatus] on table [SSop].[InvoiceSchedules]')
GO
ALTER TABLE [SSop].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO