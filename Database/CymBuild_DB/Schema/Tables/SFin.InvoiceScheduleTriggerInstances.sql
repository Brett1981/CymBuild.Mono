PRINT (N'Create table [SFin].[InvoiceScheduleTriggerInstances]')
GO
CREATE TABLE [SFin].[InvoiceScheduleTriggerInstances] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceScheduleTriggerInstances_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceScheduleTriggerInstances_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_InvoiceScheduleTriggerInstances_InvoiceScheduleId] DEFAULT (-1),
  [InstanceType] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceScheduleTriggerInstances_InstanceType] DEFAULT (N''),
  [InstanceKey] [nvarchar](200) NOT NULL CONSTRAINT [DF_InvoiceScheduleTriggerInstances_InstanceKey] DEFAULT (N''),
  [DetectedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_InvoiceScheduleTriggerInstances_DetectedDateTimeUTC] DEFAULT (getutcdate()),
  [CompletedDateTimeUTC] [datetime2] NULL,
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL CONSTRAINT [DF_InvoiceScheduleTriggerInstances_LegacySystemID] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceScheduleTriggerInstances] on table [SFin].[InvoiceScheduleTriggerInstances]')
GO
ALTER TABLE [SFin].[InvoiceScheduleTriggerInstances] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceScheduleTriggerInstances] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_UQ_InvoiceScheduleTriggerInstances_Guid] on table [SFin].[InvoiceScheduleTriggerInstances]')
GO
CREATE UNIQUE INDEX [IX_UQ_InvoiceScheduleTriggerInstances_Guid]
  ON [SFin].[InvoiceScheduleTriggerInstances] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_InvoiceScheduleTriggerInstances_Schedule_Type_Key_Active] on table [SFin].[InvoiceScheduleTriggerInstances]')
GO
CREATE UNIQUE INDEX [UX_InvoiceScheduleTriggerInstances_Schedule_Type_Key_Active]
  ON [SFin].[InvoiceScheduleTriggerInstances] ([InvoiceScheduleId], [InstanceType], [InstanceKey])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleTriggerInstances_DataObjects] on table [SFin].[InvoiceScheduleTriggerInstances]')
GO
ALTER TABLE [SFin].[InvoiceScheduleTriggerInstances] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleTriggerInstances_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceScheduleTriggerInstances_DataObjects] on table [SFin].[InvoiceScheduleTriggerInstances]')
GO
ALTER TABLE [SFin].[InvoiceScheduleTriggerInstances]
  NOCHECK CONSTRAINT [FK_InvoiceScheduleTriggerInstances_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleTriggerInstances_RowStatus] on table [SFin].[InvoiceScheduleTriggerInstances]')
GO
ALTER TABLE [SFin].[InvoiceScheduleTriggerInstances] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleTriggerInstances_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO