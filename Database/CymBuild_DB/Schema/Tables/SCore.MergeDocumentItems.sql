CREATE TABLE [SCore].[MergeDocumentItems] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Merge DocumentItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Merge DocumentItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [MergeDocumentId] [int] NOT NULL CONSTRAINT [DF_Merge DocumentItems_MergeDocumentId] DEFAULT (-1),
  [MergeDocumentItemTypeId] [smallint] NOT NULL CONSTRAINT [DF_Merge DocumentItems_MergeDocumentItemTypeId] DEFAULT (-1),
  [BookmarkName] [nvarchar](50) NOT NULL CONSTRAINT [DF_Merge DocumentItems_BookmarkName] DEFAULT (''),
  [EntityTypeId] [int] NOT NULL CONSTRAINT [DF_Merge DocumentItems_EntityType] DEFAULT (-1),
  [SubFolderPath] [nvarchar](200) NOT NULL CONSTRAINT [DF_Merge DocumentItems_SubFolderPath] DEFAULT (''),
  [ImageColumns] [int] NOT NULL CONSTRAINT [DF_Merge DocumentItems_ImageColumns] DEFAULT (0),
  CONSTRAINT [PK_MergeDocumentItems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItems_BookmarkName]
  ON [SCore].[MergeDocumentItems] ([MergeDocumentId], [BookmarkName], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItems_Guid]
  ON [SCore].[MergeDocumentItems] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[MergeDocumentItems]
  ADD CONSTRAINT [FK_MergeDocumentItems_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

ALTER TABLE [SCore].[MergeDocumentItems]
  ADD CONSTRAINT [FK_MergeDocumentItems_MergeDocumentItemTypes] FOREIGN KEY ([MergeDocumentItemTypeId]) REFERENCES [SCore].[MergeDocumentItemTypes] ([ID])
GO

ALTER TABLE [SCore].[MergeDocumentItems]
  ADD CONSTRAINT [FK_MergeDocumentItems_MergeDocuments] FOREIGN KEY ([MergeDocumentId]) REFERENCES [SCore].[MergeDocuments] ([ID])
GO