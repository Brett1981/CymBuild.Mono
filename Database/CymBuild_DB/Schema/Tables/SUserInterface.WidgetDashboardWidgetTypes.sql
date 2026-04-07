CREATE TABLE [SUserInterface].[WidgetDashboardWidgetTypes] (
  [Id] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_WidgetDashboardWidgetTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowVersion] [timestamp],
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_WidgetDashboardWidgetTypes_RowStatus] DEFAULT (0),
  [WidgetDashboardId] [int] NOT NULL CONSTRAINT [DF_WidgetDashboardWidgetTypes_WidgetDashboardId] DEFAULT (-1),
  [WidgetTypeId] [smallint] NOT NULL CONSTRAINT [DF_WidgetDashboardWidgetTypes_WidgetTypeId] DEFAULT (-1),
  CONSTRAINT [PK_WidgetDashboardWidgetTypes] PRIMARY KEY CLUSTERED ([Id]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_WidgetDashboardWidgetTypes]
  ON [SUserInterface].[WidgetDashboardWidgetTypes] ([WidgetDashboardId], [WidgetTypeId])
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_WidgetDashboardWidgetTypes_Guid]
  ON [SUserInterface].[WidgetDashboardWidgetTypes] ([Guid])
  ON [METADATA]
GO

ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes]
  ADD CONSTRAINT [FK_WidgetDashboardWidgetTypes_WidgetDashboards] FOREIGN KEY ([WidgetDashboardId]) REFERENCES [SUserInterface].[WidgetDashboards] ([Id])
GO

ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes]
  ADD CONSTRAINT [FK_WidgetDashboardWidgetTypes_WidgetTypes] FOREIGN KEY ([WidgetTypeId]) REFERENCES [SUserInterface].[WidgetTypes] ([Id])
GO