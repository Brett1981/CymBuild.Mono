CREATE TABLE [SCore].[MergeDocumentItemIncludes] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [MergeDocumentItemId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_MergeDocumentItemId] DEFAULT (-1),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_SortOrder] DEFAULT (0),
  [SourceDocumentEntityPropertyId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_SourceDocumentEntityPropertyId] DEFAULT (-1),
  [SourceSharePointItemEntityPropertyId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_SourceSharePointItemEntityPropertyId] DEFAULT (-1),
  [IncludedMergeDocumentId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_IncludedMergeDocumentId] DEFAULT (-1),
  CONSTRAINT [PK_MergeDocumentItemIncludes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItemIncludes_Guid]
  ON [SCore].[MergeDocumentItemIncludes] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[MergeDocumentItemIncludes]
  ADD CONSTRAINT [FK_MergeDocumentItemIncludes_EntityProperties] FOREIGN KEY ([SourceDocumentEntityPropertyId]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

ALTER TABLE [SCore].[MergeDocumentItemIncludes]
  ADD CONSTRAINT [FK_MergeDocumentItemIncludes_EntityProperties1] FOREIGN KEY ([SourceSharePointItemEntityPropertyId]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

ALTER TABLE [SCore].[MergeDocumentItemIncludes]
  ADD CONSTRAINT [FK_MergeDocumentItemIncludes_MergeDocumentItems] FOREIGN KEY ([MergeDocumentItemId]) REFERENCES [SCore].[MergeDocumentItems] ([ID])
GO

ALTER TABLE [SCore].[MergeDocumentItemIncludes]
  ADD CONSTRAINT [FK_MergeDocumentItemIncludes_MergeDocuments] FOREIGN KEY ([IncludedMergeDocumentId]) REFERENCES [SCore].[MergeDocuments] ([ID])
GO