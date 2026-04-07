CREATE TABLE [SOffice].[Preferences] (
  [ID] [int] NOT NULL,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Preferences_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MailerSettings_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [OutlookMailboxID] [int] NOT NULL CONSTRAINT [DF_Preferences_OutlookMailboxID] DEFAULT (-1),
  [AutoFileMinutes] [int] NOT NULL CONSTRAINT [DF_MailerSettings_AutoFileMinutes] DEFAULT (0),
  [IsAutoFilingEnabled] [bit] NOT NULL CONSTRAINT [DF_MailerSettings_AutoFile] DEFAULT (0),
  [MoveFiledToFiledItems] [bit] NOT NULL CONSTRAINT [DF_MailerSettings_MoveToFiledItems] DEFAULT (0),
  [SharedMailboxesToCheck] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Preferences_SharedMailboxesToCheck] DEFAULT (''),
  CONSTRAINT [PK_Preferences] PRIMARY KEY CLUSTERED ([ID]),
  CONSTRAINT [UQ__Preferences_Guid] UNIQUE ([Guid])
)
ON [PRIMARY]
GO

ALTER TABLE [SOffice].[Preferences]
  ADD CONSTRAINT [FK_Preferences_OutlookEmailMailboxes] FOREIGN KEY ([ID]) REFERENCES [SOffice].[OutlookEmailMailboxes] ([ID])
GO