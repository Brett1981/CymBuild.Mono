PRINT (N'Create table [SUserInterface].[WidgetDashboardWidgetTypes]')
GO
CREATE TABLE [SUserInterface].[WidgetDashboardWidgetTypes] (
  [Id] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_WidgetDashboardWidgetTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowVersion] [timestamp],
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_WidgetDashboardWidgetTypes_RowStatus] DEFAULT (0),
  [WidgetDashboardId] [int] NOT NULL CONSTRAINT [DF_WidgetDashboardWidgetTypes_WidgetDashboardId] DEFAULT (-1),
  [WidgetTypeId] [smallint] NOT NULL CONSTRAINT [DF_WidgetDashboardWidgetTypes_WidgetTypeId] DEFAULT (-1)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_WidgetDashboardWidgetTypes] on table [SUserInterface].[WidgetDashboardWidgetTypes]')
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_WidgetDashboardWidgetTypes] PRIMARY KEY CLUSTERED ([Id]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_WidgetDashboardWidgetTypes] on table [SUserInterface].[WidgetDashboardWidgetTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_WidgetDashboardWidgetTypes]
  ON [SUserInterface].[WidgetDashboardWidgetTypes] ([WidgetDashboardId], [WidgetTypeId])
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_WidgetDashboardWidgetTypes_Guid] on table [SUserInterface].[WidgetDashboardWidgetTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_WidgetDashboardWidgetTypes_Guid]
  ON [SUserInterface].[WidgetDashboardWidgetTypes] ([Guid])
  ON [METADATA]
GO

PRINT (N'Create foreign key [FK_WidgetDashboardWidgetTypes_WidgetDashboards] on table [SUserInterface].[WidgetDashboardWidgetTypes]')
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_WidgetDashboardWidgetTypes_WidgetDashboards] FOREIGN KEY ([WidgetDashboardId]) REFERENCES [SUserInterface].[WidgetDashboards] ([Id])
GO

PRINT (N'Create foreign key [FK_WidgetDashboardWidgetTypes_WidgetTypes] on table [SUserInterface].[WidgetDashboardWidgetTypes]')
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_WidgetDashboardWidgetTypes_WidgetTypes] FOREIGN KEY ([WidgetTypeId]) REFERENCES [SUserInterface].[WidgetTypes] ([Id])
GO