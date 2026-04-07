CREATE TABLE [SUserInterface].[MainMenuItems] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MainMenuItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_MainMenuItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [LanguageLabelId] [int] NOT NULL CONSTRAINT [DF__MainMenuI__Langu__37F1C144] DEFAULT (-1),
  [IconId] [int] NOT NULL CONSTRAINT [DF_MainMenuItems_IconId] DEFAULT (-1),
  [NavigationUrl] [nvarchar](500) NOT NULL CONSTRAINT [DF_MainMenuItems_NavigationUrl] DEFAULT (''),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_MainMenuItems_SortOrder] DEFAULT (0),
  CONSTRAINT [PK_MainMenuItems] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

ALTER TABLE [SUserInterface].[MainMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_MainMenuItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SUserInterface].[MainMenuItems]
  NOCHECK CONSTRAINT [FK_MainMenuItems_DataObjects]
GO

ALTER TABLE [SUserInterface].[MainMenuItems]
  ADD CONSTRAINT [FK_MainMenuItems_Icons] FOREIGN KEY ([IconId]) REFERENCES [SUserInterface].[Icons] ([ID])
GO

ALTER TABLE [SUserInterface].[MainMenuItems]
  ADD CONSTRAINT [FK_MainMenuItems_LanguageLabelId] FOREIGN KEY ([LanguageLabelId]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

ALTER TABLE [SUserInterface].[MainMenuItems]
  ADD CONSTRAINT [FK_MainMenuItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO