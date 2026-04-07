CREATE TABLE [SOffice].[OutlookCalendarEvents] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [TargetObjectID] [bigint] NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_RecordID] DEFAULT (-1),
  [OutlookEmailMailboxID] [int] NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_Mailbox] DEFAULT (-1),
  [ExchangeImmutableID] [nvarchar](250) NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_ExchangeImmutableID] DEFAULT (''),
  [Title] [nvarchar](2000) NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_Title] DEFAULT (''),
  [StartDateTime] [datetime2] NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_StartDateTime] DEFAULT (getutcdate()),
  [EndDateTime] [datetime2] NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_EndDateTime] DEFAULT (getutcdate()),
  [IsAllDay] [bit] NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_IsAllDay] DEFAULT (0),
  [Recurrence] [nvarchar](max) NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_Recurance] DEFAULT (''),
  [LastUpdateSource] [nvarchar](1) NOT NULL CONSTRAINT [DF_OutlookCalendarEvents_LastUpdateSource] DEFAULT (''),
  CONSTRAINT [PK_OutlookCalendarEvents] PRIMARY KEY CLUSTERED ([ID]),
  CONSTRAINT [CK_OutlookCalendarEvents_LastUpdateSource] CHECK ([LastUpdateSource]=N'E' OR [LastUpdateSource]=N'B' OR [LastUpdateSource]=N'')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [SOffice].[OutlookCalendarEvents]
  ADD CONSTRAINT [FK_OutlookCalendarEvents_OutlookCalendarEvents] FOREIGN KEY ([OutlookEmailMailboxID]) REFERENCES [SOffice].[OutlookEmailMailboxes] ([ID])
GO

ALTER TABLE [SOffice].[OutlookCalendarEvents]
  ADD CONSTRAINT [FK_OutlookCalendarEvents_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SOffice].[OutlookCalendarEvents]
  ADD CONSTRAINT [FK_OutlookCalendarEvents_TargetObjects] FOREIGN KEY ([TargetObjectID]) REFERENCES [SOffice].[TargetObjects] ([ID])
GO