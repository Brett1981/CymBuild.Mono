PRINT (N'Create table [SUserInterface].[WidgetDashboards]')
GO
PRINT (N'Create table [SUserInterface].[WidgetDashboards]')
GO
CREATE TABLE [SUserInterface].[WidgetDashboards] (
  [Id] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_WidgetDashboards_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowVersion] [timestamp],
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_WidgetDashboards_RowStatus] DEFAULT (0),
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_WidgetDashboards_Name] DEFAULT (''),
  [ParentEntityTypeId] [int] NOT NULL CONSTRAINT [DF_WidgetDashboards_ParentEntityTypeId] DEFAULT (-1)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_WidgetDashboards] on table [SUserInterface].[WidgetDashboards]')
GO
ALTER TABLE [SUserInterface].[WidgetDashboards] WITH NOCHECK
  ADD CONSTRAINT [PK_WidgetDashboards] PRIMARY KEY CLUSTERED ([Id]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_WidgetDashboards_Guid] on table [SUserInterface].[WidgetDashboards]')
GO
CREATE UNIQUE INDEX [IX_UQ_WidgetDashboards_Guid]
  ON [SUserInterface].[WidgetDashboards] ([Guid])
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_WidgetDashboards_Name] on table [SUserInterface].[WidgetDashboards]')
GO
CREATE UNIQUE INDEX [IX_UQ_WidgetDashboards_Name]
  ON [SUserInterface].[WidgetDashboards] ([Name])
  ON [METADATA]
GO

PRINT (N'Create foreign key [FK_WidgetDashboards_EntityTypes] on table [SUserInterface].[WidgetDashboards]')
GO
ALTER TABLE [SUserInterface].[WidgetDashboards] WITH NOCHECK
  ADD CONSTRAINT [FK_WidgetDashboards_EntityTypes] FOREIGN KEY ([ParentEntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO