PRINT (N'Create table [SFin].[InvoiceScheduleActivityMilestoneConfiguration]')
GO
CREATE TABLE [SFin].[InvoiceScheduleActivityMilestoneConfiguration] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceScheduleActivityMilestoneConfiguration_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceScheduleActivityMilestoneConfiguration_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [OnMilestoneCompletion] [bit] NOT NULL CONSTRAINT [DF_InvoiceScheduleActivityMilestoneConfiguration_OnMilestoneCompletion] DEFAULT (0),
  [OnActivityCompletion] [bit] NOT NULL CONSTRAINT [DF_InvoiceScheduleActivityMilestoneConfiguration_OnActivityCompletion] DEFAULT (0),
  [OnActivityAndMilestonCompletion] [bit] NOT NULL CONSTRAINT [DF_InvoiceScheduleActivityMilestoneConfiguration_OnActivityAndMilestoneCompletion] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceScheduleActivityMilestoneConfiguration] on table [SFin].[InvoiceScheduleActivityMilestoneConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleActivityMilestoneConfiguration] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceScheduleActivityMilestoneConfiguration] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleMonthlyConfiguration_DataObjects] on table [SFin].[InvoiceScheduleActivityMilestoneConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleActivityMilestoneConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleMonthlyConfiguration_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceScheduleMonthlyConfiguration_DataObjects] on table [SFin].[InvoiceScheduleActivityMilestoneConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleActivityMilestoneConfiguration]
  NOCHECK CONSTRAINT [FK_InvoiceScheduleMonthlyConfiguration_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleMonthlyConfiguration_RowStatus] on table [SFin].[InvoiceScheduleActivityMilestoneConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleActivityMilestoneConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleMonthlyConfiguration_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO