CREATE TABLE [SCore].[UserPreferences] (
  [ID] [int] NOT NULL,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_UserPreferences_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MailerSettings_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [SystemLanguageID] [int] NOT NULL CONSTRAINT [DF_UserPreferences_SystemLanguageId] DEFAULT (-1),
  [WidgetLayout] [nvarchar](max) NOT NULL CONSTRAINT [DF_UserPreferences_WidgetLayout] DEFAULT ('{"ItemStates": []}'),
  CONSTRAINT [PK_UserPreferences] PRIMARY KEY CLUSTERED ([ID]),
  CONSTRAINT [UQ__UserPreferences_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 90)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [SCore].[UserPreferences]
  ADD CONSTRAINT [FK_UserPreferences_Identities] FOREIGN KEY ([ID]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SCore].[UserPreferences]
  ADD CONSTRAINT [FK_UserPreferences_Languages] FOREIGN KEY ([SystemLanguageID]) REFERENCES [SCore].[Languages] ([ID])
GO

ALTER TABLE [SCore].[UserPreferences]
  ADD CONSTRAINT [FK_UserPreferences_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'User settable preferences, e.g. their default system language. ', 'SCHEMA', N'SCore', 'TABLE', N'UserPreferences'
GO