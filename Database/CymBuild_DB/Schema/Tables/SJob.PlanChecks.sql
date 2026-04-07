CREATE TABLE [SJob].[PlanChecks] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_PlanChecks_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_PlanChecks_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DEFAULT_PlanChecks_JobID] DEFAULT (-1),
  [Date] [datetime2] NOT NULL CONSTRAINT [DEFAULT_PlanChecks_Date] DEFAULT (getdate()),
  [RevisionNo] [int] NOT NULL CONSTRAINT [DF_PlanChecks_RevisionNo] DEFAULT (0),
  [Heading] [nvarchar](256) NOT NULL CONSTRAINT [DF_PlanChecks_Heading] DEFAULT (''),
  [Notes] [nvarchar](4000) NOT NULL CONSTRAINT [DF_PlanChecks_Notes] DEFAULT (''),
  [DrawingRefs] [nvarchar](4000) NOT NULL CONSTRAINT [DF_PlanChecks_DrawingRefs] DEFAULT (''),
  CONSTRAINT [PK_PlanChecks] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

ALTER TABLE [SJob].[PlanChecks]
  ADD CONSTRAINT [FK_PlanChecks_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO