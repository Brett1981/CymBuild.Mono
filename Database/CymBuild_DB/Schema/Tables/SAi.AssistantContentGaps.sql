PRINT (N'Create table [SAi].[AssistantContentGaps]')
GO
CREATE TABLE [SAi].[AssistantContentGaps] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [Title] [nvarchar](500) NOT NULL,
  [Description] [nvarchar](max) NULL,
  [TopicCluster] [nvarchar](250) NULL,
  [OccurrenceCount] [int] NOT NULL,
  [LastSeenUtc] [datetime2] NOT NULL,
  [StatusCode] [nvarchar](30) NOT NULL,
  [SuggestedKnowledgeItemId] [int] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantContentGaps] on table [SAi].[AssistantContentGaps]')
GO
ALTER TABLE [SAi].[AssistantContentGaps] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantContentGaps] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantContentGaps_Guid] on table [SAi].[AssistantContentGaps]')
GO
ALTER TABLE [SAi].[AssistantContentGaps] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantContentGaps_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantContentGaps_Status_LastSeen] on table [SAi].[AssistantContentGaps]')
GO
CREATE INDEX [IX_AssistantContentGaps_Status_LastSeen]
  ON [SAi].[AssistantContentGaps] ([StatusCode], [LastSeenUtc] DESC)
  INCLUDE ([Title], [TopicCluster], [OccurrenceCount], [SuggestedKnowledgeItemId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantContentGaps_DataObjects] on table [SAi].[AssistantContentGaps]')
GO
ALTER TABLE [SAi].[AssistantContentGaps] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantContentGaps_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantContentGaps_DataObjects] on table [SAi].[AssistantContentGaps]')
GO
ALTER TABLE [SAi].[AssistantContentGaps]
  NOCHECK CONSTRAINT [FK_AssistantContentGaps_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantContentGaps_KnowledgeItems] on table [SAi].[AssistantContentGaps]')
GO
ALTER TABLE [SAi].[AssistantContentGaps] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantContentGaps_KnowledgeItems] FOREIGN KEY ([SuggestedKnowledgeItemId]) REFERENCES [SAi].[AssistantKnowledgeItems] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantContentGaps_RowStatus] on table [SAi].[AssistantContentGaps]')
GO
ALTER TABLE [SAi].[AssistantContentGaps] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantContentGaps_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO