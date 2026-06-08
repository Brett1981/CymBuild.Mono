PRINT (N'Create table [SAi].[AssistantKnowledgeCategories]')
GO
CREATE TABLE [SAi].[AssistantKnowledgeCategories] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL,
  [Code] [nvarchar](50) NOT NULL,
  [Description] [nvarchar](1000) NULL,
  [DisplayOrder] [int] NOT NULL,
  [IsVisible] [bit] NOT NULL CONSTRAINT [DF_AssistantKnowledgeCategories_IsVisible] DEFAULT (1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantKnowledgeCategories] on table [SAi].[AssistantKnowledgeCategories]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeCategories] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantKnowledgeCategories] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeCategories_Code] on table [SAi].[AssistantKnowledgeCategories]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeCategories] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeCategories_Code] UNIQUE ([Code]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeCategories_Guid] on table [SAi].[AssistantKnowledgeCategories]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeCategories] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeCategories_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeCategories_DataObjects] on table [SAi].[AssistantKnowledgeCategories]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeCategories] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeCategories_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantKnowledgeCategories_DataObjects] on table [SAi].[AssistantKnowledgeCategories]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeCategories]
  NOCHECK CONSTRAINT [FK_AssistantKnowledgeCategories_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeCategories_RowStatus] on table [SAi].[AssistantKnowledgeCategories]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeCategories] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeCategories_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO