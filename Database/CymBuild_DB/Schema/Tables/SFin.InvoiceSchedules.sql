PRINT (N'Create table [SFin].[InvoiceSchedules]')
GO
CREATE TABLE [SFin].[InvoiceSchedules] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceSchedules_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_InvoiceSchedules_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceSchedules_Name] DEFAULT (''),
  [DescriptionOfWork] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceSchedule_DescriptionOfWork] DEFAULT (''),
  [Amount] [decimal](19, 2) NOT NULL CONSTRAINT [DF_InvoiceSchedule_Amount] DEFAULT (0),
  [TriggerId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedules_TriggerId] DEFAULT (-1),
  [ExpectedDate] [date] NULL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedules_QuoteId] DEFAULT (-1),
  [RibaConfigurationId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedules_RibaConfigurationId] DEFAULT (-1),
  [ActivityMilestoneConfigurationId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedules_ActivityMilestoneConfigurationId] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceSchedules] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceSchedules] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_ActivityMilestoneConfigurationId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_ActivityMilestoneConfigurationId] FOREIGN KEY ([ActivityMilestoneConfigurationId]) REFERENCES [SFin].[InvoiceScheduleActivityMilestoneConfiguration] ([ID])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedules_ActivityMilestoneConfigurationId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_ActivityMilestoneConfigurationId]
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_DataObjects] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedules_DataObjects] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_QuoteId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_QuoteId] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_RibaConfigurationId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_RibaConfigurationId] FOREIGN KEY ([RibaConfigurationId]) REFERENCES [SFin].[InvoiceScheduleRibaConfiguration] ([ID])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedules_RibaConfigurationId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_RibaConfigurationId]
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_RowStatus] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_TriggerId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_TriggerId] FOREIGN KEY ([TriggerId]) REFERENCES [SFin].[InvoiceScheduleTrigger] ([ID])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedules_TriggerId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_TriggerId]
GO