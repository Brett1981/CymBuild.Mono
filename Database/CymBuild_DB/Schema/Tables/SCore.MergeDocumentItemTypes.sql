CREATE TABLE [SCore].[MergeDocumentItemTypes] (
  [ID] [smallint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MergeDocumentItemTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MergeDocumentItemTypes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_MergeDocumentItemTypes_Name] DEFAULT (''),
  [IsImageType] [bit] NOT NULL CONSTRAINT [DF_MergeDocumentItemTypes_IsImageType] DEFAULT (0),
  CONSTRAINT [PK_MergeDocumentItemTypes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItemsTypes_Name]
  ON [SCore].[MergeDocumentItemTypes] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItemTypes_Guid]
  ON [SCore].[MergeDocumentItemTypes] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO