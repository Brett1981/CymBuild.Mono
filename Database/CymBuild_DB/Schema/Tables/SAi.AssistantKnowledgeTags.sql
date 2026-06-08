PRINT (N'Create table [SAi].[AssistantKnowledgeTags]')
GO
CREATE TABLE [SAi].[AssistantKnowledgeTags] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL,
  [Code] [nvarchar](50) NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantKnowledgeTags] on table [SAi].[AssistantKnowledgeTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeTags] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantKnowledgeTags] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeTags_Code] on table [SAi].[AssistantKnowledgeTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeTags] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeTags_Code] UNIQUE ([Code]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeTags_Guid] on table [SAi].[AssistantKnowledgeTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeTags] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeTags_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeTags_DataObjects] on table [SAi].[AssistantKnowledgeTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeTags] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeTags_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantKnowledgeTags_DataObjects] on table [SAi].[AssistantKnowledgeTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeTags]
  NOCHECK CONSTRAINT [FK_AssistantKnowledgeTags_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeTags_RowStatus] on table [SAi].[AssistantKnowledgeTags]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeTags] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeTags_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO