PRINT (N'Create table [SJob].[PlanChecks]')
GO
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
  [DrawingRefs] [nvarchar](4000) NOT NULL CONSTRAINT [DF_PlanChecks_DrawingRefs] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_PlanChecks] on table [SJob].[PlanChecks]')
GO
ALTER TABLE [SJob].[PlanChecks] WITH NOCHECK
  ADD CONSTRAINT [PK_PlanChecks] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_PlanChecks_RowStatus] on table [SJob].[PlanChecks]')
GO
ALTER TABLE [SJob].[PlanChecks] WITH NOCHECK
  ADD CONSTRAINT [FK_PlanChecks_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO