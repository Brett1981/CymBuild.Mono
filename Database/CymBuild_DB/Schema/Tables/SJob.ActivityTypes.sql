CREATE TABLE [SJob].[ActivityTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ActivityTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ActivityTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](150) NOT NULL CONSTRAINT [DF_ActivityTypes_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DF_ActivityTypes_IsActive] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_ActivityTypess_SortOrder] DEFAULT (0),
  [IsFeeTrigger] [bit] NOT NULL CONSTRAINT [DF_ActivityTypes_IsFeeTrigger] DEFAULT (0),
  [IsLiveTrigger] [bit] NOT NULL CONSTRAINT [DF_ActivityTypes_IsLiveTrigger] DEFAULT (0),
  [IsAdmin] [bit] NOT NULL CONSTRAINT [DF_ActivityTypes_IsAdmin] DEFAULT (0),
  [IsScheduleItem] [bit] NOT NULL CONSTRAINT [DF_ActivityTypes_IsScheduleItem] DEFAULT (0),
  [Colour] [nvarchar](6) NOT NULL CONSTRAINT [DEFAULT_ActivityTypes_Colour] DEFAULT (''),
  [IsMeeting] [bit] NOT NULL CONSTRAINT [DF_ActivityTypes_IsMeeting] DEFAULT (0),
  [IsSiteVisit] [bit] NOT NULL CONSTRAINT [DF_ActivityTypes_IsSiteVisit] DEFAULT (0),
  [IsBillable] [bit] NOT NULL CONSTRAINT [DF_ActivityTypes_IsBillable] DEFAULT (0),
  [IsCommencementTrigger] [bit] NOT NULL CONSTRAINT [DF_ActivityTypes_IsCommencementTrigger] DEFAULT (0),
  CONSTRAINT [PK_ActivityTypes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_ActivityTypes_IsScheduleItem]
  ON [SJob].[ActivityTypes] ([IsScheduleItem])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActivityTypes_Guid]
  ON [SJob].[ActivityTypes] ([Guid])
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ActivityTypes_Name]
  ON [SJob].[ActivityTypes] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[ActivityTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_ActivityTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[ActivityTypes]
  NOCHECK CONSTRAINT [FK_ActivityTypes_DataObjects]
GO

ALTER TABLE [SJob].[ActivityTypes]
  ADD CONSTRAINT [FK_ActivityTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO