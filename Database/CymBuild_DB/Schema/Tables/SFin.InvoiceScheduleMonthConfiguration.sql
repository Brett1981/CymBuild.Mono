PRINT (N'Create table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
CREATE TABLE [SFin].[InvoiceScheduleMonthConfiguration] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_InvoiceScheduleId] DEFAULT (-1),
  [PeriodNumber] [int] NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_PeriodNumber] DEFAULT (0),
  [Amount] [decimal](19, 2) NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_Amount] DEFAULT (0.0),
  [OnDayOfMonth] [date] NULL,
  [Description] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_Description] DEFAULT ('')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceScheduleMonthConfiguration] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceScheduleMonthConfiguration] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleMonthConfiguration_DataObjects] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleMonthConfiguration_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceScheduleMonthConfiguration_DataObjects] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration]
  NOCHECK CONSTRAINT [FK_InvoiceScheduleMonthConfiguration_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleMonthConfiguration_InvoiceScheduleId] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleMonthConfiguration_InvoiceScheduleId] FOREIGN KEY ([InvoiceScheduleId]) REFERENCES [SFin].[InvoiceSchedules] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleMonthConfiguration_RowStatus] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleMonthConfiguration_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO