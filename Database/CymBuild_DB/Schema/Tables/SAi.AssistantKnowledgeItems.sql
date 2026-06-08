PRINT (N'Create table [SAi].[AssistantKnowledgeItems]')
GO
CREATE TABLE [SAi].[AssistantKnowledgeItems] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [Title] [nvarchar](500) NOT NULL,
  [Slug] [nvarchar](500) NOT NULL,
  [KnowledgeCategoryId] [int] NULL,
  [ContentTypeCode] [nvarchar](30) NOT NULL,
  [SourceTypeCode] [nvarchar](30) NOT NULL,
  [StorageUrl] [nvarchar](1000) NOT NULL,
  [PreviewUrl] [nvarchar](1000) NULL,
  [Summary] [nvarchar](max) NULL,
  [IsAuthoritative] [bit] NOT NULL CONSTRAINT [DF_AssistantKnowledgeItems_IsAuthoritative] DEFAULT (0),
  [IsPublished] [bit] NOT NULL CONSTRAINT [DF_AssistantKnowledgeItems_IsPublished] DEFAULT (0),
  [PublishedUtc] [datetime2] NULL,
  [CreatedByUserId] [int] NOT NULL,
  [UpdatedByUserId] [int] NULL,
  [CreatedUtc] [datetime2] NOT NULL,
  [UpdatedUtc] [datetime2] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantKnowledgeItems] on table [SAi].[AssistantKnowledgeItems]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItems] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantKnowledgeItems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeItems_Guid] on table [SAi].[AssistantKnowledgeItems]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItems] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeItems_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeItems_Slug] on table [SAi].[AssistantKnowledgeItems]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItems] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeItems_Slug] UNIQUE ([Slug]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantKnowledgeItems_Category_Published] on table [SAi].[AssistantKnowledgeItems]')
GO
CREATE INDEX [IX_AssistantKnowledgeItems_Category_Published]
  ON [SAi].[AssistantKnowledgeItems] ([KnowledgeCategoryId], [IsPublished], [IsAuthoritative])
  INCLUDE ([Title], [Slug], [ContentTypeCode], [UpdatedUtc])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItems_Categories] on table [SAi].[AssistantKnowledgeItems]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItems] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItems_Categories] FOREIGN KEY ([KnowledgeCategoryId]) REFERENCES [SAi].[AssistantKnowledgeCategories] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItems_DataObjects] on table [SAi].[AssistantKnowledgeItems]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItems] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantKnowledgeItems_DataObjects] on table [SAi].[AssistantKnowledgeItems]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItems]
  NOCHECK CONSTRAINT [FK_AssistantKnowledgeItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItems_Identities_CreatedBy] on table [SAi].[AssistantKnowledgeItems]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItems] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItems_Identities_CreatedBy] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItems_Identities_UpdatedBy] on table [SAi].[AssistantKnowledgeItems]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItems] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItems_Identities_UpdatedBy] FOREIGN KEY ([UpdatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItems_RowStatus] on table [SAi].[AssistantKnowledgeItems]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItems] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO