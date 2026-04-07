CREATE TABLE [SJob].[MilestoneTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MilestoneTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MilestoneTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](20) NOT NULL CONSTRAINT [DF_MilestoneTypes_Code] DEFAULT (''),
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_MilestoneTypes_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DF_MilestoneTypes_IsActive] DEFAULT (0),
  [IsInvoiceTrigger] [bit] NOT NULL CONSTRAINT [DF_MilestoneTypes_IsInvoiceTrigger] DEFAULT (0),
  [IsReviewRequired] [bit] NOT NULL CONSTRAINT [DF_MilestoneTypes_IsReviewRequired] DEFAULT (0),
  [HelpText] [nvarchar](2000) NOT NULL CONSTRAINT [DF_MilestoneTypes_HelpText] DEFAULT (''),
  [HasQuotedHours] [bit] NOT NULL DEFAULT (0),
  [HasDescription] [bit] NOT NULL DEFAULT (0),
  [HasReference] [bit] NOT NULL DEFAULT (0),
  [IsCompulsory] [bit] NOT NULL DEFAULT (0),
  [IncludeStart] [bit] NOT NULL DEFAULT (0),
  [IncludeSchedule] [bit] NOT NULL DEFAULT (0),
  [IncludeDueDate] [bit] NOT NULL DEFAULT (0),
  [HasExternalSubmission] [bit] NOT NULL CONSTRAINT [DF_MilestoneTypes_HasExternalSubmission] DEFAULT (0),
  CONSTRAINT [PK_MilestoneTypes] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_MilestoneTypes_Code]
  ON [SJob].[MilestoneTypes] ([Code])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_MilestoneTypes_Guid]
  ON [SJob].[MilestoneTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[MilestoneTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_MilestoneTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[MilestoneTypes]
  NOCHECK CONSTRAINT [FK_MilestoneTypes_DataObjects]
GO

ALTER TABLE [SJob].[MilestoneTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_MilestoneTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO