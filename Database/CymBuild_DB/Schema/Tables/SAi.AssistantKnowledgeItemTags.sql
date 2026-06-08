PRINT (N'Create table [SAi].[AssistantKnowledgeItemTags]')
GO
CREATE TABLE [SAi].[AssistantKnowledgeItemTags] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [KnowledgeItemId] [int] NOT NULL,
  [KnowledgeTagId] [int] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantKnowledgeItemTags] on table [SAi].[AssistantKnowledgeItemTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemTags] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantKnowledgeItemTags] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeItemTags_Guid] on table [SAi].[AssistantKnowledgeItemTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemTags] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeItemTags_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeItemTags_Key] on table [SAi].[AssistantKnowledgeItemTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemTags] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeItemTags_Key] UNIQUE ([KnowledgeItemId], [KnowledgeTagId]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItemTags_DataObjects] on table [SAi].[AssistantKnowledgeItemTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemTags] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItemTags_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantKnowledgeItemTags_DataObjects] on table [SAi].[AssistantKnowledgeItemTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemTags]
  NOCHECK CONSTRAINT [FK_AssistantKnowledgeItemTags_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItemTags_Items] on table [SAi].[AssistantKnowledgeItemTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemTags] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItemTags_Items] FOREIGN KEY ([KnowledgeItemId]) REFERENCES [SAi].[AssistantKnowledgeItems] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItemTags_RowStatus] on table [SAi].[AssistantKnowledgeItemTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemTags] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItemTags_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItemTags_Tags] on table [SAi].[AssistantKnowledgeItemTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemTags] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItemTags_Tags] FOREIGN KEY ([KnowledgeTagId]) REFERENCES [SAi].[AssistantKnowledgeTags] ([ID])
GO