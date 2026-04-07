CREATE TABLE [SJob].[PlanCheckItems] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_PlanCheckItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_PlanCheckItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [PlanCheckId] [int] NOT NULL CONSTRAINT [DEFAULT_PlanCheckItems_PlanCheckId] DEFAULT (-1),
  [Date] [datetime2] NOT NULL CONSTRAINT [DEFAULT_PlanCheckItems_Date] DEFAULT (getdate()),
  [IsOK] [bit] NOT NULL CONSTRAINT [DF_PlanCheckItems_IsOK] DEFAULT (0),
  [IsPublished] [bit] NOT NULL CONSTRAINT [DF_PlanCheckItems_IsPublished] DEFAULT (0),
  [Part] [nvarchar](50) NOT NULL CONSTRAINT [DF_PlanCheckItems_Part] DEFAULT (''),
  [Notes] [nvarchar](4000) NOT NULL CONSTRAINT [DF_PlanCheckItems_Notes] DEFAULT (''),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_PlanCheckItems_SortOrder] DEFAULT (0),
  [RevisedFromPlanCheckItemID] [int] NOT NULL CONSTRAINT [DF_PlanCheckItems_RevisedFromPlanCheckItemID] DEFAULT (-1),
  CONSTRAINT [PK_PlanCheckItems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

ALTER TABLE [SJob].[PlanCheckItems]
  ADD CONSTRAINT [FK_PlanCheckItems_PlanChecks] FOREIGN KEY ([PlanCheckId]) REFERENCES [SJob].[PlanChecks] ([ID])
GO

ALTER TABLE [SJob].[PlanCheckItems]
  ADD CONSTRAINT [FK_PlanCheckItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO