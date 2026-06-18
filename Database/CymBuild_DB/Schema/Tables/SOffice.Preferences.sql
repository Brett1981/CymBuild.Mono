PRINT (N'Create table [SOffice].[Preferences]')
GO
CREATE TABLE [SOffice].[Preferences] (
  [ID] [int] NOT NULL,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Preferences_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MailerSettings_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [OutlookMailboxID] [int] NOT NULL CONSTRAINT [DF_Preferences_OutlookMailboxID] DEFAULT (-1),
  [AutoFileMinutes] [int] NOT NULL CONSTRAINT [DF_MailerSettings_AutoFileMinutes] DEFAULT (0),
  [IsAutoFilingEnabled] [bit] NOT NULL CONSTRAINT [DF_MailerSettings_AutoFile] DEFAULT (0),
  [MoveFiledToFiledItems] [bit] NOT NULL CONSTRAINT [DF_MailerSettings_MoveToFiledItems] DEFAULT (0),
  [SharedMailboxesToCheck] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Preferences_SharedMailboxesToCheck] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Preferences] on table [SOffice].[Preferences]')
GO
ALTER TABLE [SOffice].[Preferences] WITH NOCHECK
  ADD CONSTRAINT [PK_Preferences] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create unique key [UQ__Preferences_Guid] on table [SOffice].[Preferences]')
GO
ALTER TABLE [SOffice].[Preferences] WITH NOCHECK
  ADD CONSTRAINT [UQ__Preferences_Guid] UNIQUE ([Guid])
GO

PRINT (N'Create foreign key [FK_Preferences_OutlookEmailMailboxes] on table [SOffice].[Preferences]')
GO
ALTER TABLE [SOffice].[Preferences] WITH NOCHECK
  ADD CONSTRAINT [FK_Preferences_OutlookEmailMailboxes] FOREIGN KEY ([ID]) REFERENCES [SOffice].[OutlookEmailMailboxes] ([ID])
GO