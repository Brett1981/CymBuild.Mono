PRINT (N'Create table [SAi].[AssistantKnowledgeItemVersions]')
GO
CREATE TABLE [SAi].[AssistantKnowledgeItemVersions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [KnowledgeItemId] [int] NOT NULL,
  [VersionNumber] [int] NOT NULL,
  [StorageUrl] [nvarchar](1000) NOT NULL,
  [ExtractedText] [nvarchar](max) NULL,
  [ExtractionStatusCode] [nvarchar](30) NOT NULL,
  [MetadataJson] [nvarchar](max) NULL,
  [FileHash] [nvarchar](200) NULL,
  [IsCurrent] [bit] NOT NULL CONSTRAINT [DF_AssistantKnowledgeItemVersions_IsCurrent] DEFAULT (0),
  [CreatedByUserId] [int] NOT NULL,
  [CreatedUtc] [datetime2] NOT NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantKnowledgeItemVersions] on table [SAi].[AssistantKnowledgeItemVersions]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemVersions] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantKnowledgeItemVersions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeItemVersions_Guid] on table [SAi].[AssistantKnowledgeItemVersions]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemVersions] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeItemVersions_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantKnowledgeItemVersions_ItemVersion] on table [SAi].[AssistantKnowledgeItemVersions]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemVersions] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantKnowledgeItemVersions_ItemVersion] UNIQUE ([KnowledgeItemId], [VersionNumber]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantKnowledgeItemVersions_Item_Current] on table [SAi].[AssistantKnowledgeItemVersions]')
GO
CREATE INDEX [IX_AssistantKnowledgeItemVersions_Item_Current]
  ON [SAi].[AssistantKnowledgeItemVersions] ([KnowledgeItemId], [IsCurrent] DESC, [VersionNumber] DESC)
  INCLUDE ([ExtractionStatusCode], [CreatedUtc])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItemVersions_DataObjects] on table [SAi].[AssistantKnowledgeItemVersions]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemVersions] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItemVersions_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantKnowledgeItemVersions_DataObjects] on table [SAi].[AssistantKnowledgeItemVersions]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemVersions]
  NOCHECK CONSTRAINT [FK_AssistantKnowledgeItemVersions_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItemVersions_Identities_CreatedBy] on table [SAi].[AssistantKnowledgeItemVersions]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemVersions] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItemVersions_Identities_CreatedBy] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItemVersions_Items] on table [SAi].[AssistantKnowledgeItemVersions]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemVersions] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItemVersions_Items] FOREIGN KEY ([KnowledgeItemId]) REFERENCES [SAi].[AssistantKnowledgeItems] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantKnowledgeItemVersions_RowStatus] on table [SAi].[AssistantKnowledgeItemVersions]')
GO
ALTER TABLE [SAi].[AssistantKnowledgeItemVersions] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantKnowledgeItemVersions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO