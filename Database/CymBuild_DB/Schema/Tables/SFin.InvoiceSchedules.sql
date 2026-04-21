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
  [ActivityMilestoneConfigurationId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedules_ActivityMilestoneConfigurationId] DEFAULT (-1),
  [ScheduleReenabled] [bit] NOT NULL CONSTRAINT [DF_InvoiceSchedules_ScheduleReenabled] DEFAULT (0),
  CONSTRAINT [PK_InvoiceSchedules] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_ActivityMilestoneConfigurationId] FOREIGN KEY ([ActivityMilestoneConfigurationId]) REFERENCES [SFin].[InvoiceScheduleActivityMilestoneConfiguration] ([ID])
GO

ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_ActivityMilestoneConfigurationId]
GO

ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_DataObjects]
GO

ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_QuoteId] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID])
GO

ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_RibaConfigurationId] FOREIGN KEY ([RibaConfigurationId]) REFERENCES [SFin].[InvoiceScheduleRibaConfiguration] ([ID])
GO

ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_RibaConfigurationId]
GO

ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_TriggerId] FOREIGN KEY ([TriggerId]) REFERENCES [SFin].[InvoiceScheduleTrigger] ([ID])
GO

ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_TriggerId]
GO