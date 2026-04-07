PRINT (N'Create table [SCore].[LanguageLabelTranslations]')
GO
CREATE TABLE [SCore].[LanguageLabelTranslations] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Text] [nvarchar](250) NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_Text] DEFAULT (''),
  [TextPlural] [nvarchar](250) NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_TextPlural] DEFAULT (''),
  [LanguageLabelID] [int] NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_LanguageLabelID] DEFAULT (-1),
  [LanguageID] [int] NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_LanguageID] DEFAULT (-1),
  [HelpText] [nvarchar](max) NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_HelpText] DEFAULT ('')
)
ON [METADATA]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_LanguageLabelTranslations] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [PK_LanguageLabelTranslations] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create foreign key [FK_LanguageLabelTranslations_DataObjects] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabelTranslations_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_LanguageLabelTranslations_DataObjects] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations]
  NOCHECK CONSTRAINT [FK_LanguageLabelTranslations_DataObjects]
GO

PRINT (N'Create foreign key [FK_LanguageLabelTranslations_LanguageLabels] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabelTranslations_LanguageLabels] FOREIGN KEY ([LanguageLabelID]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_LanguageLabelTranslations_Languages] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabelTranslations_Languages] FOREIGN KEY ([LanguageID]) REFERENCES [SCore].[Languages] ([ID])
GO

PRINT (N'Create foreign key [FK_LanguageLabelTranslations_RowStatus] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabelTranslations_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[LanguageLabelTranslations]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Language translations for the Language Labels', 'SCHEMA', N'SCore', 'TABLE', N'LanguageLabelTranslations'
GO