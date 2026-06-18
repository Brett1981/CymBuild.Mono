PRINT (N'Create table [SUserInterface].[WidgetTypes]')
GO
CREATE TABLE [SUserInterface].[WidgetTypes] (
  [Id] [smallint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_WidgetTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowVersion] [timestamp],
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_WidgetTypes_RowStatus] DEFAULT (0),
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_WidgetTypes_Name] DEFAULT ('')
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_WidgetTypes] on table [SUserInterface].[WidgetTypes]')
GO
ALTER TABLE [SUserInterface].[WidgetTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_WidgetTypes] PRIMARY KEY CLUSTERED ([Id]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_WidgetTypes_Guid] on table [SUserInterface].[WidgetTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_WidgetTypes_Guid]
  ON [SUserInterface].[WidgetTypes] ([Guid])
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_WidgetTypes_Name] on table [SUserInterface].[WidgetTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_WidgetTypes_Name]
  ON [SUserInterface].[WidgetTypes] ([Name])
  ON [METADATA]
GO