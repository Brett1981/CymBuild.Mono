PRINT (N'Create table [SUserInterface].[MainMenuItems]')
GO
CREATE TABLE [SUserInterface].[MainMenuItems] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MainMenuItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_MainMenuItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [LanguageLabelId] [int] NOT NULL CONSTRAINT [DF__MainMenuI__Langu__37F1C144] DEFAULT (-1),
  [IconId] [int] NOT NULL CONSTRAINT [DF_MainMenuItems_IconId] DEFAULT (-1),
  [NavigationUrl] [nvarchar](500) NOT NULL CONSTRAINT [DF_MainMenuItems_NavigationUrl] DEFAULT (''),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_MainMenuItems_SortOrder] DEFAULT (0)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_MainMenuItems] on table [SUserInterface].[MainMenuItems]')
GO
ALTER TABLE [SUserInterface].[MainMenuItems] WITH NOCHECK
  ADD CONSTRAINT [PK_MainMenuItems] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create foreign key [FK_MainMenuItems_DataObjects] on table [SUserInterface].[MainMenuItems]')
GO
ALTER TABLE [SUserInterface].[MainMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_MainMenuItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_MainMenuItems_DataObjects] on table [SUserInterface].[MainMenuItems]')
GO
ALTER TABLE [SUserInterface].[MainMenuItems]
  NOCHECK CONSTRAINT [FK_MainMenuItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_MainMenuItems_Icons] on table [SUserInterface].[MainMenuItems]')
GO
ALTER TABLE [SUserInterface].[MainMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_MainMenuItems_Icons] FOREIGN KEY ([IconId]) REFERENCES [SUserInterface].[Icons] ([ID])
GO

PRINT (N'Create foreign key [FK_MainMenuItems_LanguageLabelId] on table [SUserInterface].[MainMenuItems]')
GO
ALTER TABLE [SUserInterface].[MainMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_MainMenuItems_LanguageLabelId] FOREIGN KEY ([LanguageLabelId]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_MainMenuItems_RowStatus] on table [SUserInterface].[MainMenuItems]')
GO
ALTER TABLE [SUserInterface].[MainMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_MainMenuItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO