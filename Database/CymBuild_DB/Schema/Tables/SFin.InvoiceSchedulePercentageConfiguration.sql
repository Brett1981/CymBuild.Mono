PRINT (N'Create table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
CREATE TABLE [SFin].[InvoiceSchedulePercentageConfiguration] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_InvoiceScheduleId] DEFAULT (-1),
  [PeriodNumber] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_PeriodNumber] DEFAULT (1),
  [Percentage] [decimal](19, 2) NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_Percentage] DEFAULT (0.0),
  [OnDayOfMonth] [date] NULL,
  [Description] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_Description] DEFAULT ('')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceSchedulePercentageConfiguration] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceSchedulePercentageConfiguration] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create foreign key [FK_InvoiceSchedulePercentageConfiguration_DataObjects] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedulePercentageConfiguration_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedulePercentageConfiguration_DataObjects] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration]
  NOCHECK CONSTRAINT [FK_InvoiceSchedulePercentageConfiguration_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceSchedulePercentageConfiguration_InvoiceScheduleId] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedulePercentageConfiguration_InvoiceScheduleId] FOREIGN KEY ([InvoiceScheduleId]) REFERENCES [SFin].[InvoiceSchedules] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceSchedulePercentageConfiguration_RowStatus] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedulePercentageConfiguration_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO