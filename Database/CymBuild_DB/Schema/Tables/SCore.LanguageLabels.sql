PRINT (N'Create table [SCore].[LanguageLabels]')
GO
CREATE TABLE [SCore].[LanguageLabels] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_LanguageLabels_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_LanguageLabels_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_LanguageLabels_Name] DEFAULT ('')
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_LanguageLabels] on table [SCore].[LanguageLabels]')
GO
ALTER TABLE [SCore].[LanguageLabels] WITH NOCHECK
  ADD CONSTRAINT [PK_LanguageLabels] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create foreign key [FK_LanguageLabels_RowStatus] on table [SCore].[LanguageLabels]')
GO
ALTER TABLE [SCore].[LanguageLabels] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabels_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[LanguageLabels]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Labels to put against properties in the UI.', 'SCHEMA', N'SCore', 'TABLE', N'LanguageLabels'
GO